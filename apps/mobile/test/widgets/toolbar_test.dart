import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/widgets/components/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toolbar is always two rows', () {
    expect(Toolbar.height, 76);
    expect(Toolbar.heightFor(expanded: false), 76);
    expect(Toolbar.heightFor(expanded: true), 76);
  });

  testWidgets('keeps both rows visible without the IME', (tester) async {
    await tester.pumpWidget(_toolbar(keyboardVisible: false));
    await tester.pump();

    expect(find.text('tab'), findsOneWidget);
    expect(find.text('ctrl'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('shft'), findsOneWidget);
    expect(find.text('^C'), findsOneWidget);
    expect(find.text('esc'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_return_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);
  });

  testWidgets('places interrupt, keyboard, and the inverted-T arrows', (
    tester,
  ) async {
    await tester.pumpWidget(_toolbar());
    await tester.pump();

    final buttons = find.descendant(
      of: find.byType(Toolbar),
      matching: find.byType(InkWell),
    );
    expect(buttons, findsNWidgets(14));

    final interrupt = tester.getRect(buttons.at(7));
    final keyboard = tester.getRect(buttons.at(6));
    final up = tester.getRect(buttons.at(5));
    final left = tester.getRect(buttons.at(11));
    final down = tester.getRect(buttons.at(12));
    final right = tester.getRect(buttons.at(13));

    expect(find.descendant(of: buttons.at(7), matching: find.text('^C')), findsOneWidget);
    expect(
      find.descendant(
        of: buttons.at(6),
        matching: find.byIcon(Icons.keyboard_rounded),
      ),
      findsOneWidget,
    );

    expect(interrupt.left, lessThan(tester.getRect(buttons.at(8)).left));
    expect(keyboard.top, lessThan(interrupt.top));
    expect(up.center.dx, closeTo(down.center.dx, 0.5));
    expect(up.bottom, lessThan(down.top));
    expect(left.center.dy, closeTo(down.center.dy, 0.5));
    expect(right.center.dy, closeTo(down.center.dy, 0.5));
    expect(left.right, lessThan(down.left));
    expect(down.right, lessThan(right.left));
  });

  testWidgets('ctrl c still sends etx from the bottom-left key', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_toolbar(onSendKey: sent.add));
    await tester.pump();

    await tester.tap(find.text('^C'));
    await tester.pump();

    expect(sent, ['\u0003']);
  });

  testWidgets('keeps edge keys inside the matching side and bottom inset', (
    tester,
  ) async {
    await tester.pumpWidget(_toolbar(bottomInset: Toolbar.cornerInset));
    await tester.pump();

    final toolbar = tester.getRect(find.byType(Toolbar));
    final buttons = find.descendant(
      of: find.byType(Toolbar),
      matching: find.byType(InkWell),
    );
    final topLeft = tester.getRect(buttons.at(0));
    final topRight = tester.getRect(buttons.at(6));
    final bottomLeft = tester.getRect(buttons.at(7));

    expect(topLeft.left - toolbar.left, closeTo(Toolbar.cornerInset, 0.001));
    expect(
      toolbar.right - topRight.right,
      closeTo(Toolbar.cornerInset, 0.001),
    );
    expect(bottomLeft.left - toolbar.left, closeTo(Toolbar.cornerInset, 0.001));
    expect(
      toolbar.bottom - tester.getRect(buttons.at(12)).bottom,
      closeTo(Toolbar.cornerInset + Toolbar.verticalPadding, 0.001),
    );
  });
}

Widget _toolbar({
  bool keyboardVisible = false,
  double bottomInset = 0,
  ValueChanged<String>? onSendKey,
}) {
  return MaterialApp(
    theme: buildAppTheme(),
    home: AppPreferences(
      accent: AccentChoices.cyan,
      locale: LocaleChoices.english,
      themeMode: ThemeMode.dark,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: 390,
          child: Toolbar(
            onSendKey: onSendKey ?? (_) {},
            onPaste: () {},
            onCopy: () {},
            applicationCursor: false,
            keyboardVisible: keyboardVisible,
            bottomInset: bottomInset,
            onToggleKeyboard: () {},
          ),
        ),
      ),
    ),
  );
}
