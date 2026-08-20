import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/models/workspace_mode.dart';
import 'package:codux_flutter/services/remote_terminal_output_controller.dart';
import 'package:codux_flutter/services/terminal_repaint_signal.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/widgets/components/remote_terminal_pane.dart';
import 'package:codux_flutter/widgets/components/self_drawn_terminal_view.dart';
import 'package:codux_flutter/widgets/components/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _key(String label) =>
    find.descendant(of: find.byType(Toolbar), matching: find.text(label));

void main() {
  testWidgets('terminal content starts at the top', (tester) async {
    await tester.pumpWidget(_host(_pane()));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('remote-terminal-body'))).dy,
      tester.getTopLeft(find.byType(RemoteTerminalPane)).dy,
    );
  });

  testWidgets('ctrl c sends etx', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(_host(_pane(onSendKey: sent.add)));
    await tester.pump();
    await tester.tap(_key('^C'));
    expect(sent, ['\u0003']);
  });

  testWidgets('more button expands and collapses the third row', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_pane()));
    await tester.pump();
    expect(_key('@'), findsNothing);
    expect(find.byIcon(Icons.apps_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    expect(_key('@'), findsOneWidget);
    expect(_key('Shift+Tab'), findsOneWidget);
    expect(_key('^R'), findsOneWidget);
    expect(_key('^O'), findsOneWidget);
    expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(_key('@'), findsNothing);
  });

  testWidgets('expanded panel exposes upload-path action', (tester) async {
    var upload = false;
    await tester.pumpWidget(
      _host(_pane(onUploadAndPastePath: () => upload = true)),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.file_upload_outlined));
    expect(upload, isTrue);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
  });

  testWidgets('expanded panel calls existing Git and session features', (
    tester,
  ) async {
    var git = false;
    var sessions = false;
    await tester.pumpWidget(
      _host(
        _pane(
          onShowGit: () => git = true,
          onOpenSessions: () => sessions = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.apps_rounded));
    await tester.pump();
    await tester.tap(find.text('Git'));
    await tester.tap(find.text('Session History'));
    expect(git, isTrue);
    expect(sessions, isTrue);
  });

  testWidgets('handoff action shows progress while takeover is pending', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_pane(handedAway: true, takeOverPending: true)),
    );
    await tester.pump();

    expect(find.text('Restoring terminal…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('terminal-take-over')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('horizontal swipes switch terminal with direction feedback', (
    tester,
  ) async {
    final directions = <int>[];
    await tester.pumpWidget(
      _host(
        _pane(
          onSwipeTerminal: (direction) {
            directions.add(direction);
            return direction > 0 ? 'Terminal 2' : 'Terminal 1';
          },
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byType(SelfDrawnTerminalView),
      const Offset(-120, 0),
    );
    await tester.pump();
    expect(directions, [1]);
    expect(find.text('Terminal 2'), findsOneWidget);

    await tester.drag(find.byType(SelfDrawnTerminalView), const Offset(120, 0));
    await tester.pump();
    expect(directions, [1, -1]);
    expect(find.text('Terminal 1'), findsOneWidget);
  });

  testWidgets('terminal selection disables swipe switching', (tester) async {
    var switched = false;
    await tester.pumpWidget(
      _host(
        _pane(
          hasSelection: true,
          onSwipeTerminal: (_) {
            switched = true;
            return 'Terminal 2';
          },
        ),
      ),
    );
    await tester.pump();

    await tester.drag(
      find.byType(SelfDrawnTerminalView),
      const Offset(-120, 0),
    );
    await tester.pump();
    expect(switched, isFalse);
  });

  testWidgets('selection actions stay above the terminal', (tester) async {
    var copied = false;
    var copiedAndPasted = false;
    await tester.pumpWidget(
      _host(
        _pane(
          hasSelection: true,
          onCopy: () => copied = true,
          onCopyAndPaste: () => copiedAndPasted = true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Copy'));
    await tester.tap(find.text('Copy and paste'));
    expect(copied, isTrue);
    expect(copiedAndPasted, isTrue);
  });

  testWidgets('disconnected pane shows reconnect hint', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(_pane(connected: false, onConnect: () => tapped = true)),
    );
    await tester.pump();
    expect(find.text('Tap to reconnect'), findsOneWidget);
    await tester.tap(find.text('Reconnect'));
    expect(tapped, isTrue);
  });

  testWidgets(
    'keyboard lays terminal out above toolbar without translating it',
    (tester) async {
      await tester.pumpWidget(_host(_pane(), keyboardInset: 300));
      await tester.pump();

      final body = tester.getRect(
        find.byKey(const ValueKey('remote-terminal-body')),
      );
      final toolbar = tester.getRect(find.byType(Toolbar));
      expect(body.top, 0);
      expect(body.bottom, closeTo(toolbar.top, 0.1));
      expect(body.height, greaterThan(120));
      expect(find.byType(SelfDrawnTerminalView), findsOneWidget);
    },
  );

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

Widget _host(Widget child, {double keyboardInset = 0}) => MaterialApp(
  theme: buildAppTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(360, 720),
      viewInsets: EdgeInsets.only(bottom: keyboardInset),
    ),
    child: AppPreferences(
      accent: AccentChoices.cyan,
      locale: LocaleChoices.english,
      themeMode: ThemeMode.dark,
      child: SizedBox(width: 360, height: 720, child: child),
    ),
  ),
);

RemoteTerminalPane _pane({
  ValueChanged<String>? onSendKey,
  bool connected = true,
  VoidCallback? onConnect,
  VoidCallback? onCopy,
  VoidCallback? onCopyAndPaste,
  bool hasSelection = false,
  VoidCallback? onUploadAndPastePath,
  VoidCallback? onShowGit,
  VoidCallback? onOpenSessions,
  String? Function(int direction)? onSwipeTerminal,
  bool handedAway = false,
  bool takeOverPending = false,
}) => RemoteTerminalPane(
  connected: connected,
  showTerminal: connected,
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
  keyboardVisible: false,
  keyboardRequested: false,
  keyboardRequestSerial: 0,
  repaintSignal: TerminalRepaintSignal(),
  outputController: RemoteTerminalOutputController(),
  terminalFontSize: 16,
  reconnecting: false,
  onConnect: onConnect ?? () {},
  onInput: (_) {},
  onResize: (_, _) {},
  onSelectionChanged: (_) {},
  onSendKey: onSendKey ?? (_) {},
  onToggleKeyboard: () {},
  onRequestKeyboard: () {},
  onPaste: () {},
  onCopy: onCopy ?? () {},
  onCopyAndPaste: onCopyAndPaste,
  hasSelection: hasSelection,
  onSwipeTerminal: onSwipeTerminal,
  onUpload: () {},
  onUploadAndPastePath: onUploadAndPastePath,
  onShowGit: onShowGit ?? () {},
  onOpenSessions: onOpenSessions ?? () {},
  onShowStats: () {},
  onShowFiles: () {},
  onRebuildTerminal: () {},
  onEditProject: () {},
  onAddProject: () {},
  handedAway: handedAway,
  takeOverPending: takeOverPending,
  handoffMessageKey: 'terminal.handoff.takenOver',
  onTakeOver: () {},
);
