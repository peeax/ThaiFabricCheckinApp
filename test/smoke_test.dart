import 'package:flutter_test/flutter_test.dart';
import 'package:aewmai/core/constants.dart';

void main() {
  test('Thailand province count remains stable', () {
    expect(AppStrings.totalProvinces, 77);
  });
}
