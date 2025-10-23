import 'package:pubghost/pubghost.dart';
import 'package:test/test.dart';

void main() {
  test('run', () {
    expect(run(), isA<Future<void>>());
  });
}
