import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:codux_protocol_ffi/codux_protocol_ffi.dart';

import '../../i18n.dart';
import '../../theme/app_theme.dart';

class Toolbar extends StatefulWidget {
  const Toolbar({
    super.key,
    required this.onSendKey,
    required this.onPaste,
    required this.onCopy,
    required this.applicationCursor,
    required this.keyboardVisible,
    required this.bottomInset,
    required this.onToggleKeyboard,
  });

  static const double rowHeight = 32;
  static const double verticalPadding = 4;
  static const double rowGap = 4;
  static const double cornerInset = 16;

  static double heightFor({required bool expanded}) {
    final rows = expanded ? 2 : 1;
    return verticalPadding * 2 + rowHeight * rows + (expanded ? rowGap : 0);
  }

  final ValueChanged<String> onSendKey;
  final VoidCallback onPaste;
  final VoidCallback onCopy;
  final bool applicationCursor;
  final bool keyboardVisible;
  final double bottomInset;
  final VoidCallback onToggleKeyboard;

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> {
  bool _ctrl = false;
  bool _shift = false;

  void _clearModifiers() {
    if (!_ctrl && !_shift) return;
    setState(() {
      _ctrl = false;
      _shift = false;
    });
  }

  void _send(String key, {String keyChar = ''}) {
    final input = keyChar.isNotEmpty && !_ctrl && !_shift
        ? terminalTextInput(keyChar)
        : terminalKeyInput(
            key: key,
            keyChar: keyChar,
            shift: _shift,
            alt: false,
            control: _ctrl,
            applicationCursor: widget.applicationCursor,
          );
    widget.onSendKey(input);
    _clearModifiers();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final leftInset = math.max(viewPadding.left, Toolbar.cornerInset);
    final rightInset = math.max(viewPadding.right, Toolbar.cornerInset);
    final row1 = [
      _ToolItem(
        label: 'esc',
        kind: _ToolKind.special,
        onTap: () => _send('escape'),
      ),
      _ToolItem(
        label: 'tab',
        kind: _ToolKind.special,
        onTap: () => _send('tab'),
      ),
      _ToolItem(
        label: '^C',
        kind: _ToolKind.danger,
        onTap: () {
          widget.onSendKey('\u0003');
          _clearModifiers();
        },
      ),
      _ToolItem(
        icon: Icons.keyboard_arrow_up_rounded,
        label: '↑',
        kind: _ToolKind.icon,
        repeatable: true,
        onTap: () => _send('up'),
      ),
      _ToolItem(
        icon: Icons.keyboard_arrow_down_rounded,
        label: '↓',
        kind: _ToolKind.icon,
        repeatable: true,
        onTap: () => _send('down'),
      ),
      _ToolItem(
        icon: Icons.keyboard_return_rounded,
        label: prefs.t('toolbar.enter'),
        kind: _ToolKind.enter,
        onTap: () => _send('enter'),
      ),
      _ToolItem(
        icon: widget.keyboardVisible
            ? Icons.keyboard_hide_rounded
            : Icons.keyboard_rounded,
        label: prefs.t('toolbar.keyboard'),
        kind: _ToolKind.special,
        onTap: widget.onToggleKeyboard,
      ),
    ];
    final row2 = widget.keyboardVisible
        ? [
            _ToolItem(
              label: 'ctrl',
              kind: _ToolKind.modifier,
              active: _ctrl,
              onTap: () => setState(() => _ctrl = !_ctrl),
            ),
            _ToolItem(
              label: '/',
              kind: _ToolKind.special,
              onTap: () => _send('/', keyChar: '/'),
            ),
            _ToolItem(
              icon: Icons.content_paste_rounded,
              label: 'paste',
              kind: _ToolKind.special,
              onTap: widget.onPaste,
            ),
            _ToolItem(
              icon: Icons.keyboard_arrow_left_rounded,
              label: '←',
              kind: _ToolKind.icon,
              repeatable: true,
              onTap: () => _send('left'),
            ),
            _ToolItem(
              icon: Icons.keyboard_arrow_right_rounded,
              label: '→',
              kind: _ToolKind.icon,
              repeatable: true,
              onTap: () => _send('right'),
            ),
            _ToolItem(
              label: 'shft',
              kind: _ToolKind.modifier,
              active: _shift,
              onTap: () => setState(() => _shift = !_shift),
            ),
            _ToolItem(
              icon: Icons.content_copy_rounded,
              label: 'copy',
              kind: _ToolKind.special,
              onTap: widget.onCopy,
            ),
          ]
        : const <_ToolItem>[];

    return Container(
      color: AppColors.terminalChrome,
      child: SizedBox(
        height: Toolbar.heightFor(expanded: widget.keyboardVisible) +
            widget.bottomInset,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            leftInset,
            Toolbar.verticalPadding,
            rightInset,
            Toolbar.verticalPadding + widget.bottomInset,
          ),
          child: _ToolGrid(row1: row1, row2: row2),
        ),
      ),
    );
  }
}

