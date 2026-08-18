import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../models/remote_models.dart';
import '../../theme/app_theme.dart';
import '../pad/pad_project_picker_modal.dart';
import '../pad/pad_workspace_shared.dart';
import 'swipe_list_tile.dart';

enum TerminalSwitcherSection { terminals, worktrees, sessions }

class TerminalSwitcherScreen extends StatefulWidget {
  const TerminalSwitcherScreen({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required this.projects,
    required this.terminals,
    required this.worktrees,
    required this.activeTerminalId,
    required this.selectedProjectId,
    required this.selectedWorktreeId,
    required this.switchingWorktreeId,
    required this.loadingWorktrees,
    required this.creating,
    required this.creatingWorktree,
    required this.onBack,
    required this.onSelectProject,
    required this.onAddProject,
    required this.onRemoveProject,
    required this.onSelectTerminal,
    required this.onCreateTerminal,
    required this.onCloseTerminal,
    required this.onSelectWorktree,
    required this.onCreateWorktree,
    required this.onMergeWorktree,
    required this.onDeleteWorktree,
    required this.onOpenWorktrees,
    required this.onRefreshWorktrees,
    required this.onRefreshTerminals,
    required this.aiSessions,
    required this.onOpenSessions,
    required this.onRefreshSessions,
    required this.onOpenSession,
    required this.onRenameSession,
    required this.onDeleteSession,
  });

  final double topInset;
  final double bottomInset;
  final List<ProjectInfo> projects;
  final List<TerminalInfo> terminals;
  final List<RemoteWorktreeInfo> worktrees;
  final String? activeTerminalId;
  final String? selectedProjectId;
  final String? selectedWorktreeId;
  final String? switchingWorktreeId;
  final bool loadingWorktrees;
  final bool creating;
  final bool creatingWorktree;
  final VoidCallback onBack;
  final ValueChanged<ProjectInfo> onSelectProject;
  final VoidCallback onAddProject;
  final ValueChanged<ProjectInfo> onRemoveProject;
  final ValueChanged<TerminalInfo> onSelectTerminal;
  final VoidCallback onCreateTerminal;
  final ValueChanged<TerminalInfo> onCloseTerminal;
  final ValueChanged<RemoteWorktreeInfo> onSelectWorktree;
  final VoidCallback onCreateWorktree;
  final ValueChanged<RemoteWorktreeInfo> onMergeWorktree;
  final ValueChanged<RemoteWorktreeInfo> onDeleteWorktree;
  final VoidCallback onOpenWorktrees;
  final VoidCallback onRefreshWorktrees;
  final VoidCallback onRefreshTerminals;
  final List<AISessionRecord> aiSessions;
  final VoidCallback onOpenSessions;
  final VoidCallback onRefreshSessions;
  final ValueChanged<AISessionRecord> onOpenSession;
  final ValueChanged<AISessionRecord> onRenameSession;
  final ValueChanged<AISessionRecord> onDeleteSession;

  @override
  State<TerminalSwitcherScreen> createState() => _TerminalSwitcherScreenState();
}

