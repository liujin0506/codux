import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../models/workspace_mode.dart';
import '../../theme/app_theme.dart';
import 'phone_workspace_menu.dart';

/// Single-row phone workspace chrome: back, project switcher, and the overflow
/// menu for tools + project actions.
class PhoneWorkspaceHeader extends StatelessWidget {
  const PhoneWorkspaceHeader({
    super.key,
    required this.topInset,
    required this.projectName,
    required this.worktreeName,
    required this.terminalName,
    required this.onBack,
    required this.onOpenSwitcher,
    required this.onSwitchProject,
    required this.onShowStats,
    required this.onShowFiles,
    required this.onShowGit,
    required this.onEditProject,
    required this.onAddProject,
    this.onRebuildTerminal,
  });

  static const barHeight = 48.0;
  static const workspaceBarHeight = 60.0;

  final double topInset;
  final String? projectName;
  final String? worktreeName;
  final String? terminalName;
  final VoidCallback onBack;
  final VoidCallback onOpenSwitcher;
  final VoidCallback onSwitchProject;
  final VoidCallback onShowStats;
  final VoidCallback onShowFiles;
  final VoidCallback onShowGit;
  final VoidCallback onEditProject;
  final VoidCallback onAddProject;
  final VoidCallback? onRebuildTerminal;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    final projectLabel = projectName?.trim().isNotEmpty == true
        ? projectName!.trim()
        : prefs.t('project.selectFirst');
    final worktreeLabel = worktreeName?.trim();
    final terminalLabel = terminalName?.trim();
    final hasWorktree = worktreeLabel?.isNotEmpty == true;
    final hasTerminal = terminalLabel?.isNotEmpty == true;
    final hasContext = hasWorktree || hasTerminal;

    return Material(
      color: AppColors.bgBase,
      child: Container(
        height: workspaceBarHeight + topInset,
        padding: EdgeInsets.only(top: topInset),
        decoration: BoxDecoration(color: AppColors.bgBase),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                        fontSize: 16,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasContext)
                      SizedBox(
                        width: double.infinity,
                        height: 17,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            onTap: onOpenSwitcher,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    if (hasWorktree)
                                      TextSpan(
                                        text: worktreeLabel,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 11,
                                          height: 1.1,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (hasWorktree && hasTerminal)
                                      TextSpan(
                                        text: '  /  ',
                                        style: TextStyle(
                                          color: AppColors.textSubtle,
                                          fontSize: 11,
                                          height: 1.1,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    if (hasTerminal)
                                      TextSpan(
                                        text: terminalLabel,
                                        style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                          height: 1.1,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: const ValueKey('phone-workspace-switcher'),
                tooltip: prefs.t('workspace.switcher'),
                onPressed: onOpenSwitcher,
                icon: Icon(
                  Icons.grid_view_rounded,
                  size: 20,
                  color: accent.withValues(alpha: 0.88),
                ),
              ),
            ),
            PhoneWorkspaceMenu(
              onShowStats: onShowStats,
              onShowGit: onShowGit,
              onShowFiles: onShowFiles,
              onSwitchProject: onSwitchProject,
              onRebuildTerminal: onRebuildTerminal,
              onEditProject: onEditProject,
              onAddProject: onAddProject,
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
      color: AppColors.bgBase,
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
                style: TextStyle(
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

String phoneToolHeaderTitle(AppPreferences prefs, WorkspaceMode mode) {
  return switch (mode) {
    WorkspaceMode.stats => prefs.t('workspace.stats'),
    WorkspaceMode.files => prefs.t('workspace.files'),
    WorkspaceMode.git => prefs.t('workspace.git'),
    WorkspaceMode.review => prefs.t('workspace.review'),
    _ => prefs.t('workspace.terminal'),
  };
}
