import 'package:pubghost/pubghost.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'test_project.dart';

void main() {
  group('checkUnusedDependencies', () {
    late TestProject project;

    setUp(() async => project = await TestProject.create());
    tearDown(() => project.dispose());

    test('reports a dependency that is never imported', () async {
      await project.writePubspec('''
name: sample
dependencies:
  path: ^1.9.0
  http: ^1.2.0
''');
      await project.writeFile(
          'lib/main.dart', "import 'package:path/path.dart';");

      final run = await runInProject(project, checkUnusedDependencies);

      expect(run.result, isFalse);
      expect(run.output.join('\n'), contains('http'));
      expect(run.output.join('\n'), isNot(contains(' - path')));
    });

    test('passes when every dependency is imported somewhere', () async {
      await project.writePubspec('''
name: sample
dependencies:
  path: ^1.9.0
''');
      await project.writeFile(
          'lib/main.dart', "import 'package:path/path.dart';");

      final run = await runInProject(project, checkUnusedDependencies);

      expect(run.result, isTrue);
      expect(run.output.join('\n'), contains('All packages are used'));
    });

    test('does not flag a dependency listed under ignore_dependencies',
        () async {
      await project.writePubspec('''
name: sample
dependencies:
  http: ^1.2.0
pubghost:
  ignore_dependencies:
    - http
''');
      await project.writeFile('lib/main.dart', "void main() {}");

      final run = await runInProject(project, checkUnusedDependencies);

      expect(run.result, isTrue);
    });
  });
}
