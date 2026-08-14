import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/services/remote_terminal_output_controller.dart';
import 'package:codux_flutter/services/terminal_repaint_signal.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/models/workspace_mode.dart';
import 'package:codux_flutter/widgets/components/remote_terminal_pane.dart';
import 'package:codux_flutter/widgets/components/self_drawn_terminal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    await tester.tap(find.text('^C'));
    await tester.pump();

    expect(sent, ['\u0003']);
    expect(find.text('ctrl'), findsNothing);
  });

  testWidgets('ime open expands the toolbar to two rows', (tester) async {
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
            child: _pane(keyboardVisible: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('^C'), findsOneWidget);
    expect(find.text('ctrl'), findsOneWidget);
    expect(find.text('shft'), findsOneWidget);
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
}

RemoteTerminalPane _pane({
  ValueChanged<String>? onSendKey,
  bool keyboardVisible = false,
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
    handedAway: false,
    onTakeOver: () {},
  );
}
