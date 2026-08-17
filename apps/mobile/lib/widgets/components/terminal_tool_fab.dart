import 'package:codux_protocol_ffi/codux_protocol_ffi.dart';
import 'package:flutter/material.dart';

import '../../i18n.dart';
import '../../services/remote_capabilities.dart';
import '../../theme/app_theme.dart';

const _terminalToolFabBorder = Color(0x40FFFFFF);
const _terminalToolFabShadow = BoxShadow(
  color: Color(0x73000000),
  blurRadius: 10,
  offset: Offset(0, 3),
);

/// Expandable floating tool menu for terminal actions not on the bottom toolbar.
class TerminalToolFab extends StatefulWidget {
  const TerminalToolFab({
    super.key,
    required this.bottomOffset,
    required this.leftInset,
    required this.onSendKey,
    required this.onUpload,
    required this.onVoice,
    this.aiTool = MobileAiToolCapability.fallback,
    this.uploadLoading = false,
  });

  final double bottomOffset;
  final double leftInset;
  final ValueChanged<String> onSendKey;
  final VoidCallback onUpload;
  final VoidCallback onVoice;

  /// Host-configured AI shortcut. The action only appears while the host
  /// advertises a command.
  final MobileAiToolCapability aiTool;
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

  void _sendKey(
    String key, {
    String keyChar = '',
    bool shift = false,
  }) {
    final input = keyChar.isNotEmpty && !shift
        ? terminalTextInput(keyChar)
        : terminalKeyInput(
            key: key,
            keyChar: keyChar,
            shift: shift,
            alt: false,
            control: false,
            applicationCursor: false,
          );
    _run(() => widget.onSendKey(input));
  }

  /// Type the host's command and submit it, the way a user would.
  void _sendCommand(String command) {
    _run(() {
      widget.onSendKey(terminalTextInput(command));
      widget.onSendKey(
        terminalKeyInput(
          key: 'enter',
          keyChar: '',
          shift: false,
          alt: false,
          control: false,
          applicationCursor: false,
        ),
      );
    });
  }

  List<_TerminalToolAction> _actions(AppPreferences prefs) {
    return [
      for (final entry in widget.aiTool.commands)
        _TerminalToolAction(
          icon: Icons.auto_awesome_rounded,
          label: entry.label.isNotEmpty
              ? entry.label
              : prefs.t('terminal.tool.ai'),
          onTap: () => _sendCommand(entry.command),
        ),
      _TerminalToolAction(
        icon: Icons.cancel_outlined,
        label: prefs.t('terminal.tool.esc'),
        onTap: () => _sendKey('escape'),
      ),
      _TerminalToolAction(
        icon: Icons.keyboard_return_rounded,
        label: prefs.t('toolbar.enter'),
        onTap: () => _sendKey('enter'),
      ),
      _TerminalToolAction(
        icon: Icons.close_rounded,
        label: prefs.t('terminal.tool.interrupt'),
        labelColor: AppColors.danger,
        iconColor: AppColors.danger,
        onTap: () => _run(() => widget.onSendKey('\u0003')),
      ),
      _TerminalToolAction(
        icon: Icons.arrow_back_rounded,
        label: prefs.t('terminal.tool.shiftTab'),
        onTap: () => _sendKey('tab', shift: true),
      ),
      _TerminalToolAction(
        icon: Icons.upload_rounded,
        label: prefs.t('toolbar.upload'),
        onTap: widget.uploadLoading ? null : () => _run(widget.onUpload),
      ),
      _TerminalToolAction(
        icon: Icons.mic_none_rounded,
        label: prefs.t('toolbar.voice'),
        onTap: () => _run(widget.onVoice),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final accent = Theme.of(context).colorScheme.secondary;
    final actions = _actions(prefs);

    return Positioned(
      left: widget.leftInset,
      bottom: widget.bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizeTransition(
            sizeFactor: _expand,
            alignment: AlignmentDirectional.bottomStart,
            child: FadeTransition(
              opacity: _expand,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _expanded
                  ? AppColors.terminalChrome
                  : AppColors.terminalElevated,
              border: Border.all(color: _terminalToolFabBorder),
              boxShadow: const [_terminalToolFabShadow],
            ),
            child: Material(
              color: Colors.transparent,
              elevation: 0,
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
                        color: accent,
                        size: 22,
                      ),
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
    this.labelColor,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? labelColor;
  final Color? iconColor;
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
    final iconColor = enabled
        ? (action.iconColor ?? accent)
        : AppColors.terminalTextDim;
    final labelColor = enabled
        ? (action.labelColor ?? AppColors.terminalText)
        : AppColors.terminalTextDim;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.terminalElevated,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: _terminalToolFabBorder),
        boxShadow: const [_terminalToolFabShadow],
      ),
      child: Material(
        color: Colors.transparent,
        elevation: 0,
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
                  Icon(
                    action.icon,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    action.label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
