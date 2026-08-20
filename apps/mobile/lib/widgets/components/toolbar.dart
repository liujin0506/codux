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
    required this.applicationCursor,
    required this.keyboardVisible,
    required this.bottomInset,
    required this.onToggleKeyboard,
    required this.expanded,
    required this.onToggleMore,
    required this.onUpload,
    this.onUploadAndPastePath,
    required this.uploadLoading,
    required this.onShowGit,
    required this.onOpenSessions,
    required this.onShowStats,
    required this.onShowFiles,
    required this.onRebuildTerminal,
    required this.onEditProject,
    required this.onAddProject,
  });

  static const double rowHeight = 38;
  static const double expandedRowHeight = 34;
  static const double verticalPadding = 4;
  static const double rowGap = 4;
  static const double cornerInset = 16;
  static const double height = verticalPadding * 2 + rowHeight * 2 + rowGap;
  static const int expandedRowCount = 3;
  static const double expandedHeight =
      height + (expandedRowHeight + rowGap) * expandedRowCount;

  static double heightFor({bool expanded = true}) =>
      expanded ? expandedHeight : height;

  /// Left, right, and bottom use the same safe inset so the bar clears the
  /// rounded corners without lifting a full Home Indicator gap.
  static double edgeInsetFor(EdgeInsets viewPadding) {
    return math.max(math.max(viewPadding.left, viewPadding.right), cornerInset);
  }

  final ValueChanged<String> onSendKey;
  final VoidCallback onPaste;
  final bool applicationCursor;
  final bool keyboardVisible;
  final double bottomInset;
  final VoidCallback onToggleKeyboard;
  final bool expanded;
  final VoidCallback onToggleMore;
  final VoidCallback onUpload;
  final VoidCallback? onUploadAndPastePath;
  final bool uploadLoading;
  final VoidCallback onShowGit;
  final VoidCallback onOpenSessions;
  final VoidCallback onShowStats;
  final VoidCallback onShowFiles;
  final VoidCallback onRebuildTerminal;
  final VoidCallback onEditProject;
  final VoidCallback onAddProject;

  @override
  State<Toolbar> createState() => _ToolbarState();
}

class _ToolbarState extends State<Toolbar> {
  bool _ctrl = false;

  void _clearModifiers() {
    if (!_ctrl) return;
    setState(() {
      _ctrl = false;
    });
  }

  void _send(String key, {String keyChar = ''}) {
    final input = keyChar.isNotEmpty && !_ctrl
        ? terminalTextInput(keyChar)
        : terminalKeyInput(
            key: key,
            keyChar: keyChar,
            shift: false,
            alt: false,
            control: _ctrl,
            applicationCursor: widget.applicationCursor,
          );
    widget.onSendKey(input);
    _clearModifiers();
  }

