import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/models/remote_models.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/widgets/components/terminal_switcher_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new split action is not rendered as the active split', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _switcher(
          terminals: const [
            TerminalInfo(
              id: 'split-1',
              title: 'One',
              projectId: 'project-1',
              layoutOrder: 0,
            ),
            TerminalInfo(
              id: 'split-2',
              title: 'Two',
              projectId: 'project-1',
              layoutOrder: 1,
            ),
          ],
          activeTerminalId: 'split-2',
          creating: true,
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('terminal-switcher-terminal-split-2')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    final addIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('terminal-switcher-add')),
        matching: find.byIcon(Icons.add_rounded),
      ),
    );
    final activeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('terminal-switcher-terminal-split-2')),
        matching: find.byIcon(Icons.terminal_rounded),
      ),
    );

    expect(addIcon.color, isNot(activeIcon.color));
  });

  testWidgets('project strip selects a different project', (tester) async {
    ProjectInfo? selected;
    await tester.pumpWidget(
      _wrap(
        _switcher(
          terminals: const [
            TerminalInfo(id: 'term-1', title: 'One', projectId: 'project-1'),
          ],
          activeTerminalId: 'term-1',
          projects: const [
            ProjectInfo(id: 'project-1', name: 'Alpha', path: '/tmp/a'),
            ProjectInfo(id: 'project-2', name: 'Beta', path: '/tmp/b'),
          ],
          onSelectProject: (project) => selected = project,
        ),
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    await tester.tap(find.text('Beta'));
    await tester.pump();

    expect(selected?.id, 'project-2');
  });

  testWidgets('project strip can remove a project', (tester) async {
    ProjectInfo? removed;
    await tester.pumpWidget(
      _wrap(
        _switcher(
          terminals: const [],
          activeTerminalId: null,
          onRemoveProject: (project) => removed = project,
          projects: const [
            ProjectInfo(id: 'project-1', name: 'Alpha', path: '/tmp/a'),
          ],
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('terminal-switcher-project-delete-project-1')),
    );
    await tester.pump();

    expect(removed?.id, 'project-1');
  });

  testWidgets('sessions tab lists history after worktrees', (tester) async {
    var opened = 0;
    var requested = 0;
    await tester.pumpWidget(
      _wrap(
        _switcher(
          terminals: const [
            TerminalInfo(id: 'term-1', title: 'One', projectId: 'project-1'),
          ],
          activeTerminalId: 'term-1',
          aiSessions: const [
            AISessionRecord(
              id: 'sess-1',
              title: 'Fix the toolbar',
              tool: 'claude',
              model: 'opus',
              time: 1755200000,
              size: 1200,
            ),
          ],
          onOpenSessions: () => requested += 1,
          onOpenSession: (_) => opened += 1,
        ),
      ),
    );

    expect(find.text('Terminals'), findsOneWidget);
    expect(find.text('Worktree'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);

    await tester.tap(find.text('Sessions'));
    await tester.pump();

    expect(requested, 1);
    expect(find.text('Fix the toolbar'), findsOneWidget);
    expect(find.textContaining('claude'), findsOneWidget);

    await tester.tap(find.text('Fix the toolbar'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('initial sessions section opens history directly', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        _switcher(
          terminals: const [],
          activeTerminalId: null,
          initialSection: TerminalSwitcherSection.sessions,
          aiSessions: const [
            AISessionRecord(
              id: 'sess-long',
              title:
                  'A very long conversation title that should stay on one line',
              tool: 'codex',
              model: 'gpt-5',
              time: 1755200000,
              size: 12000,
              inputTokens: 8000,
              outputTokens: 2000,
              cachedInputTokens: 2000,
              requestCount: 3,
              usageAmounts: [AIUsageAmount(unit: 'USD', value: 0.0192)],
            ),
          ],
        ),
      ),
    );

    expect(
      find.text('A very long conversation title that should stay on one line'),
      findsOneWidget,
    );
    expect(
      find.text(
        '12.0k · ↑ 8.0k · ↓ 2.0k · ⚡ 20% · 3 req · \$0.0192',
      ),
      findsOneWidget,
    );
  });

  test('session history parses detailed usage metrics', () {
    final session = AISessionRecord.fromJson({
      'id': 'sess-1',
      'title': 'Usage',
      'tool': 'codex',
      'time': 1,
      'size': 12,
      'inputTokens': 8,
      'outputTokens': 2,
      'cachedInputTokens': 2,
      'requestCount': 3,
      'usageAmounts': [
        {'unit': 'USD', 'value': 0.0192},
      ],
    });

    expect(session.inputTokens, 8);
    expect(session.outputTokens, 2);
    expect(session.cachedInputTokens, 2);
    expect(session.requestCount, 3);
    expect(session.usageAmounts.single.unit, 'USD');
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(accent: AccentChoices.cyan.color),
    home: AppPreferences(
      accent: AccentChoices.cyan,
      locale: LocaleChoices.english,
      themeMode: ThemeMode.dark,
      child: child,
    ),
  );
}

TerminalSwitcherScreen _switcher({
  required List<TerminalInfo> terminals,
  required String? activeTerminalId,
  bool creating = false,
  List<ProjectInfo> projects = const [
    ProjectInfo(id: 'project-1', name: 'Project 1', path: '/tmp/p1'),
  ],
  List<AISessionRecord> aiSessions = const [],
  TerminalSwitcherSection initialSection = TerminalSwitcherSection.terminals,
  VoidCallback? onOpenSessions,
  ValueChanged<AISessionRecord>? onOpenSession,
  ValueChanged<ProjectInfo>? onSelectProject,
  ValueChanged<ProjectInfo>? onRemoveProject,
}) {
  return TerminalSwitcherScreen(
    topInset: 0,
    bottomInset: 0,
    projects: projects,
    terminals: terminals,
    worktrees: const [],
    activeTerminalId: activeTerminalId,
    selectedProjectId: 'project-1',
    selectedWorktreeId: 'project-1',
    switchingWorktreeId: null,
    loadingWorktrees: false,
    creating: creating,
    creatingWorktree: false,
    onBack: () {},
    onSelectProject: onSelectProject ?? (_) {},
    onAddProject: () {},
    onRemoveProject: onRemoveProject ?? (_) {},
    onSelectTerminal: (_) {},
    onCreateTerminal: () {},
    onCloseTerminal: (_) {},
    onSelectWorktree: (_) {},
    onCreateWorktree: () {},
    onMergeWorktree: (_) {},
    onDeleteWorktree: (_) {},
    onOpenWorktrees: () {},
    onRefreshWorktrees: () {},
    onRefreshTerminals: () {},
    aiSessions: aiSessions,
    onOpenSessions: onOpenSessions ?? () {},
    initialSection: initialSection,
    onRefreshSessions: () {},
    onOpenSession: onOpenSession ?? (_) {},
    onRenameSession: (_) {},
    onDeleteSession: (_) {},
  );
}
