import 'dart:async';
import 'dart:io';

/// A throwaway project directory used to exercise the `checkUnused*`
/// functions, which operate on `Directory.current` and real files on disk.
class TestProject {
  final Directory root;

  TestProject._(this.root);

  static Future<TestProject> create() async {
    final dir = await Directory.systemTemp.createTemp('pubghost_test_');
    return TestProject._(dir);
  }

  /// Writes [contents] to [relativePath] inside the project, creating any
  /// intermediate directories as needed.
  Future<File> writeFile(String relativePath, String contents) async {
    final file = File('${root.path}/$relativePath');
    await file.parent.create(recursive: true);
    return file.writeAsString(contents);
  }

  Future<void> writePubspec(String contents) =>
      writeFile('pubspec.yaml', contents);

  Future<void> dispose() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

/// Runs [body] with `Directory.current` set to [project]'s root, restoring
/// the original working directory afterwards even if [body] throws.
///
/// Also captures everything written via `print()` during [body] and returns
/// it via the returned record's `output`, alongside [body]'s own return
/// value as `result`.
Future<({T result, List<String> output})> runInProject<T>(
  TestProject project,
  Future<T> Function() body,
) async {
  final originalDir = Directory.current;
  final output = <String>[];
  late T result;
  try {
    Directory.current = project.root;
    await runZoned(
      () async {
        result = await body();
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => output.add(line),
      ),
    );
  } finally {
    Directory.current = originalDir;
  }
  return (result: result, output: output);
}
