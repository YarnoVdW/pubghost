import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

const packageName = 'pubghost';

/// Scans `pubspec.yaml` dependencies vs `lib/` imports to report unused packages.
Future<bool> checkUnusedDependencies() async {
  final projectDir = Directory.current;

  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('No pubspec.yaml found in current directory.');
    return false;
  }

  final yaml = loadYaml(pubspecFile.readAsStringSync());
  final deps = <String>[...?yaml['dependencies']?.keys];
  final devDeps = <String>[...?yaml['dev_dependencies']?.keys];

  if (deps.isEmpty && devDeps.isEmpty) {
    print('No dependencies found in pubspec.yaml.');
    return true;
  }

  final ignoredDeps = yaml[packageName]?['ignore_dependencies'];

  final ignored = <String>{};
  if (ignoredDeps is YamlList) {
    for (final item in ignoredDeps) {
      if (item is String) ignored.add(item);
    }
  }
  deps.removeWhere((dep) => ignored.contains(dep));
  devDeps.removeWhere((dep) => ignored.contains(dep));

  final dartFiles =
      projectDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  final usedPackages = <String>{};
  final allDependencies = {...deps, ...devDeps}.toList();

  for (final file in dartFiles) {
    final content = await file.readAsString();
    for (final dep in allDependencies) {
      final importPattern = RegExp("import\\s+['\"]package:$dep/");
      if (importPattern.hasMatch(content)) {
        usedPackages.add(dep);
      }
    }
  }

  final unusedDeps = deps.where((d) => !usedPackages.contains(d)).toList()..sort();
  final unusedDevDeps = devDeps.where((d) => !usedPackages.contains(d)).toList()..sort();

  if (unusedDeps.isEmpty && unusedDevDeps.isEmpty) {
    print('✅ All packages are used.');
    return true;
  } else {
    if (unusedDeps.isNotEmpty) {
      print('⚠️  Unused dependencies (${unusedDeps.length}):');
      for (final dep in unusedDeps) {
        print(' - $dep');
      }
    }
    if (unusedDevDeps.isNotEmpty) {
      print('⚠️  Unused dev_dependencies (${unusedDevDeps.length}):');
      for (final dep in unusedDevDeps) {
        print(' - $dep');
      }
    }
    return false;
  }
}