enum _ToolKind { special, modifier, icon, enter, danger }

class _ToolItem {
  const _ToolItem({
    this.icon,
    this.label,
    required this.kind,
    required this.onTap,
    this.active = false,
    this.repeatable = false,
  }) : assert(icon != null || label != null);

  final IconData? icon;
  final String? label;
  final _ToolKind kind;
  final VoidCallback onTap;
  final bool active;
  final bool repeatable;
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.row1, required this.row2});

  final List<_ToolItem> row1;
  final List<_ToolItem> row2;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: _ToolRow(items: row1, gap: Toolbar.rowGap),
      ),
      if (row2.isNotEmpty) ...[
        const SizedBox(height: Toolbar.rowGap),
        Expanded(
          child: _ToolRow(items: row2, gap: Toolbar.rowGap),
        ),
      ],
    ],
  );
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.items, required this.gap});

  final List<_ToolItem> items;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < items.length; index += 1) ...[
        Expanded(child: _ToolButton(item: items[index])),
        if (index < items.length - 1) SizedBox(width: gap),
      ],
    ],
  );
}

class _ToolButton extends StatefulWidget {
  const _ToolButton({required this.item});

  final _ToolItem item;

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
  Timer? _repeatDelayTimer;
  Timer? _repeatTimer;

  void _startRepeat() {
    if (!widget.item.repeatable) return;
    _repeatDelayTimer?.cancel();
    _repeatTimer?.cancel();
    _repeatDelayTimer = Timer(const Duration(milliseconds: 320), () {
      widget.item.onTap();
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 72), (_) {
        widget.item.onTap();
      });
    });
  }

  void _stopRepeat() {
    _repeatDelayTimer?.cancel();
    _repeatDelayTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final accent = Theme.of(context).colorScheme.secondary;
    final color = switch (item.kind) {
      _ToolKind.enter => accent.withValues(alpha: 0.16),
      _ToolKind.danger => AppColors.danger.withValues(alpha: 0.16),
      _ToolKind.modifier when item.active => accent.withValues(alpha: 0.16),
      _ => AppColors.terminalElevated,
    };
    final foreground = switch (item.kind) {
      _ToolKind.enter => accent,
      _ToolKind.danger => AppColors.danger,
      _ToolKind.modifier when item.active => accent,
      _ => AppColors.terminalText,
    };

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTapDown: (_) => _startRepeat(),
        onTapUp: (_) => _stopRepeat(),
        onTapCancel: _stopRepeat,
        onTap: item.onTap,
        child: Semantics(
          label: item.label,
          button: true,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            alignment: Alignment.center,
            child: item.icon != null
                ? Icon(
                    item.icon,
                    size: item.kind == _ToolKind.enter ? 20 : 17,
                    color: foreground,
                  )
                : Text(
                    item.label!,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
