import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/widgets/components/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toolbar expands from two primary rows to five grouped rows', () {
    expect(Toolbar.height, 88);
    expect(Toolbar.heightFor(expanded: false), 88);
    expect(Toolbar.heightFor(expanded: true), 202);
  });

  testWidgets('keeps both rows visible without the IME', (tester) async {
    await tester.pumpWidget(_toolbar(keyboardVisible: false));
    await tester.pump();

    expect(find.text('Tab'), findsOneWidget);
    expect(find.text('Ctrl'), findsOneWidget);
    expect(find.text('/'), findsOneWidget);
    expect(find.text('@'), findsNothing);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);
    expect(find.text('!'), findsNothing);
    expect(find.text('^C'), findsOneWidget);
    expect(find.text('Esc'), findsOneWidget);
    expect(find.byIcon(Icons.content_copy_rounded), findsNothing);
    expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_return_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_rounded), findsOneWidget);
  });

  testWidgets('shows the extra shortcuts in the expanded third row', (
    tester,
  ) async {
    await tester.pumpWidget(_toolbar(expanded: true));
    await tester.pump();

    expect(find.byType(InkWell), findsNWidgets(28));
    expect(find.text('@'), findsOneWidget);
    expect(find.text('Shift+Tab'), findsOneWidget);
    expect(find.text('^R'), findsOneWidget);
    expect(find.text('^O'), findsOneWidget);
    expect(find.text('^L'), findsOneWidget);
    expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Rebuild terminal'), findsOneWidget);
    expect(find.text('Edit project'), findsOneWidget);
    expect(find.text('Add project'), findsOneWidget);
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('!'), findsOneWidget);
    expect(find.text('/model'), findsNothing);
    expect(find.text('Git'), findsOneWidget);
    expect(find.text('Session History'), findsOneWidget);
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

    final escape = tester.getRect(buttons.at(0));
    final interrupt = tester.getRect(buttons.at(7));
    final keyboard = tester.getRect(buttons.at(6));
    final up = tester.getRect(buttons.at(4));
    final left = tester.getRect(buttons.at(10));
    final down = tester.getRect(buttons.at(11));
    final right = tester.getRect(buttons.at(12));
    final enter = tester.getRect(buttons.at(13));

    expect(
      find.descendant(of: buttons.at(7), matching: find.text('^C')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: buttons.at(6),
        matching: find.byIcon(Icons.keyboard_rounded),
      ),
      findsOneWidget,
    );

    expect(interrupt.left, lessThan(tester.getRect(buttons.at(8)).left));
    expect(escape.top, lessThan(interrupt.top));
    expect(keyboard.top, lessThan(interrupt.top));
    expect(up.center.dx, closeTo(down.center.dx, 0.5));
    expect(up.bottom, lessThan(down.top));
    expect(left.center.dy, closeTo(down.center.dy, 0.5));
    expect(right.center.dy, closeTo(down.center.dy, 0.5));
    expect(left.right, lessThan(down.left));
    expect(down.right, lessThan(right.left));
    expect(right.right, lessThan(enter.left));
  });

  testWidgets('ctrl c still sends etx from the bottom-left key', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(_toolbar(onSendKey: sent.add));
    await tester.pump();

    await tester.tap(find.text('^C'));
    await tester.pump();

    expect(sent, ['\u0003']);
  });

  testWidgets('expanded backspace sends the terminal backspace key', (
    tester,
  ) async {
    final sent = <String>[];
    await tester.pumpWidget(_toolbar(expanded: true, onSendKey: sent.add));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();

    expect(sent, ['\u007f']);
  });

  testWidgets('does not add a selection action to the bottom toolbar', (
    tester,
  ) async {
    await tester.pumpWidget(_toolbar());
    await tester.pump();

    expect(find.byType(InkWell), findsNWidgets(14));
    expect(find.byIcon(Icons.copy_all_rounded), findsNothing);
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
    expect(toolbar.right - topRight.right, closeTo(Toolbar.cornerInset, 0.001));
    expect(bottomLeft.left - toolbar.left, closeTo(Toolbar.cornerInset, 0.001));
    expect(
      toolbar.bottom - tester.getRect(buttons.at(12)).bottom,
      closeTo(Toolbar.cornerInset + Toolbar.verticalPadding, 0.001),
    );
  });
}

Widget _toolbar({
  bool keyboardVisible = false,
  bool expanded = false,
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
            applicationCursor: false,
            keyboardVisible: keyboardVisible,
            bottomInset: bottomInset,
            onToggleKeyboard: () {},
            expanded: expanded,
            onToggleMore: () {},
            onUpload: () {},
            onUploadAndPastePath: () {},
            uploadLoading: false,
            onShowGit: () {},
            onOpenSessions: () {},
            onShowStats: () {},
            onShowFiles: () {},
            onRebuildTerminal: () {},
            onEditProject: () {},
            onAddProject: () {},
          ),
        ),
      ),
    ),
  );
}
