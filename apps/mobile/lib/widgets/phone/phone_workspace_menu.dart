import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../theme/app_theme.dart';

class PhoneWorkspaceMenu extends StatelessWidget {
  const PhoneWorkspaceMenu({
    super.key,
    required this.onShowStats,
    required this.onShowGit,
    required this.onShowFiles,
    required this.onSwitchProject,
    required this.onEditProject,
    required this.onAddProject,
    this.onRebuildTerminal,
  });

  final VoidCallback onShowStats;
  final VoidCallback onShowGit;
  final VoidCallback onShowFiles;
  final VoidCallback onSwitchProject;
  final VoidCallback onEditProject;
  final VoidCallback onAddProject;
  final VoidCallback? onRebuildTerminal;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: PopupMenuButton<String>(
        tooltip: '',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 4),
        color: AppColors.bgSurface,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: AppColors.border, width: 0.5),
        ),
        icon: Icon(Icons.more_vert, size: 22, color: AppColors.textPrimary),
        onSelected: (value) {
          switch (value) {
            case 'switcher':
              onSwitchProject();
            case 'stats':
              onShowStats();
            case 'git':
              onShowGit();
            case 'files':
              onShowFiles();
            case 'rebuild':
              onRebuildTerminal?.call();
            case 'edit':
              onEditProject();
            case 'add':
              onAddProject();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'switcher',
            height: 40,
            child: _MenuRow(
              icon: Icons.grid_view_rounded,
              label: prefs.t('workspace.switcher'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'stats',
            height: 40,
            child: _MenuRow(
              icon: Icons.bar_chart_rounded,
              label: prefs.t('workspace.stats'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'git',
            height: 40,
            child: _MenuRow(
              icon: Icons.account_tree_rounded,
              label: prefs.t('workspace.git'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'files',
            height: 40,
            child: _MenuRow(
              icon: Icons.folder_open_rounded,
              label: prefs.t('workspace.files'),
            ),
          ),
          const PopupMenuDivider(height: 8),
          if (onRebuildTerminal != null)
            PopupMenuItem<String>(
              value: 'rebuild',
              height: 40,
              child: _MenuRow(
                icon: Icons.refresh_rounded,
                label: prefs.t('project.rebuildTerminal'),
              ),
            ),
          PopupMenuItem<String>(
            value: 'edit',
            height: 40,
            child: _MenuRow(
              icon: Icons.edit_outlined,
              label: prefs.t('project.edit'),
            ),
          ),
          PopupMenuItem<String>(
            value: 'add',
            height: 40,
            child: _MenuRow(
              icon: Icons.add_box_outlined,
              label: prefs.t('project.add'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.s),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