class _TerminalSwitcherScreenState extends State<TerminalSwitcherScreen> {
  TerminalSwitcherSection _section = TerminalSwitcherSection.terminals;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    final scopedWorktrees = widget.selectedProjectId == null
        ? widget.worktrees
        : widget.worktrees
              .where((item) => item.projectId == widget.selectedProjectId)
              .toList(growable: false);
    return ColoredBox(
      color: AppColors.bgBase,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          widget.topInset + AppSpacing.m,
          AppSpacing.l,
          widget.bottomInset + AppSpacing.l,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: widget.onBack,
                ),
                const SizedBox(width: AppSpacing.m),
                Expanded(
                  child: Text(
                    prefs.t('workspace.switcher'),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.l),
            _ProjectStrip(
              projects: widget.projects,
              selectedProjectId: widget.selectedProjectId,
              onSelect: widget.onSelectProject,
              onAdd: widget.onAddProject,
              onRemove: widget.onRemoveProject,
            ),
            const SizedBox(height: AppSpacing.l),
            _SectionTabs(
              value: _section,
              onChanged: (next) {
                setState(() => _section = next);
                if (next == TerminalSwitcherSection.worktrees) {
                  widget.onOpenWorktrees();
                } else if (next == TerminalSwitcherSection.sessions) {
                  widget.onOpenSessions();
                }
              },
            ),
            const SizedBox(height: AppSpacing.l),
            Expanded(
              child: RefreshIndicator(
                color: accent,
                backgroundColor: AppColors.bgSurface,
                onRefresh: () async {
                  switch (_section) {
                    case TerminalSwitcherSection.worktrees:
                      widget.onRefreshWorktrees();
                    case TerminalSwitcherSection.sessions:
                      widget.onRefreshSessions();
                    case TerminalSwitcherSection.terminals:
                      widget.onRefreshTerminals();
                  }
                  // Brief delay so the pull-to-refresh spinner reads as an
                  // action; the host's reply arrives asynchronously.
                  await Future<void>.delayed(const Duration(milliseconds: 600));
                },
                child: switch (_section) {
                  TerminalSwitcherSection.terminals => _TerminalList(
                    terminals: widget.terminals,
                    activeTerminalId: widget.activeTerminalId,
                    addLabel: prefs.t('switcher.newTerminal'),
                    itemPrefix: prefs.t('switcher.terminal'),
                    creating: widget.creating,
                    onAdd: widget.onCreateTerminal,
                    onSelect: widget.onSelectTerminal,
                    onClose: widget.onCloseTerminal,
                  ),
                  TerminalSwitcherSection.worktrees => _WorktreeList(
                    accent: accent,
                    loading: widget.loadingWorktrees,
                    creating: widget.creatingWorktree,
                    worktrees: scopedWorktrees,
                    selectedId: widget.selectedWorktreeId,
                    switchingId: widget.switchingWorktreeId,
                    onSelect: widget.onSelectWorktree,
                    onCreate: widget.onCreateWorktree,
                    onMerge: widget.onMergeWorktree,
                    onDelete: widget.onDeleteWorktree,
                  ),
                  TerminalSwitcherSection.sessions => _SessionList(
                    sessions: widget.aiSessions,
                    onOpen: widget.onOpenSession,
                    onRename: widget.onRenameSession,
                    onDelete: widget.onDeleteSession,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectStrip extends StatelessWidget {
  const _ProjectStrip({
    required this.projects,
    required this.selectedProjectId,
    required this.onSelect,
    required this.onAdd,
    required this.onRemove,
  });

  final List<ProjectInfo> projects;
  final String? selectedProjectId;
  final ValueChanged<ProjectInfo> onSelect;
  final VoidCallback onAdd;
  final ValueChanged<ProjectInfo> onRemove;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefs.t('workspace.projects'),
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: projects.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.s),
            itemBuilder: (context, index) {
              if (index == projects.length) {
                return _ProjectChip(
                  label: prefs.t('project.add'),
                  initials: '+',
                  active: false,
                  accent: accent,
                  onTap: onAdd,
                );
              }
              final project = projects[index];
              final active = project.id == selectedProjectId;
              return _ProjectChip(
                projectId: project.id,
                label: project.name,
                initials: projectInitials(project.name),
                active: active,
                accent: accent,
                onTap: () => onSelect(project),
                onDelete: () => onRemove(project),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({
    this.projectId,
    required this.label,
    required this.initials,
    required this.active,
    required this.accent,
    required this.onTap,
    this.onDelete,
  });

  final String? projectId;
  final String label;
  final String initials;
  final bool active;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    return Material(
      color: active ? accent.withValues(alpha: 0.16) : AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: active
                      ? accent.withValues(alpha: 0.22)
                      : AppColors.bgBase,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    color: active ? accent : AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active
                        ? AppColors.textPrimary
                        : AppColors.textSubtle,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_rounded, size: 16, color: accent),
              ],
              if (onDelete != null) ...[
                const SizedBox(width: 2),
                IconButton(
                  key: projectId == null
                      ? null
                      : ValueKey('terminal-switcher-project-delete-$projectId'),
                  tooltip: prefs.t('project.remove'),
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 24,
                  ),
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: active ? accent : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.value, required this.onChanged});

  final TerminalSwitcherSection value;
  final ValueChanged<TerminalSwitcherSection> onChanged;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _Segment(
            label: prefs.t('switcher.terminals'),
            active: value == TerminalSwitcherSection.terminals,
            onTap: () => onChanged(TerminalSwitcherSection.terminals),
          ),
          _Segment(
            label: prefs.t('switcher.worktrees'),
            active: value == TerminalSwitcherSection.worktrees,
            onTap: () => onChanged(TerminalSwitcherSection.worktrees),
          ),
          _Segment(
            label: prefs.t('switcher.sessions'),
            active: value == TerminalSwitcherSection.sessions,
            onTap: () => onChanged(TerminalSwitcherSection.sessions),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: active ? accent.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? accent : AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalList extends StatelessWidget {
  const _TerminalList({
    required this.terminals,
    required this.activeTerminalId,
    required this.addLabel,
    required this.itemPrefix,
    required this.creating,
    required this.onAdd,
    required this.onSelect,
    required this.onClose,
  });

  final List<TerminalInfo> terminals;
  final String? activeTerminalId;
  final String addLabel;
  final String itemPrefix;
  final bool creating;
  final VoidCallback onAdd;
  final ValueChanged<TerminalInfo> onSelect;
  final ValueChanged<TerminalInfo> onClose;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    final itemCount = terminals.length + 1;
    if (terminals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SwipeListTile(
            key: const ValueKey('terminal-switcher-add'),
            title: addLabel,
            subtitle: creating ? prefs.t('terminal.creating') : itemPrefix,
            leadingIcon: Icons.add_rounded,
            active: false,
            onTap: creating ? null : onAdd,
            trailing: creating ? _InlineLoader(color: accent) : null,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
      itemBuilder: (context, index) {
        if (index == terminals.length) {
          return SwipeListTile(
            key: const ValueKey('terminal-switcher-add'),
            title: addLabel,
            subtitle: creating ? prefs.t('terminal.creating') : itemPrefix,
            leadingIcon: Icons.add_rounded,
            active: false,
            onTap: creating ? null : onAdd,
            trailing: creating ? _InlineLoader(color: accent) : null,
          );
        }
        final terminal = terminals[index];
        final active = terminal.id == activeTerminalId;
        return SwipeListTile(
          key: ValueKey('terminal-switcher-terminal-${terminal.id}'),
          title: '$itemPrefix ${index + 1}',
          subtitle: _terminalSubtitle(terminal),
          leadingIcon: Icons.terminal_rounded,
          active: active,
          onTap: () => onSelect(terminal),
          trailing: active
              ? Icon(Icons.check_rounded, color: accent, size: 20)
              : null,
          actions: [
            SwipeListAction(
              label: prefs.t('app.delete'),
              color: AppColors.danger,
              icon: Icons.delete_outline_rounded,
              onTap: () => onClose(terminal),
            ),
          ],
        );
      },
    );
  }
}

class _WorktreeList extends StatelessWidget {
  const _WorktreeList({
    required this.accent,
    required this.loading,
    required this.creating,
    required this.worktrees,
    required this.selectedId,
    required this.switchingId,
    required this.onSelect,
    required this.onCreate,
    required this.onMerge,
    required this.onDelete,
  });

  final Color accent;
  final bool loading;
  final bool creating;
  final List<RemoteWorktreeInfo> worktrees;
  final String? selectedId;
  final String? switchingId;
  final ValueChanged<RemoteWorktreeInfo> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<RemoteWorktreeInfo> onMerge;
  final ValueChanged<RemoteWorktreeInfo> onDelete;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    if (loading && worktrees.isEmpty) {
      return Center(child: CircularProgressIndicator(color: accent));
    }
    if (worktrees.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SwipeListTile(
            key: const ValueKey('terminal-switcher-worktree-add'),
            title: prefs.t('worktree.new'),
            subtitle: creating
                ? prefs.t('worktree.creating')
                : prefs.t('switcher.worktrees'),
            leadingIcon: Icons.add_rounded,
            active: false,
            onTap: creating ? null : onCreate,
            trailing: creating ? _InlineLoader(color: accent) : null,
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: worktrees.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
      itemBuilder: (context, index) {
        if (index == worktrees.length) {
          return SwipeListTile(
            key: const ValueKey('terminal-switcher-worktree-add'),
            title: prefs.t('worktree.new'),
            subtitle: creating
                ? prefs.t('worktree.creating')
                : prefs.t('switcher.worktrees'),
            leadingIcon: Icons.add_rounded,
            active: false,
            onTap: creating ? null : onCreate,
            trailing: creating ? _InlineLoader(color: accent) : null,
          );
        }
        final item = worktrees[index];
        final active = item.id == selectedId;
        final switching = item.id == switchingId;
        final actions = _worktreeActions(
          context: context,
          item: item,
          accent: accent,
          onMerge: onMerge,
          onDelete: onDelete,
        );
        return SwipeListTile(
          key: ValueKey('terminal-switcher-worktree-${item.id}'),
          title: _worktreeTitle(item),
          subtitle: _worktreeSubtitle(item),
          leadingIcon: Icons.account_tree_outlined,
          active: active,
          onTap: switching ? null : () => onSelect(item),
          trailing: switching
              ? _InlineLoader(color: accent)
              : active
              ? Icon(Icons.check_rounded, color: accent, size: 20)
              : null,
          actions: actions,
        );
      },
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final List<AISessionRecord> sessions;
  final ValueChanged<AISessionRecord> onOpen;
  final ValueChanged<AISessionRecord> onRename;
  final ValueChanged<AISessionRecord> onDelete;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    if (sessions.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 200,
            child: Center(
              child: Text(
                prefs.t('workspace.sessionsEmpty'),
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
      itemBuilder: (context, index) {
        final session = sessions[index];
        final title = session.title.trim().isNotEmpty
            ? session.title.trim()
            : session.id;
        final time = formatEpochSeconds(session.time);
        final tool = session.tool.trim();
        final subtitle = [
          if (tool.isNotEmpty) tool,
          if (time.isNotEmpty) time,
        ].join(' · ');
        return SwipeListTile(
          key: ValueKey('terminal-switcher-session-${session.id}'),
          title: title,
          subtitle: subtitle.isEmpty ? session.id : subtitle,
          leadingIcon: Icons.forum_outlined,
          onTap: () => onOpen(session),
          trailing: session.size > 0
              ? Text(
                  formatTokenSize(session.size),
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
          actions: [
            SwipeListAction(
              label: prefs.t('session.menuRename'),
              color: accent,
              icon: Icons.drive_file_rename_outline_rounded,
              onTap: () => onRename(session),
            ),
            SwipeListAction(
              label: prefs.t('session.menuDelete'),
              color: AppColors.danger,
              icon: Icons.delete_outline_rounded,
              onTap: () => onDelete(session),
            ),
          ],
        );
      },
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgSurface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }
}

class _InlineLoader extends StatelessWidget {
  const _InlineLoader({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }
}

String _terminalSubtitle(TerminalInfo terminal) {
  final parts = <String>[
    if (terminal.title.trim().isNotEmpty) terminal.title.trim(),
    if (terminal.status?.trim().isNotEmpty == true) terminal.status!.trim(),
  ];
  if (parts.isEmpty) return terminal.id;
  return parts.join(' · ');
}

String _worktreeTitle(RemoteWorktreeInfo worktree) {
  if (worktree.name.isNotEmpty) return worktree.name;
  if (worktree.branch.isNotEmpty) return worktree.branch;
  return worktree.id;
}

String _worktreeSubtitle(RemoteWorktreeInfo worktree) {
  final parts = <String>[
    if (worktree.branch.isNotEmpty) worktree.branch,
    if (worktree.changes > 0) 'Δ${worktree.changes}',
  ];
  if (parts.isNotEmpty) return parts.join(' · ');
  return worktree.path;
}

List<SwipeListAction> _worktreeActions({
  required BuildContext context,
  required RemoteWorktreeInfo item,
  required Color accent,
  required ValueChanged<RemoteWorktreeInfo> onMerge,
  required ValueChanged<RemoteWorktreeInfo> onDelete,
}) {
  if (item.isDefault || item.path.trim().isEmpty) return const [];
  final prefs = AppPreferences.of(context);
  return [
    SwipeListAction(
      label: prefs.t('worktree.merge'),
      color: accent,
      icon: Icons.call_merge_rounded,
      onTap: () => onMerge(item),
    ),
    SwipeListAction(
      label: prefs.t('worktree.remove'),
      color: AppColors.danger,
      icon: Icons.delete_outline_rounded,
      onTap: () => onDelete(item),
    ),
  ];
}
