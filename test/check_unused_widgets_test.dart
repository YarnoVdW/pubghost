import 'package:pubghost/pubghost.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';
import 'test_project.dart';

void main() {
  group('checkUnusedWidgets', () {
    late TestProject project;

    setUp(() async => project = await TestProject.create());
    tearDown(() => project.dispose());

    test('reports a class that is never referenced', () async {
      await project.writePubspec('name: sample');
      await project.writeFile('lib/main.dart', '''
class UsedWidget {}
class OrphanWidget {}

void main() {
  UsedWidget();
}
''');

      final run = await runInProject(project, checkUnusedWidgets);

      expect(run.result, isFalse);
      expect(run.output.join('\n'), contains('OrphanWidget'));
      expect(run.output.join('\n'), isNot(contains('UsedWidget')));
    });

    test('does not flag classes referenced via extends/implements/with',
        () async {
      await project.writePubspec('name: sample');
      await project.writeFile('lib/main.dart', '''
class Base {}
class Interface {}
mixin MyMixin {}

class Impl extends Base implements Interface with MyMixin {}

void main() {
  Impl();
}
''');

      final run = await runInProject(project, checkUnusedWidgets);

      expect(run.result, isTrue);
    });

    test('respects exact and regex ignore_classes config', () async {
      await project.writePubspec('''
name: sample
pubghost:
  ignore_classes:
    - ExactlyIgnored
    - ".*Model\$"
''');
      await project.writeFile('lib/main.dart', '''
class ExactlyIgnored {}
class UserModel {}

void main() {}
''');

      final run = await runInProject(project, checkUnusedWidgets);

      expect(run.result, isTrue);
    });
  });
}
