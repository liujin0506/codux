import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../theme/app_theme.dart';

/// Expandable floating tool menu for the terminal pane (upload, voice, …).
class TerminalToolFab extends StatefulWidget {
  const TerminalToolFab({
    super.key,
    required this.bottomOffset,
    required this.rightInset,
    required this.onUpload,
    required this.onVoice,
    this.uploadLoading = false,
  });

  final double bottomOffset;
  final double rightInset;
  final VoidCallback onUpload;
  final VoidCallback onVoice;
  final bool uploadLoading;

  @override
  State<TerminalToolFab> createState() => _TerminalToolFabState();
}

class _TerminalToolFabState extends State<TerminalToolFab>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _expand;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _expand = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() => _expanded = false);
    _controller.reverse();
  }

  void _run(VoidCallback action) {
    _collapse();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    final actions = [
      _TerminalToolAction(
        icon: Icons.mic_none_rounded,
        label: prefs.t('toolbar.voice'),
        onTap: () => _run(widget.onVoice),
      ),
      _TerminalToolAction(
        icon: Icons.upload_rounded,
        label: prefs.t('toolbar.upload'),
        onTap: widget.uploadLoading ? null : () => _run(widget.onUpload),
      ),
    ];

    return Positioned(
      right: widget.rightInset,
      bottom: widget.bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizeTransition(
            sizeFactor: _expand,
            alignment: AlignmentDirectional(-1, 1),
            child: FadeTransition(
              opacity: _expand,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var index = 0; index < actions.length; index += 1) ...[
                    _TerminalToolFabItem(
                      action: actions[index],
                      accent: accent,
                    ),
                    if (index < actions.length - 1)
                      const SizedBox(height: AppSpacing.s),
                  ],
                  const SizedBox(height: AppSpacing.s),
                ],
              ),
            ),
          ),
          Material(
            color: _expanded
                ? accent.withValues(alpha: 0.18)
                : AppColors.terminalElevated,
            elevation: _expanded ? 4 : 2,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _toggle,
              child: Semantics(
                button: true,
                label: prefs.t('terminal.tools'),
                expanded: _expanded,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: AnimatedRotation(
                    turns: _expanded ? 0.125 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _expanded ? Icons.close_rounded : Icons.apps_rounded,
                      color: _expanded ? accent : AppColors.terminalText,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TerminalToolAction {
  const _TerminalToolAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

class _TerminalToolFabItem extends StatelessWidget {
  const _TerminalToolFabItem({
    required this.action,
    required this.accent,
  });

  final _TerminalToolAction action;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    return Material(
      color: AppColors.terminalElevated,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: action.onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.s,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  action.label,
                  style: const TextStyle(
                    color: AppColors.terminalText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Icon(
                  action.icon,
                  size: 20,
                  color: enabled ? accent : AppColors.terminalTextDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
