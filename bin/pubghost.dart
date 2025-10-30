import 'package:pubghost/pubghost.dart' as pubghost;
import 'dart:io';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Usage: pubghost <command>');
    print('Commands:');
    print('  --deps     Check for unused dependencies');
    print('  --widgets  Check for unused classes/widgets');
    print('  --intl     Check ARB intl keys not used in code');
    exit(1);
  }

  switch (arguments.first) {
    case '--deps':
      pubghost.checkUnusedDependencies();
      break;
    case '--widgets':
      pubghost.checkUnusedWidgets();
      break;
    case '--intl':
      pubghost.checkUnusedIntlKeys();
      break;
    default:
      print('Unknown command: ${arguments.first}');
      print('Usage: pubghost <command>');
      print('Commands:');
      print('  --deps     Check for unused dependencies');
      print('  --widgets  Check for unused classes/widgets');
      print('  --intl     Check ARB intl keys not used in code');
      exit(1);
  }
}
