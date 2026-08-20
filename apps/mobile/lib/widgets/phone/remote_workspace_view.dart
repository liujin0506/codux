import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../theme/app_theme.dart';
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
    required this.worktreeName,
    required this.terminalName,
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
  final String? worktreeName;
  final String? terminalName;
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
          projectName: projectName,
          worktreeName: worktreeName,
          terminalName: terminalName,
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
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              terminalBody,
              Positioned(
                top: AppSpacing.s,
                right: AppSpacing.m,
                child: IgnorePointer(
                  child: _TerminalLatencyBadge(
                    latencyMs: latencyMs,
                    connected: connected,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TerminalLatencyBadge extends StatelessWidget {
  const _TerminalLatencyBadge({
    required this.latencyMs,
    required this.connected,
  });

  final int? latencyMs;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final label = !connected
        ? AppPreferences.of(context).t('status.offline')
        : latencyMs != null
        ? '${latencyMs}ms'
        : '--';
    final color = _latencyColor(latencyMs, connected);
    return Container(
      key: const ValueKey('phone-terminal-latency'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color.withValues(alpha: 0.82),
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _latencyColor(int? value, bool connected) {
    if (!connected || value == null) return AppColors.textSubtle;
    if (value <= 300) return AppColors.success;
    if (value <= 800) return AppColors.warning;
    return AppColors.danger;
  }
}
