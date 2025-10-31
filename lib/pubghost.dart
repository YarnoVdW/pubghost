import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// Scans `pubspec.yaml` dependencies vs `lib/` imports to report unused packages.
Future<void> checkUnusedDependencies() async {
  final projectDir = Directory.current;

  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('No pubspec.yaml found in current directory.');
    exit(1);
  }

  final yaml = loadYaml(pubspecFile.readAsStringSync());
  final deps = <String>[
    ...?yaml['dependencies']?.keys,
    ...?yaml['dev_dependencies']?.keys,
  ];

  if (deps.isEmpty) {
    print('No dependencies found in pubspec.yaml.');
    exit(0);
  }

  final dartFiles = projectDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final usedPackages = <String>{};

  for (final file in dartFiles) {
    final content = await file.readAsString();
    for (final dep in deps) {
      final importPattern = RegExp("import\\s+['\"]package:$dep/");
      if (importPattern.hasMatch(content)) {
        usedPackages.add(dep);
      }
    }
  }

  final unusedPackages = deps.where((d) => !usedPackages.contains(d)).toList();

  if (unusedPackages.isEmpty) {
    print('✅ All packages are used.');
  } else {
    print('⚠️  Unused packages (${unusedPackages.length}):');
    for (final dep in unusedPackages) {
      print(' - $dep');
    }
  }
}

/// Scans your project’s `lib/` for class declarations and reports classes never referenced elsewhere.
Future<void> checkUnusedWidgets() async {
  final projectDir = Directory.current;

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

    final classPattern = RegExp(r'class\s+(\w+)');
    final matches = classPattern.allMatches(content);
    for (final match in matches) {
      final className = match.group(1)!;
      if (!className.startsWith('_')) {
        definedClasses[className] = file.path;
      }
    }
  }

  if (definedClasses.isEmpty) {
    print('No classes found in the project.');
    return;
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

  final unusedClasses = definedClasses.keys
      .where((className) => !usedClasses.contains(className))
      .toList();

  if (unusedClasses.isEmpty) {
    print('✅ All classes are used.');
  } else {
    print('⚠️  Unused classes (${unusedClasses.length}):');
    for (final className in unusedClasses) {
      final filePath = definedClasses[className]!;
      final relativePath =
          filePath.replaceFirst(projectDir.path, '').replaceFirst('/', '');
      print(' - $className ($relativePath)');
    }
  }
}

/// Scans keys from `.arb` files and reports keys not referenced in code via common l10n access patterns (e.g., `S.of(context).keyName`, `AppLocalizations.current.keyName`, `context.l10n.keyName`).
Future<void> checkUnusedIntlKeys() async {
  final projectDir = Directory.current;

  final arbFiles = Directory('${projectDir.path}/lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb'))
      .toList();

  if (arbFiles.isEmpty) {
    print('No .arb files found. Skipping intl key check.');
    return;
  }

  final allKeys = <String>{};
  for (final file in arbFiles) {
    try {
      final content = await file.readAsString();
      final Map<String, dynamic> data =
          jsonDecode(content) as Map<String, dynamic>;
      for (final key in data.keys) {
        if (!key.startsWith('@')) {
          allKeys.add(key);
        }
      }
    } catch (_) {}
  }

  if (allKeys.isEmpty) {
    print('No intl keys found in ARB files.');
    return;
  }

  final dartFiles = projectDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) {
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
    return;
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
    final pattern = RegExp('\\.$escapedKey(\\b|\\()');
    if (!pattern.hasMatch(code)) {
      unusedTranslations.add(key);
    }
  }

  if (unusedTranslations.isEmpty) {
    print('✅ All intl keys are used.');
  } else {
    print('⚠️  Unused intl keys (${unusedTranslations.length}):');
    for (final k in unusedTranslations..sort()) {
      print(' - $k');
    }
  }
}
