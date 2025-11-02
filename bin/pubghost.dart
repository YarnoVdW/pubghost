import 'package:pubghost/pubghost.dart' as pubghost;
import 'dart:io';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: pubghost <command>');
    print('Commands:');
    print('  -d, --deps      Check for unused dependencies');
    print('  -c, --widgets   Check for unused classes/widgets');
    print('  -t, --intl      Check ARB intl keys not used in code');
    print('');
    print('Flags can be chained: -dc, -cdt, etc.');
    exit(1);
  }

  final command = arguments.first;

  final checks = <String>[];
  bool hasError = false;

  if (command.startsWith('-') && !command.startsWith('--')) {
    for (int i = 1; i < command.length; i++) {
      final char = command[i];
      switch (char) {
        case 'd':
          checks.add('deps');
          break;
        case 'c':
          checks.add('widgets');
          break;
        case 't':
          checks.add('intl');
          break;
        default:
          print('Unknown flag: -$char');
          hasError = true;
          break;
      }
    }
  } else {
    bool isDeprecated = false;

    switch (command) {
      case '-d':
        checks.add('deps');
        break;
      case '-c':
        checks.add('widgets');
        break;
      case '-t':
        checks.add('intl');
        break;
      case '--deps':
        checks.add('deps');
        isDeprecated = true;
        break;
      case '--widgets':
        checks.add('widgets');
        isDeprecated = true;
        break;
      case '--intl':
        checks.add('intl');
        isDeprecated = true;
        break;
      default:
        print('Unknown command: $command');
        print('Usage: pubghost <command>');
        print('Commands:');
        print('  -d, --deps      Check for unused dependencies');
        print('  -c, --widgets   Check for unused classes/widgets');
        print('  -t, --intl      Check ARB intl keys not used in code');
        print('');
        print('Flags can be chained: -dc, -cdt, etc.');
    }

    if (isDeprecated) {
      stderr.writeln(
          '⚠️  Warning: $command is going to be deprecated in the future. Use ${command == "--deps" ? "-d" : command == "--widgets" ? "-c" : "-t"} instead.');
    }
  }

  if (hasError || checks.isEmpty) {
    print('Usage: pubghost <command>');
    print('Commands:');
    print('  -d, --deps      Check for unused dependencies');
    print('  -c, --widgets   Check for unused classes/widgets');
    print('  -t, --intl      Check ARB intl keys not used in code');
    print('');
    print('Flags can be chained: -dc, -cdt, etc.');
    exit(1);
  }

  bool allPassed = true;

  for (final check in checks) {
    bool passed = false;
    switch (check) {
      case 'deps':
        passed = await pubghost.checkUnusedDependencies();
        break;
      case 'widgets':
        passed = await pubghost.checkUnusedWidgets();
        break;
      case 'intl':
        passed = await pubghost.checkUnusedIntlKeys();
        break;
    }

    if (!passed) {
      allPassed = false;
    }

    if (checks.length > 1 && check != checks.last) {
      print('');
    }
  }

  exit(allPassed ? 0 : 1);
}
