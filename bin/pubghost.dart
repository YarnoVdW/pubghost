import 'dart:io';
import 'package:args/args.dart';
import 'package:pubghost/pubghost.dart' as pubghost;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('deps',
        abbr: 'd', negatable: false, help: 'Check for unused dependencies')
    ..addFlag('widgets',
        abbr: 'c', negatable: false, help: 'Check for unused classes/widgets')
    ..addFlag('intl',
        abbr: 't',
        negatable: false,
        help: 'Check ARB intl keys not used in code')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Show usage information');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    print('Error: $e\n');
    printUsage(parser);
    exit(1);
  }

  if (argResults['help'] as bool || argResults.arguments.isEmpty) {
    printUsage(parser);
    exit(0);
  }

  final checks = <String>[];
  if (argResults['deps'] as bool) checks.add('deps');
  if (argResults['widgets'] as bool) checks.add('widgets');
  if (argResults['intl'] as bool) checks.add('intl');

  if (checks.isEmpty) {
    printUsage(parser);
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

    if (!passed) allPassed = false;

    if (checks.length > 1 && check != checks.last) print('');
  }

  exit(allPassed ? 0 : 1);
}

void printUsage(ArgParser parser) {
  print('Usage: pubghost [options]');
  print(parser.usage);
}
