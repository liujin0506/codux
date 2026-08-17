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
  testWidgets('shows terminal body with project context header', (tester) async {
    await tester.pumpWidget(_wrap(_terminalWorkspace()));

    expect(find.text('Terminal body'), findsOneWidget);
    expect(find.text('my-app'), findsOneWidget);
    expect(find.text('bash'), findsOneWidget);
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

    expect(find.text('Project'), findsWidgets);
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
                  path: 'lib/main.dart',
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

RemoteWorkspaceView _terminalWorkspace() {
  return RemoteWorkspaceView(
    topInset: 0,
    connected: true,
    latencyMs: 42,
    projectName: 'my-app',
    terminalTitle: 'bash',
    terminalBody: const Center(child: Text('Terminal body')),
    onShowStats: () {},
    onShowFiles: () {},
    onShowGit: () {},
    onBack: () {},
    onEditProject: () {},
    onAddProject: () {},
    onRemoveProject: () {},
    onOpenTerminalSwitcher: () {},
    onRebuildTerminal: () {},
  );
}
