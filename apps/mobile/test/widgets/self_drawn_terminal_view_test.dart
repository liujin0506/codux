import 'package:codux_protocol_ffi/codux_protocol_ffi.dart';
import 'package:codux_flutter/models/remote_models.dart';
import 'package:codux_flutter/services/remote_terminal_output_controller.dart';
import 'package:codux_flutter/widgets/components/self_drawn_terminal_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the Rust cell snapshot and reports a sane grid size', (
    tester,
  ) async {
    final controller = RemoteTerminalOutputController();
    addTearDown(controller.dispose);
    controller.bindSession('session-1', requireBaseline: true);
    controller.accept(
      const RelayEnvelope(
        type: 'terminal.output',
        sessionId: 'session-1',
        payload: {
          'data': 'hello world',
          'screenData': '[2J[Hhello world',
          'buffer': true,
          'offset': 0,
          'bufferLength': 11,
          'tail': true,
          'outputSeq': 1,
        },
      ),
      activeSessionId: 'session-1',
    );

    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);
    int? reportedCols;
    int? reportedRows;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: SelfDrawnTerminalView(
              sessionId: 'session-1',
              controller: controller,
              repaintSignal: signal,
              fontSize: 14,
              onResize: (cols, rows) {
                reportedCols = cols;
                reportedRows = rows;
              },
            ),
          ),
        ),
      ),
    );

    // Drain the post-frame resize + snapshot refresh callbacks.
    await tester.pump();
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(reportedCols, isNotNull);
    expect(reportedRows, isNotNull);
    expect(reportedCols!, greaterThan(0));
    expect(reportedRows!, greaterThan(0));

    // A new output signal must re-read the snapshot and repaint without error.
    signal.value = 1;
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-press then drag selects text and reports it', (
    tester,
  ) async {
    final controller = RemoteTerminalOutputController();
    addTearDown(controller.dispose);
    controller.bindSession('session-1', requireBaseline: true);
    controller.accept(
      const RelayEnvelope(
        type: 'terminal.output',
        sessionId: 'session-1',
        payload: {
          'data': 'hello world',
          'buffer': true,
          'offset': 0,
          'bufferLength': 11,
          'tail': true,
          'outputSeq': 1,
        },
      ),
      activeSessionId: 'session-1',
    );

    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);
    String? selected = '';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: SelfDrawnTerminalView(
              sessionId: 'session-1',
              controller: controller,
              repaintSignal: signal,
              fontSize: 14,
              onSelectionChanged: (text) => selected = text,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(SelfDrawnTerminalView));
    final gesture = await tester.startGesture(origin + const Offset(6, 8));
    await tester.pump(const Duration(milliseconds: 600)); // long-press fires
    await gesture.moveBy(const Offset(90, 0)); // extend across the first line
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(selected, isNotNull);
    expect(selected, isNotEmpty);
  });

  testWidgets('tapping a terminal URL reports it to the owner', (tester) async {
    const url = 'https://example.com/docs.';
    final controller = _StaticTerminalController(_snapshotForText(url));
    addTearDown(controller.dispose);

    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);
    Uri? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: SelfDrawnTerminalView(
              sessionId: 'session-1',
              controller: controller,
              repaintSignal: signal,
              fontSize: 14,
              onOpenUrl: (uri) => opened = uri,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(SelfDrawnTerminalView));
    await tester.tapAt(origin + const Offset(5, 8));
    await tester.pump();

    expect(opened, Uri.parse('https://example.com/docs'));
  });

  testWidgets('tapping an OSC 8 terminal link uses its target URI', (
    tester,
  ) async {
    final controller = _StaticTerminalController(
      _snapshotForText('Open', link: 'https://example.com/open'),
    );
    addTearDown(controller.dispose);
    Uri? opened;
    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: SelfDrawnTerminalView(
            sessionId: 'session-1',
            controller: controller,
            repaintSignal: signal,
            fontSize: 14,
            onOpenUrl: (uri) => opened = uri,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final origin = tester.getTopLeft(find.byType(SelfDrawnTerminalView));
    await tester.tapAt(origin + const Offset(5, 8));
    await tester.pump();

    expect(opened, Uri.parse('https://example.com/open'));
  });

  testWidgets('renders terminal built-in box drawing cells', (tester) async {
    final controller = RemoteTerminalOutputController();
    addTearDown(controller.dispose);
    controller.bindSession('session-1', requireBaseline: true);
    controller.accept(
      const RelayEnvelope(
        type: 'terminal.output',
        sessionId: 'session-1',
        payload: {
          'data': '┌─┐\n│█│\n└─┘',
          'screenData': '[2J[H┌─┐\r\n│█│\r\n└─┘',
          'buffer': true,
          'offset': 0,
          'bufferLength': 11,
          'tail': true,
          'outputSeq': 1,
        },
      ),
      activeSessionId: 'session-1',
    );

    final signal = ValueNotifier<int>(0);
    addTearDown(signal.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 480,
            child: SelfDrawnTerminalView(
              sessionId: 'session-1',
              controller: controller,
              repaintSignal: signal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _StaticTerminalController extends RemoteTerminalOutputController {
  _StaticTerminalController(this._snapshot);

  final TerminalScreenSnapshot _snapshot;

  @override
  TerminalScreenSnapshot? screenSnapshot(String sessionId) => _snapshot;

  @override
  int renderGeneration(String sessionId) => 1;

  @override
  void resizeScreen(String sessionId, {required int cols, required int rows}) {}
}

TerminalScreenSnapshot _snapshotForText(String text, {String? link}) {
  return TerminalScreenSnapshot(
    data: '',
    cols: 40,
    rows: 20,
    totalLines: 20,
    displayOffset: 0,
    scrollPixelOffset: 0,
    applicationCursor: false,
    cells: [
      for (var index = 0; index < text.length; index++)
        TerminalScreenCell(
          row: 0,
          col: index,
          text: text[index],
          width: 1,
          fg: const {},
          bg: const {},
          bold: false,
          dim: false,
          italic: false,
          underline: TerminalScreenUnderline.none,
          link: link,
          inverse: false,
          hidden: false,
          strikeout: false,
        ),
    ],
    cursor: const TerminalScreenCursor(
      row: 0,
      col: 0,
      visible: false,
      shape: TerminalScreenCursorShape.block,
    ),
  );
}