/// Scans your project’s `lib/` for class declarations and reports classes never referenced elsewhere.
Future<bool> checkUnusedWidgets() async {
  final projectDir = Directory.current;
  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  final ignoredExactClasses = <String>{};
  final ignoredPatterns = <RegExp>[];

  if (!pubspecFile.existsSync()) {
    print('No pubspec.yaml found in current directory.');
    return false;
  }

  if (pubspecFile.existsSync()) {
    final yaml = loadYaml(pubspecFile.readAsStringSync());
    final ignoredFromConfig = yaml[packageName]?['ignore_classes'];

    if (ignoredFromConfig is YamlList) {
      for (final ignored in ignoredFromConfig) {
        if (ignored is String) {
          if (_isRegexPattern(ignored)) {
            try {
              ignoredPatterns.add(RegExp(ignored));
            } catch (e) {
              ignoredExactClasses.add(ignored);
            }
          } else {
            ignoredExactClasses.add(ignored);
          }
        }
      }
    }
  }

  final dartFiles = Directory('${projectDir.path}/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final definedClasses = <String, String>{};
  final allContent = <String, String>{};

  for (final file in dartFiles) {
    final content = await file.readAsString();
    allContent[file.path] = content;

    final strippedContent = _stripComments(content);

    final classPattern = RegExp(r'class\s+(\w+)');
    final matches = classPattern.allMatches(strippedContent);
    for (final match in matches) {
      final className = match.group(1)!;
      if (!className.startsWith('_')) {
        definedClasses[className] = file.path;
      }
    }
  }

  if (definedClasses.isEmpty) {
    print('No classes found in the project.');
    return true;
  }

  final usedClasses = <String>{};
  final combinedContent = allContent.values.join('\n');

  for (final className in definedClasses.keys) {
    final classDefinitionPattern = RegExp(r'class\s+' + className + r'\b');
    final contentWithoutDefinition = combinedContent.replaceAll(
      classDefinitionPattern,
      '',
    );

    final patterns = [
      RegExp('\\b$className\\b'),
      RegExp('<$className>'),
      RegExp('$className\\('),
      RegExp('extends\\s+$className\\b'),
      RegExp('implements\\s+$className\\b'),
      RegExp('with\\s+$className\\b'),
    ];

    for (final pattern in patterns) {
      if (pattern.hasMatch(contentWithoutDefinition)) {
        usedClasses.add(className);
        break;
      }
    }
  }

  final unusedClasses = definedClasses.keys.where((className) {
    if (usedClasses.contains(className)) return false;

    if (ignoredExactClasses.contains(className)) return false;

    for (final pattern in ignoredPatterns) {
      if (pattern.hasMatch(className)) return false;
    }

    return true;
  }).toList();

  if (unusedClasses.isEmpty) {
    print('✅ All classes are used.');
    return true;
  } else {
    print('⚠️  Unused classes (${unusedClasses.length}):');
    for (final className in unusedClasses) {
      final filePath = definedClasses[className]!;
      final relativePath = filePath.replaceFirst(projectDir.path, '').replaceFirst('/', '');
      print(' - $className ($relativePath)');
    }
    return false;
  }
}

/// Strips comments from the given code.
String _stripComments(String code) {
  final blockComments = RegExp(r'/\*[\s\S]*?\*/');
  final lineComments = RegExp(r'//.*$', multiLine: true);
  return code.replaceAll(blockComments, '').replaceAll(lineComments, '');
}

/// Scans keys from `.arb` files and reports keys not referenced in code via common l10n access patterns (e.g., `S.of(context).keyName`, `AppLocalizations.current.keyName`, `context.l10n.keyName`).
Future<bool> checkUnusedIntlKeys() async {
  final projectDir = Directory.current;
  final pubspecFile = File('${projectDir.path}/pubspec.yaml');

  String? jsonPath;

  if (pubspecFile.existsSync()) {
    final yaml = loadYaml(pubspecFile.readAsStringSync());
    jsonPath = yaml[packageName]?['json_intl_path'] as String?;
  }

  final arbFiles = Directory('${projectDir.path}/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList();

  final jsonFiles = [];
  if (jsonPath != null) {
    final jsonDir = Directory(jsonPath.startsWith('/') ? jsonPath : '${projectDir.path}/$jsonPath');
    if (jsonDir.existsSync()) {
      jsonFiles
          .addAll(jsonDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')).toList());
    }
  }

  if (arbFiles.isEmpty && jsonPath == null) {
    print('No translation files found. Skipping intl key check.');
    return true;
  }

  if (jsonFiles.isEmpty && jsonPath != null) {
    print('No JSON files found. Skipping intl key check.');
    return true;
  }

  final allKeys = <String>{};
  for (final file in arbFiles) {
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      for (final key in data.keys) {
        if (!key.startsWith('@')) {
          allKeys.add(key);
        }
      }
    } catch (_) {}
  }

  for (final file in jsonFiles) {
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
      _extractKeysFromJson(data, allKeys);
    } catch (_) {}
  }

  if (allKeys.isEmpty) {
    print('No intl keys found in ARB or JSON files.');
    return true;
  }

  final dartFiles =
      projectDir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).where((f) {
    final p = f.path;
    if (p.contains('/test/')) return false;
    if (p.contains('/.dart_tool/')) return false;
    if (p.contains('/build/')) return false;
    if (p.contains('/gen_l10n/')) return false;
    if (p.contains('/l10n/generated/')) return false;
    return true;
  }).toList();

  if (dartFiles.isEmpty) {
    print('No Dart files to scan for intl usage.');
    return true;
  }

  final buffer = StringBuffer();
  for (final file in dartFiles) {
    try {
      buffer.writeln(await file.readAsString());
    } catch (_) {}
  }
  final code = buffer.toString();

  final unusedTranslations = <String>[];
  for (final key in allKeys) {
    final escapedKey = RegExp.escape(key);
    final patterns = [
      RegExp("['\"]$escapedKey['\"]"),
      RegExp("\\b$escapedKey\\b"),
      RegExp("\\.$escapedKey(\\b|\\()"),
      RegExp("\\[$escapedKey\\]"),
    ];
    var used = false;
    for (final pattern in patterns) {
      if (pattern.hasMatch(code)) {
        used = true;
        break;
      }
    }

    if (!used) {
      unusedTranslations.add(key);
    }
  }

  if (unusedTranslations.isEmpty) {
    print('✅ All intl keys are used.');
    return true;
  } else {
    print('⚠️  Unused intl keys (${unusedTranslations.length}):');
    for (final k in unusedTranslations..sort()) {
      print(' - $k');
    }
    return false;
  }
}

/// Checks if a string looks like a regex pattern.
bool _isRegexPattern(String s) {
  final regexChars = ['.*', '^', r'$', '+', '*', '?', '|', '(', ')', '[', ']', '{', '}', '\\'];
  return regexChars.any((char) => s.contains(char));
}

void _extractKeysFromJson(Map<String, dynamic> json, Set<String> keys, {String prefix = ''}) {
  for (final entry in json.entries) {
    final key = entry.key;
    final value = entry.value;

    if (key.startsWith('@')) continue;

    final fullKey = prefix.isEmpty ? key : '$prefix.$key';

    if (value is Map<String, dynamic>) {
      _extractKeysFromJson(value, keys, prefix: fullKey);

      final allChildrenAreStrings = value.values.every((v) => v is String);
      if (allChildrenAreStrings && value.isNotEmpty) {
        keys.add(fullKey);
      }
    } else if (value is String) {
      keys.add(fullKey);
    }
  }
}
