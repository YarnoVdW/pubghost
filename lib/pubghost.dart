import 'dart:io';
import 'package:yaml/yaml.dart';

Future<void> run() async {
  final projectDir = Directory.current;

  final pubspecFile = File('${projectDir.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('No pubspec.yaml found in current directory.');
    exit(1);
  }

  final yaml = loadYaml(pubspecFile.readAsStringSync());
  final deps = <String>[...?yaml['dependencies']?.keys, ...?yaml['dev_dependencies']?.keys];

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

  final unused = deps.where((d) => !usedPackages.contains(d)).toList();

  if (unused.isEmpty) {
    print('✅ All packages are used.');
  } else {
    print('⚠️  Unused packages:');
    for (final dep in unused) {
      print(' - $dep');
    }
  }
}
