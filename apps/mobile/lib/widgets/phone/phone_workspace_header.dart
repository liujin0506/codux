import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../models/workspace_mode.dart';
import '../../theme/app_theme.dart';
import 'phone_workspace_menu.dart';

/// Single-row phone workspace chrome: back, project/terminal context, latency,
/// and the overflow menu for tools + project actions.
class PhoneWorkspaceHeader extends StatelessWidget {
  const PhoneWorkspaceHeader({
    super.key,
    required this.topInset,
    required this.connected,
    required this.projectName,
    required this.terminalTitle,
    required this.onBack,
    required this.onOpenSwitcher,
    required this.onShowStats,
    required this.onShowFiles,
    required this.onShowGit,
    required this.onEditProject,
    required this.onAddProject,
    required this.onRemoveProject,
    this.latencyMs,
    this.onRebuildTerminal,
  });

  static const barHeight = 48.0;

  final double topInset;
  final bool connected;
  final int? latencyMs;
  final String? projectName;
  final String? terminalTitle;
  final VoidCallback onBack;
  final VoidCallback onOpenSwitcher;
  final VoidCallback onShowStats;
  final VoidCallback onShowFiles;
  final VoidCallback onShowGit;
  final VoidCallback onEditProject;
  final VoidCallback onAddProject;
  final VoidCallback onRemoveProject;
  final VoidCallback? onRebuildTerminal;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    final projectLabel =
        projectName?.trim().isNotEmpty == true
            ? projectName!.trim()
            : prefs.t('project.selectFirst');
    final terminalLabel = terminalTitle?.trim();

    return Material(
      color: AppColors.bgBase,
      child: Container(
        height: barHeight + topInset,
        padding: EdgeInsets.only(top: topInset),
        decoration: const BoxDecoration(color: AppColors.bgBase),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  onTap: onOpenSwitcher,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.s,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                projectLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              if (terminalLabel != null &&
                                  terminalLabel.isNotEmpty)
                                Text(
                                  terminalLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSubtle,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.2,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.unfold_more_rounded,
                          size: 18,
                          color: accent.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _HeaderLatencyText(
              latencyMs: latencyMs,
              connected: connected,
            ),
            PhoneWorkspaceMenu(
              onShowStats: onShowStats,
              onShowGit: onShowGit,
              onShowFiles: onShowFiles,
              onOpenSwitcher: onOpenSwitcher,
              onRebuildTerminal: onRebuildTerminal,
              onEditProject: onEditProject,
              onAddProject: onAddProject,
              onRemoveProject: onRemoveProject,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact header for stats / git / files tool screens on phone.
class PhoneToolHeader extends StatelessWidget {
  const PhoneToolHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onRefresh,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      child: SizedBox(
        height: PhoneWorkspaceHeader.barHeight,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onRefresh != null)
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textPrimary,
                ),
              )
            else
              const SizedBox(width: AppSpacing.s),
          ],
        ),
      ),
    );
  }
}

class _HeaderLatencyText extends StatelessWidget {
  const _HeaderLatencyText({required this.latencyMs, required this.connected});

  final int? latencyMs;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final label = connected && latencyMs != null ? '${latencyMs}ms' : '--';
    final color = _latencyColor(latencyMs, connected);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Color _latencyColor(int? value, bool connected) {
    if (!connected || value == null) return AppColors.textSubtle;
    if (value <= 120) return AppColors.success;
    if (value <= 300) return AppColors.warning;
    return AppColors.danger;
  }
}

String phoneToolHeaderTitle(AppPreferences prefs, WorkspaceMode mode) {
  return switch (mode) {
    WorkspaceMode.stats => prefs.t('workspace.stats'),
    WorkspaceMode.files => prefs.t('workspace.files'),
    WorkspaceMode.git => prefs.t('workspace.git'),
    WorkspaceMode.review => prefs.t('workspace.review'),
    _ => prefs.t('workspace.terminal'),
  };
}
