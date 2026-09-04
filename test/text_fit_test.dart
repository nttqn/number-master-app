import 'package:flutter_test/flutter_test.dart';
import 'package:number_master/game/components/text_fit.dart';

void main() {
  test('short text keeps the desired font size', () {
    final size = fitFontSize(textLength: 2, desiredFontSize: 30, maxWidth: 100);
    expect(size, 30);
  });

  test('long text shrinks to fit within maxWidth', () {
    const desired = 30.0;
    final size = fitFontSize(textLength: 8, desiredFontSize: desired, maxWidth: 100);
    expect(size, lessThan(desired));
    expect(size, greaterThan(0));
  });

  test('shrinking scales down as text gets longer', () {
    final shortSize = fitFontSize(textLength: 4, desiredFontSize: 30, maxWidth: 100);
    final longSize = fitFontSize(textLength: 10, desiredFontSize: 30, maxWidth: 100);
    expect(longSize, lessThan(shortSize));
  });

  test('never divides by zero or returns a non-finite size', () {
    expect(fitFontSize(textLength: 0, desiredFontSize: 30, maxWidth: 100), 30);
    expect(fitFontSize(textLength: 5, desiredFontSize: 30, maxWidth: 0).isFinite, isTrue);
  });
}