  void _sendControl(String key, String keyChar) {
    widget.onSendKey(
      terminalKeyInput(
        key: key,
        keyChar: keyChar,
        shift: false,
        alt: false,
        control: true,
        applicationCursor: widget.applicationCursor,
      ),
    );
    _clearModifiers();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final edgeInset = Toolbar.edgeInsetFor(viewPadding);
    final leftInset = edgeInset;
    final rightInset = edgeInset;
    final bottomInset = widget.bottomInset;
    final row1 = [
      _ToolItem(
        label: 'Esc',
        kind: _ToolKind.special,
        onTap: () => _send('escape'),
      ),
      _ToolItem(
        label: 'Tab',
        kind: _ToolKind.special,
        onTap: () => _send('tab'),
      ),
      _ToolItem(
        label: 'Ctrl',
        kind: _ToolKind.modifier,
        active: _ctrl,
        onTap: () => setState(() => _ctrl = !_ctrl),
      ),
      _ToolItem(
        icon: widget.expanded ? Icons.close_rounded : Icons.apps_rounded,
        label: prefs.t('terminal.tools'),
        kind: _ToolKind.special,
        active: widget.expanded,
        onTap: widget.onToggleMore,
      ),
      _ToolItem(
        icon: Icons.keyboard_arrow_up_rounded,
        label: '↑',
        kind: _ToolKind.icon,
        repeatable: true,
        onTap: () => _send('up'),
      ),
      _ToolItem(
        icon: Icons.backspace_outlined,
        label: 'Backspace',
        kind: _ToolKind.special,
        flex: 3,
        repeatable: true,
        onTap: () => _send('backspace'),
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
    final row3 = [
      _ToolItem(
        label: '@',
        kind: _ToolKind.special,
        onTap: () => _send('@', keyChar: '@'),
      ),
      _ToolItem(
        label: '!',
        kind: _ToolKind.special,
        onTap: () => _send('!', keyChar: '!'),
      ),
      _ToolItem(
        label: 'Shift+Tab',
        kind: _ToolKind.special,
        onTap: () => widget.onSendKey(
          terminalKeyInput(
            key: 'tab',
            keyChar: '',
            shift: true,
            alt: false,
            control: false,
            applicationCursor: widget.applicationCursor,
          ),
        ),
      ),
      _ToolItem(
        label: '^R',
        kind: _ToolKind.special,
        onTap: () => _sendControl('r', 'r'),
      ),
      _ToolItem(
        label: '^O',
        kind: _ToolKind.special,
        onTap: () => _sendControl('o', 'o'),
      ),
      _ToolItem(
        label: '^L',
        kind: _ToolKind.special,
        onTap: () => _sendControl('l', 'l'),
      ),
    ];
    final row4 = [
      _ToolItem(
        label: prefs.t('workspace.git'),
        kind: _ToolKind.workspace,
        onTap: widget.onShowGit,
      ),
      _ToolItem(
        label: prefs.t('workspace.sessions'),
        kind: _ToolKind.workspace,
        onTap: widget.onOpenSessions,
      ),
      _ToolItem(
        label: prefs.t('workspace.stats'),
        kind: _ToolKind.workspace,
        onTap: widget.onShowStats,
      ),
      _ToolItem(
        label: prefs.t('workspace.files'),
        kind: _ToolKind.workspace,
        onTap: widget.onShowFiles,
      ),
    ];
    final row5 = [
      _ToolItem(
        icon: Icons.file_upload_outlined,
        label: prefs.t('terminal.tool.uploadPath'),
        visualLabel: prefs.t('toolbar.upload'),
        kind: _ToolKind.project,
        onTap: widget.uploadLoading
            ? () {}
            : (widget.onUploadAndPastePath ?? widget.onUpload),
      ),
      _ToolItem(
        icon: Icons.refresh_rounded,
        label: prefs.t('project.rebuildTerminal'),
        visualLabel: prefs.t('project.rebuildTerminal'),
        kind: _ToolKind.project,
        onTap: widget.onRebuildTerminal,
      ),
      _ToolItem(
        icon: Icons.edit_outlined,
        label: prefs.t('project.edit'),
        visualLabel: prefs.t('project.edit'),
        kind: _ToolKind.project,
        onTap: widget.onEditProject,
      ),
      _ToolItem(
        icon: Icons.add_box_outlined,
        label: prefs.t('project.add'),
        visualLabel: prefs.t('project.add'),
        kind: _ToolKind.project,
        onTap: widget.onAddProject,
      ),
    ];
    final row2 = [
      _ToolItem(
        label: '^C',
        kind: _ToolKind.danger,
        onTap: () {
          widget.onSendKey('\u0003');
          _clearModifiers();
        },
      ),
      _ToolItem(
        icon: Icons.content_paste_rounded,
        label: 'Paste',
        kind: _ToolKind.special,
        onTap: widget.onPaste,
      ),
      _ToolItem(
        label: '/',
        kind: _ToolKind.special,
        onTap: () => _send('/', keyChar: '/'),
      ),
      _ToolItem(
        icon: Icons.keyboard_arrow_left_rounded,
        label: '←',
        kind: _ToolKind.icon,
        repeatable: true,
        onTap: () => _send('left'),
      ),
      _ToolItem(
        icon: Icons.keyboard_arrow_down_rounded,
        label: '↓',
        kind: _ToolKind.icon,
        repeatable: true,
        onTap: () => _send('down'),
      ),
      _ToolItem(
        icon: Icons.keyboard_arrow_right_rounded,
        label: '→',
        kind: _ToolKind.icon,
        repeatable: true,
        onTap: () => _send('right'),
      ),
      _ToolItem(
        icon: Icons.keyboard_return_rounded,
        label: prefs.t('toolbar.enter'),
        kind: _ToolKind.enter,
        flex: 3,
        onTap: () => _send('enter'),
      ),
    ];

    return Container(
      color: AppColors.terminalChrome,
      child: SizedBox(
        height: Toolbar.heightFor(expanded: widget.expanded) + bottomInset,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            leftInset,
            Toolbar.verticalPadding,
            rightInset,
            Toolbar.verticalPadding + bottomInset,
          ),
          child: _ToolGrid(
            row1: row1,
            row2: row2,
            row3: widget.expanded ? row3 : const [],
            row4: widget.expanded ? row4 : const [],
            row5: widget.expanded ? row5 : const [],
          ),
        ),
      ),
    );
  }
}

