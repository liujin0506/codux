import 'package:codux_flutter/screens/home/home_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('superseded remote viewport pages are not painted', () {
    expect(
      shouldApplyTerminalViewportResponseForTest(
        responseOffset: 24,
        requestedOffset: 24,
        pendingOffset: 48,
      ),
      isFalse,
    );
    expect(
      shouldApplyTerminalViewportResponseForTest(
        responseOffset: 48,
        requestedOffset: 48,
        pendingOffset: 48,
      ),
      isTrue,
    );
    expect(
      shouldApplyTerminalViewportResponseForTest(
        responseOffset: 24,
        requestedOffset: 24,
        pendingOffset: null,
      ),
      isTrue,
    );
  });
}
