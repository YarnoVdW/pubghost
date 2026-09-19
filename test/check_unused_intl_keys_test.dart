import 'package:pubghost/pubghost.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

import 'test_project.dart';

void main() {
  group('checkUnusedIntlKeys with .arb files', () {
    late TestProject project;

    setUp(() async => project = await TestProject.create());
    tearDown(() => project.dispose());

    test('reports an arb key never referenced in code', () async {
      await project.writePubspec('name: sample');
      await project.writeFile('lib/l10n/app_en.arb', '''
{
  "usedKey": "Hello",
  "orphanKey": "Bye"
}
''');
      await project.writeFile('lib/main.dart', '''
void main() {
  print(S.of(context).usedKey);
}
''');

      final run = await runInProject(project, checkUnusedIntlKeys);

      expect(run.result, isFalse);
      expect(run.output.join('\n'), contains('orphanKey'));
      expect(run.output.join('\n'), isNot(contains(' - usedKey')));
    });

    test('ignores keys only seen in generated l10n output', () async {
      await project.writePubspec('name: sample');
      await project.writeFile(
          'lib/l10n/app_en.arb', '{"onlyInGenerated": "x"}');
      await project.writeFile(
        'lib/l10n/generated/app_localizations.dart',
        'String get onlyInGenerated => "x";',
      );
      await project.writeFile('lib/main.dart', 'void main() {}');

      final run = await runInProject(project, checkUnusedIntlKeys);

      expect(run.result, isFalse);
      expect(run.output.join('\n'), contains('onlyInGenerated'));
    });
  });

  group('checkUnusedIntlKeys with JSON translations', () {
    late TestProject project;

    setUp(() async => project = await TestProject.create());
    tearDown(() => project.dispose());

    test('reports a leaf JSON key never referenced in code', () async {
      await project.writePubspec('''
name: sample
pubghost:
  json_intl_path: lib/l10n/json
''');
      await project.writeFile('lib/l10n/json/en.json', '''
{
  "greeting": "Hello",
  "farewell": "Bye"
}
''');
      await project.writeFile(
          'lib/main.dart', "void main() { 'greeting'.tr(); }");

      final run = await runInProject(project, checkUnusedIntlKeys);

      expect(run.result, isFalse);
      expect(run.output.join('\n'), contains('farewell'));
      expect(run.output.join('\n'), isNot(contains(' - greeting')));
    });

    // Regression test for https://github.com/YarnoVdW/pubghost/issues/16
    //
    // A JSON object whose direct children are only ever accessed through
    // their fully-qualified dotted key (e.g. 'consent_dialog.content'.tr())
    // must NOT have its parent key ('consent_dialog') reported as unused,
    // even though the parent key itself never appears verbatim in the code.
    test(
      'does not flag a namespace object whose children are used via dotted keys (issue #16)',
      () async {
        await project.writePubspec('''
name: sample
pubghost:
  json_intl_path: lib/l10n/json
''');
        await project.writeFile('lib/l10n/json/en.json', '''
{
  "consent_dialog": {
    "checkbox_label": "I agree",
    "content": "Please read our terms"
  }
}
''');
        await project.writeFile('lib/main.dart', '''
void main() {
  'consent_dialog.checkbox_label'.tr();
  'consent_dialog.content'.tr();
}
''');

        final run = await runInProject(project, checkUnusedIntlKeys);

        expect(
          run.result,
          isTrue,
          reason: 'output was:\n${run.output.join('\n')}',
        );
        expect(run.output.join('\n'), isNot(contains('consent_dialog')));
      },
    );

    test('flags a namespace object none of whose children are used', () async {
      await project.writePubspec('''
name: sample
pubghost:
  json_intl_path: lib/l10n/json
''');
      await project.writeFile('lib/l10n/json/en.json', '''
{
  "consent_dialog": {
    "checkbox_label": "I agree",
    "content": "Please read our terms"
  }
}
''');
      await project.writeFile('lib/main.dart', 'void main() {}');

      final run = await runInProject(project, checkUnusedIntlKeys);

      expect(run.result, isFalse);
      final joined = run.output.join('\n');
      expect(joined, contains('consent_dialog.checkbox_label'));
      expect(joined, contains('consent_dialog.content'));
    });

    test('honors a custom translation_accessor', () async {
      await project.writePubspec('''
name: sample
pubghost:
  json_intl_path: lib/l10n/json
  translation_accessor: t
''');
      await project.writeFile('lib/l10n/json/en.json', '{"greeting": "Hello"}');
      await project.writeFile(
          'lib/main.dart', "void main() { 'greeting'.t(); }");

      final run = await runInProject(project, checkUnusedIntlKeys);

      expect(run.result, isTrue);
    });

    test('ignores usages found only under test/', () async {
      await project.writePubspec('''
name: sample
pubghost:
  json_intl_path: lib/l10n/json
''');
      await project.writeFile('lib/l10n/json/en.json', '{"greeting": "Hello"}');
      await project.writeFile('lib/main.dart', 'void main() {}');
      await project.writeFile(
          'test/widget_test.dart', "void main() { 'greeting'.tr(); }");

      final run = await runInProject(project, checkUnusedIntlKeys);

      expect(run.result, isFalse);
      expect(run.output.join('\n'), contains('greeting'));
    });
  });
}
