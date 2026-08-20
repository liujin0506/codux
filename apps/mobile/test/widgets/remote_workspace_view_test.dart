import 'package:codux_flutter/i18n.dart';
import 'package:codux_flutter/models/remote_models.dart';
import 'package:codux_flutter/theme/app_theme.dart';
import 'package:codux_flutter/widgets/components/ai_stats_panel.dart';
import 'package:codux_flutter/widgets/components/project_files_panel.dart';
import 'package:codux_flutter/widgets/pad/pad_tool_panels.dart';
import 'package:codux_flutter/widgets/phone/phone_tool_screens.dart';
import 'package:codux_flutter/widgets/phone/remote_workspace_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows project header and terminal context', (tester) async {
    await tester.pumpWidget(_wrap(_terminalWorkspace()));

    expect(find.text('Terminal body'), findsOneWidget);
    expect(find.text('my-app'), findsOneWidget);
    expect(find.text('feature/login  /  zsh'), findsOneWidget);
    expect(find.text('42ms'), findsOneWidget);
  });

  testWidgets('tapping terminal context opens the switcher', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _wrap(_terminalWorkspace(onOpenTerminalSwitcher: () => opened = true)),
    );

    await tester.tap(find.text('feature/login  /  zsh'));

    expect(opened, isTrue);
  });

  testWidgets('phone tool route can read app preferences', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(accent: AccentChoices.cyan.color),
        builder: (context, child) {
          return AppPreferences(
            accent: AccentChoices.cyan,
            locale: LocaleChoices.english,
            themeMode: ThemeMode.dark,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: Builder(
          builder: (homeContext) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(homeContext).push<void>(
                      MaterialPageRoute(
                        builder: (routeContext) => PhoneToolScreen(
                          topInset: 0,
                          title: 'Stats',
                          onBack: () => Navigator.of(routeContext).pop(),
                          child: AIStatsPanel(
                            stats: const AIStatsInfo(
                              projectName: 'Project',
                              todayTokens: 1,
                              totalTokens: 2,
                              currentSessionTokens: 3,
                              requestCount: 4,
                            ),
                            loading: false,
                            onRefresh: () {},
                          ),
                        ),
                      ),
                    );
                  },
                  child: const Text('Open stats'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open stats'));
    await tester.pumpAndSettle();

    expect(find.text('Current project'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);
  });

  testWidgets('phone tool screen shows stats panel', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PhoneToolScreen(
          topInset: 0,
          title: 'Stats',
          onBack: () {},
          child: AIStatsPanel(
            stats: const AIStatsInfo(
              projectName: 'Project',
              todayTokens: 1,
              totalTokens: 2,
              currentSessionTokens: 3,
              requestCount: 4,
            ),
            loading: false,
            onRefresh: () {},
          ),
        ),
      ),
    );

    expect(find.text('Current project'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
  });

  testWidgets('stats recovery actions appear only after a slow load', (
    tester,
  ) async {
    var refreshed = false;
    var logsOpened = false;
    await tester.pumpWidget(
      _wrap(
        AIStatsPanel(
          stats: null,
          loading: true,
          onRefresh: () => refreshed = true,
          onShowLogs: () => logsOpened = true,
        ),
      ),
    );

    expect(find.text('AI Stats · Syncing'), findsOneWidget);
    expect(find.text('Refresh'), findsNothing);
    expect(find.text('Debug logs'), findsNothing);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Debug logs'), findsOneWidget);

    await tester.tap(find.text('Refresh'));
    await tester.tap(find.text('Debug logs'));
    expect(refreshed, isTrue);
    expect(logsOpened, isTrue);
  });

  testWidgets('phone tool screen shows file panel', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PhoneToolScreen(
          topInset: 0,
          title: 'Files',
          onBack: () {},
          child: ProjectFilesPanel(
            path: '/repo',
            parent: null,
            entries: const [
              RemoteFileEntry(
                name: 'main.dart',
                path: '/repo/main.dart',
                isDirectory: false,
              ),
            ],
            loading: false,
            onOpenPath: (_) {},
            onOpenFile: (_) {},
            onRefresh: () {},
            onOpenHome: () {},
            onOpenRoot: () {},
            onOpenVolumes: () {},
            onRename: (_) {},
            onCopyPath: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('/repo'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);
  });

  testWidgets('phone tool screen shows git panel', (tester) async {
    await tester.pumpWidget(
      _wrap(
        PhoneToolScreen(
          topInset: 0,
          title: 'Git · my-app',
          onBack: () {},
          child: PadGitToolPanel(
            gitStatus: const RemoteGitStatusInfo(
              projectId: 'project-1',
              projectPath: '/repo',
              branch: 'main',
              changes: 1,
              staged: 0,
              unstaged: 1,
              untracked: 0,
              ahead: 0,
              behind: 0,
              isRepository: true,
              changedFiles: [
                RemoteGitFileStatus(
                  path: 'main.dart',
                  indexStatus: 'modified',
                  worktreeStatus: 'modified',
                ),
              ],
            ),
            onAction: (_, _) {},
            onRefresh: () {},
            onOpenFile: (_) {},
            panelWidth: null,
          ),
        ),
      ),
    );

    expect(find.text('Git · my-app'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(accent: AccentChoices.cyan.color),
    home: AppPreferences(
      accent: AccentChoices.cyan,
      locale: LocaleChoices.english,
      themeMode: ThemeMode.dark,
      child: Scaffold(body: child),
    ),
  );
}

RemoteWorkspaceView _terminalWorkspace({VoidCallback? onOpenTerminalSwitcher}) {
  return RemoteWorkspaceView(
    topInset: 0,
    connected: true,
    latencyMs: 42,
    projectName: 'my-app',
    worktreeName: 'feature/login',
    terminalName: 'zsh',
    terminalBody: const Center(child: Text('Terminal body')),
    onShowStats: () {},
    onShowFiles: () {},
    onShowGit: () {},
    onBack: () {},
    onEditProject: () {},
    onAddProject: () {},
    onOpenTerminalSwitcher: onOpenTerminalSwitcher ?? () {},
    onSwitchProject: () {},
    onRebuildTerminal: () {},
  );
}
