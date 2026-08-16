import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/services/remote_terminal_output_controller.dart';
import 'package:codux_flutter/services/terminal_repaint_signal.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/models/workspace_mode.dart';
import 'package:codux_flutter/widgets/components/remote_terminal_pane.dart';
import 'package:codux_flutter/widgets/components/self_drawn_terminal_view.dart';
import 'package:codux_flutter/widgets/components/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The tool FAB carries its own `^C` action, so scope toolbar key lookups to the
// toolbar itself instead of matching every `^C` on screen.
Finder _toolbarKey(String label) =>
    find.descendant(of: find.byType(Toolbar), matching: find.text(label));

void main() {
  testWidgets('terminal content starts at top of terminal body', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppPreferences(
          accent: AccentChoices.cyan,
          locale: LocaleChoices.english,
          themeMode: ThemeMode.dark,
          child: SizedBox(width: 360, height: 720, child: _pane()),
        ),
      ),
    );
    await tester.pump();

    final paneTop = tester.getTopLeft(find.byType(RemoteTerminalPane)).dy;
    final terminalTop = tester
        .getTopLeft(find.byKey(const ValueKey('remote-terminal-body')))
        .dy;

    expect(terminalTop, paneTop);
  });

  testWidgets('ctrl c toolbar sends etx directly', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppPreferences(
          accent: AccentChoices.cyan,
          locale: LocaleChoices.english,
          themeMode: ThemeMode.dark,
          child: SizedBox(
            width: 360,
            height: 720,
            child: _pane(onSendKey: sent.add),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(_toolbarKey('^C'));
    await tester.pump();

    expect(sent, ['\u0003']);
    expect(find.text('ctrl'), findsOneWidget);
  });

  testWidgets('toolbar keeps both rows without the IME', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppPreferences(
          accent: AccentChoices.cyan,
          locale: LocaleChoices.english,
          themeMode: ThemeMode.dark,
          child: SizedBox(
            width: 360,
            height: 720,
            child: _pane(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(_toolbarKey('^C'), findsOneWidget);
    expect(_toolbarKey('ctrl'), findsOneWidget);
    expect(_toolbarKey('shft'), findsOneWidget);
  });

  test('keyboard lift follows cursor visibility', () {
    expect(
      terminalLiftForKeyboardForTest(
        terminalHeight: 600,
        keyboardLift: 260,
        cursorMetrics: const TerminalCursorMetrics(
          row: 4,
          col: 0,
          lineHeight: 20,
        ),
      ),
      0,
    );
    expect(
      terminalLiftForKeyboardForTest(
        terminalHeight: 600,
        keyboardLift: 260,
        cursorMetrics: const TerminalCursorMetrics(
          row: 20,
          col: 0,
          lineHeight: 20,
        ),
      ),
      80,
    );
  });

  testWidgets('terminal tool fab exposes upload and voice actions', (
    tester,
  ) async {
    var uploadTapped = false;
    var voiceTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppPreferences(
          accent: AccentChoices.cyan,
          locale: LocaleChoices.english,
          themeMode: ThemeMode.dark,
          child: SizedBox(
            width: 360,
            height: 720,
            child: _pane(
              onUpload: () => uploadTapped = true,
              onVoice: () => voiceTapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Upload'), findsOneWidget);
    expect(find.text('Voice'), findsOneWidget);

    await tester.tap(find.text('Upload'));
    await tester.pump();
    expect(uploadTapped, isTrue);

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Voice'));
    await tester.pump();
    expect(voiceTapped, isTrue);
  });
}

RemoteTerminalPane _pane({
  ValueChanged<String>? onSendKey,
  bool keyboardVisible = false,
  VoidCallback? onUpload,
  VoidCallback? onVoice,
}) {
  return RemoteTerminalPane(
    connected: true,
    showTerminal: true,
    hasDevice: true,
    status: '',
    workspaceMode: WorkspaceMode.terminal,
    projectListLoaded: true,
    projectCount: 1,
    terminalUploadLoading: false,
    terminalUploadStatus: '',
    terminalBufferLoading: false,
    sessionId: 'session-1',
    pendingBufferSessionId: null,
    connectionStatusText: 'connecting',
    terminalHistoryLoadingText: 'loading',
    keyboardVisible: keyboardVisible,
    keyboardRequested: false,
    keyboardRequestSerial: 0,
    repaintSignal: TerminalRepaintSignal(),
    outputController: RemoteTerminalOutputController(),
    terminalFontSize: 16,
    onConnect: () {},
    onInput: (_) {},
    onResize: (_, _) {},
    onSelectionChanged: (_) {},
    onSendKey: onSendKey ?? (_) {},
    onToggleKeyboard: () {},
    onRequestKeyboard: () {},
    onPaste: () {},
    onCopy: () {},
    onUpload: onUpload ?? () {},
    onVoice: onVoice ?? () {},
    handedAway: false,
    handoffMessageKey: 'terminal.handoff.takenOver',
    onTakeOver: () {},
  );
}
