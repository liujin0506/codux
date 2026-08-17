import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/services/remote_terminal_output_controller.dart';
import 'package:codux_flutter/services/terminal_repaint_signal.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/models/workspace_mode.dart';
import 'package:codux_flutter/widgets/components/remote_terminal_pane.dart';
import 'package:codux_flutter/services/remote_capabilities.dart';
import 'package:codux_flutter/widgets/components/self_drawn_terminal_view.dart';
import 'package:codux_flutter/widgets/components/terminal_tool_fab.dart';
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

  testWidgets('terminal tool fab lifts with the keyboard inset', (tester) async {
    Future<double> fabDistanceFromBottom(double keyboardInset) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MediaQuery(
            data: MediaQueryData(
              viewInsets: EdgeInsets.only(bottom: keyboardInset),
              size: const Size(360, 720),
            ),
            child: AppPreferences(
              accent: AccentChoices.cyan,
              locale: LocaleChoices.english,
              themeMode: ThemeMode.dark,
              child: SizedBox(width: 360, height: 720, child: _pane()),
            ),
          ),
        ),
      );
      await tester.pump();

      final paneBottom = tester.getBottomLeft(find.byType(RemoteTerminalPane)).dy;
      final fabBottom = tester.getBottomLeft(find.byType(TerminalToolFab)).dy;
      return paneBottom - fabBottom;
    }

    final restingOffset = await fabDistanceFromBottom(0);
    final keyboardOffset = await fabDistanceFromBottom(300);

    expect(keyboardOffset, greaterThan(restingOffset + 250));
  });

  testWidgets('disconnected terminal pane shows reconnect hint', (tester) async {
    var reconnectTapped = false;
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
              connected: false,
              onConnect: () => reconnectTapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tap to reconnect'), findsOneWidget);
    expect(find.text('Reconnect'), findsOneWidget);

    await tester.tap(find.text('Reconnect'));
    await tester.pump();
    expect(reconnectTapped, isTrue);
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

  testWidgets('terminal tool fab hides the ai shortcut without a host command', (
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

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('AI'), findsNothing);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsNothing);
  });

  testWidgets('terminal tool fab runs the host ai commands with a submit', (
    tester,
  ) async {
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
            child: _pane(
              onSendKey: sent.add,
              aiTool: const MobileAiToolCapability([
                MobileAiCommand(command: 'claude', label: 'Claude'),
                MobileAiCommand(command: 'codex'),
              ]),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The host-supplied caption wins; the entry without one falls back to the
    // app's translation.
    expect(find.text('Claude'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);

    await tester.tap(find.text('Claude'));
    await tester.pump();

    // Typed as text, then submitted with a carriage return.
    expect(sent, ['claude', '\r']);

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('AI'));
    await tester.pump();

    expect(sent, ['claude', '\r', 'codex', '\r']);
  });
}

RemoteTerminalPane _pane({
  ValueChanged<String>? onSendKey,
  bool keyboardVisible = false,
  bool connected = true,
  bool? showTerminal,
  bool reconnecting = false,
  VoidCallback? onConnect,
  VoidCallback? onUpload,
  VoidCallback? onVoice,
  MobileAiToolCapability aiTool = MobileAiToolCapability.fallback,
}) {
  return RemoteTerminalPane(
    connected: connected,
    showTerminal: showTerminal ?? connected,
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
    reconnecting: reconnecting,
    onConnect: onConnect ?? () {},
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
    aiTool: aiTool,
    handoffMessageKey: 'terminal.handoff.takenOver',
    onTakeOver: () {},
  );
}
