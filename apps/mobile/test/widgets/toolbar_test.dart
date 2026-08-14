import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/widgets/components/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('collapsed toolbar is one row, expanded is two', () {
    expect(Toolbar.heightFor(expanded: false), 40);
    expect(Toolbar.heightFor(expanded: true), 76);
  });

  testWidgets('hides the extra coding keys until the IME is open', (
    tester,
  ) async {
    await tester.pumpWidget(_toolbar(keyboardVisible: false));
    await tester.pump();

    expect(find.text('esc'), findsOneWidget);
    expect(find.text('tab'), findsOneWidget);
    expect(find.text('^C'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_return_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);

    expect(find.text('ctrl'), findsNothing);
    expect(find.text('/'), findsNothing);
    expect(find.text('shft'), findsNothing);
    expect(find.byIcon(Icons.content_paste_rounded), findsNothing);
    expect(find.byIcon(Icons.content_copy_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(find.byIcon(Icons.upload_file_rounded), findsNothing);
    expect(find.byIcon(Icons.backspace_outlined), findsNothing);
  });

  testWidgets('shows the second row after the IME opens', (tester) async {
    await tester.pumpWidget(_toolbar(keyboardVisible: true));
    await tester.pump();

    expect(find.text('esc'), findsOneWidget);
    expect(find.text('tab'), findsOneWidget);
    expect(find.text('^C'), findsOneWidget);
    expect(find.text('ctrl'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('shft'), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_hide_rounded), findsOneWidget);
  });

  testWidgets('ctrl c still sends etx from the first row', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_toolbar(onSendKey: sent.add));
    await tester.pump();

    await tester.tap(find.text('^C'));
    await tester.pump();

    expect(sent, ['\u0003']);
  });

  testWidgets('keeps edge keys inside the rounded-corner inset', (tester) async {
    await tester.pumpWidget(_toolbar());
    await tester.pump();

    final toolbar = tester.getRect(find.byType(Toolbar));
    final buttons = find.descendant(
      of: find.byType(Toolbar),
      matching: find.byType(InkWell),
    );

    expect(
      tester.getRect(buttons.at(0)).left - toolbar.left,
      closeTo(Toolbar.cornerInset, 0.001),
    );
    expect(
      toolbar.right - tester.getRect(buttons.at(6)).right,
      closeTo(Toolbar.cornerInset, 0.001),
    );
  });
}

Widget _toolbar({
  bool keyboardVisible = false,
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
            bottomInset: 0,
            onToggleKeyboard: () {},
          ),
        ),
      ),
    ),
  );
}
