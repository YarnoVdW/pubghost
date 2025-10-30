import 'package:pubghost/pubghost.dart';

/// Demonstrates basic usage of the `pubghost` package.
///
/// This example shows how to run all checks programmatically:
/// - Unused dependencies
/// - Unused classes/widgets
/// - Unused ARB intl keys
///
/// This mirrors what the CLI commands `--deps`, `--widgets`, `--intl` do.
Future<void> main() async {
  print('=== Running dependency analysis ===');
  await checkUnusedDependencies();

  print('\n=== Running widget/class analysis ===');
  await checkUnusedWidgets();

  print('\n=== Running intl key analysis ===');
  await checkUnusedIntlKeys();
}
