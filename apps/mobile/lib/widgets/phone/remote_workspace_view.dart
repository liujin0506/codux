import 'package:flutter/material.dart';

import 'phone_workspace_header.dart';

/// Phone workspace: terminal header + terminal body. Tool screens open as
/// full-screen routes (see [HomeController._openPhoneStats] and siblings).
class RemoteWorkspaceView extends StatelessWidget {
  const RemoteWorkspaceView({
    super.key,
    required this.topInset,
    required this.connected,
    required this.latencyMs,
    required this.projectName,
    required this.terminalTitle,
    required this.terminalBody,
    required this.onShowStats,
    required this.onShowFiles,
    required this.onShowGit,
    required this.onBack,
    required this.onEditProject,
    required this.onAddProject,
    required this.onOpenTerminalSwitcher,
    required this.onSwitchProject,
    required this.onRebuildTerminal,
  });

  final double topInset;
  final bool connected;
  final int? latencyMs;
  final String? projectName;
  final String? terminalTitle;
  final Widget terminalBody;
  final VoidCallback onShowStats;
  final VoidCallback onShowFiles;
  final VoidCallback onShowGit;
  final VoidCallback onBack;
  final VoidCallback onEditProject;
  final VoidCallback onAddProject;
  final VoidCallback onOpenTerminalSwitcher;
  final VoidCallback onSwitchProject;
  final VoidCallback onRebuildTerminal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PhoneWorkspaceHeader(
          topInset: topInset,
          connected: connected,
          latencyMs: connected ? latencyMs : null,
          projectName: projectName,
          terminalTitle: terminalTitle,
          onBack: onBack,
          onOpenSwitcher: onOpenTerminalSwitcher,
          onSwitchProject: onSwitchProject,
          onShowStats: onShowStats,
          onShowFiles: onShowFiles,
          onShowGit: onShowGit,
          onEditProject: onEditProject,
          onAddProject: onAddProject,
          onRebuildTerminal: onRebuildTerminal,
        ),
        Expanded(child: terminalBody),
      ],
    );
  }
}