enum _ToolKind { special, modifier, icon, workspace, project, enter, danger }

class _ToolItem {
  const _ToolItem({
    this.icon,
    this.label,
    this.visualLabel,
    required this.kind,
    required this.onTap,
    this.active = false,
    this.repeatable = false,
    this.flex = 2,
  }) : assert(icon != null || label != null);

  final IconData? icon;
  final String? label;
  final String? visualLabel;
  final _ToolKind kind;
  final VoidCallback onTap;
  final bool active;
  final bool repeatable;
  final int flex;
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({
    required this.row1,
    required this.row2,
    required this.row3,
    required this.row4,
    required this.row5,
  });

  final List<_ToolItem> row1;
  final List<_ToolItem> row2;
  final List<_ToolItem> row3;
  final List<_ToolItem> row4;
  final List<_ToolItem> row5;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        height: Toolbar.rowHeight,
        child: _ToolRow(items: row1, gap: Toolbar.rowGap),
      ),
      if (row2.isNotEmpty) ...[
        const SizedBox(height: Toolbar.rowGap),
        SizedBox(
          height: Toolbar.rowHeight,
          child: _ToolRow(items: row2, gap: Toolbar.rowGap),
        ),
      ],
      if (row3.isNotEmpty) ...[
        const SizedBox(height: Toolbar.rowGap),
        SizedBox(
          height: Toolbar.expandedRowHeight,
          child: _ToolRow(items: row3, gap: Toolbar.rowGap),
        ),
      ],
      if (row4.isNotEmpty) ...[
        const SizedBox(height: Toolbar.rowGap),
        SizedBox(
          height: Toolbar.expandedRowHeight,
          child: _ToolRow(items: row4, gap: Toolbar.rowGap),
        ),
      ],
      if (row5.isNotEmpty) ...[
        const SizedBox(height: Toolbar.rowGap),
        SizedBox(
          height: Toolbar.expandedRowHeight,
          child: _ToolRow(items: row5, gap: Toolbar.rowGap),
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
        Expanded(
          flex: items[index].flex,
          child: _ToolButton(item: items[index]),
        ),
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
      _ToolKind.workspace => accent.withValues(alpha: 0.08),
      _ => AppColors.terminalElevated,
    };
    final foreground = switch (item.kind) {
      _ToolKind.enter => accent,
      _ToolKind.danger => AppColors.danger,
      _ToolKind.modifier when item.active => accent,
      _ToolKind.workspace => accent.withValues(alpha: 0.9),
      _ToolKind.project => AppColors.terminalTextDim,
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
            child: item.icon != null && item.visualLabel != null
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 15, color: foreground),
                          const SizedBox(width: 4),
                          Text(
                            item.visualLabel!,
                            maxLines: 1,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 11,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : item.icon != null
                ? Icon(
                    item.icon,
                    size: item.kind == _ToolKind.enter ? 20 : 17,
                    color: foreground,
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label!,
                        maxLines: 1,
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
        ),
      ),
    );
  }
}
