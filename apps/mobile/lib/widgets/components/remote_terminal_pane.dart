import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n.dart';
import '../../models/workspace_mode.dart';
import '../../services/remote_terminal_output_controller.dart';
import '../../services/terminal_repaint_signal.dart';
import '../../theme/app_theme.dart';
import 'connect_hint.dart';
import 'self_drawn_terminal_view.dart';
import 'toolbar.dart';

// Codex/Claude's composer is bottom-anchored in the terminal grid. Keep the
// floating tool menu above that multi-row input area instead of covering it.
const _terminalSelectionToolbarShadow = BoxShadow(
  color: Color(0x73000000),
  blurRadius: 10,
  offset: Offset(0, 3),
);

class RemoteTerminalPane extends StatefulWidget {
  const RemoteTerminalPane({
    super.key,
    required this.connected,
    required this.showTerminal,
    required this.hasDevice,
    required this.status,
    required this.workspaceMode,
    required this.projectListLoaded,
    required this.projectCount,
    required this.terminalUploadLoading,
    required this.terminalUploadStatus,
    required this.terminalBufferLoading,
    required this.sessionId,
    required this.pendingBufferSessionId,
    required this.connectionStatusText,
    required this.terminalHistoryLoadingText,
    required this.keyboardVisible,
    required this.keyboardRequested,
    required this.keyboardRequestSerial,
    required this.repaintSignal,
    required this.outputController,
    required this.terminalFontSize,
    required this.reconnecting,
    required this.onConnect,
    required this.onInput,
    required this.onResize,
    required this.onSelectionChanged,
    required this.onSendKey,
    required this.onToggleKeyboard,
    required this.onRequestKeyboard,
    this.onOpenUrl,
    this.onRemoteViewportScroll,
    required this.onPaste,
    required this.onCopy,
    this.onCopyAndPaste,
    this.hasSelection = false,
    this.onSwipeTerminal,
    required this.onUpload,
    this.onUploadAndPastePath,
    required this.onShowGit,
    required this.onOpenSessions,
    required this.onShowStats,
    required this.onShowFiles,
    required this.onRebuildTerminal,
    required this.onEditProject,
    required this.onAddProject,
    required this.handedAway,
    required this.takeOverPending,
    required this.handoffMessageKey,
    required this.onTakeOver,
  });

  final bool connected;
  final bool showTerminal;
  final bool hasDevice;
  final String status;
  final WorkspaceMode workspaceMode;
  final bool projectListLoaded;
  final int projectCount;
  final bool terminalUploadLoading;
  final String terminalUploadStatus;
  final bool terminalBufferLoading;
  final String? sessionId;
  final String? pendingBufferSessionId;
  final String connectionStatusText;
  final String terminalHistoryLoadingText;
  final bool keyboardVisible;
  final bool keyboardRequested;
  final int keyboardRequestSerial;
  final TerminalRepaintSignal repaintSignal;
  final RemoteTerminalOutputController outputController;
  final double terminalFontSize;
  final bool reconnecting;
  final VoidCallback onConnect;
  final ValueChanged<String> onInput;
  final void Function(int cols, int rows) onResize;
  final ValueChanged<String?> onSelectionChanged;
  final ValueChanged<String> onSendKey;
  final VoidCallback onToggleKeyboard;
  final VoidCallback onRequestKeyboard;
  final ValueChanged<Uri>? onOpenUrl;
  final void Function(double pixels, double cellHeight)? onRemoteViewportScroll;
  final VoidCallback onPaste;
  final VoidCallback onCopy;
  final VoidCallback? onCopyAndPaste;
  final bool hasSelection;
  final String? Function(int direction)? onSwipeTerminal;
  final VoidCallback onUpload;
  final VoidCallback? onUploadAndPastePath;
  final VoidCallback onShowGit;
  final VoidCallback onOpenSessions;
  final VoidCallback onShowStats;
  final VoidCallback onShowFiles;
  final VoidCallback onRebuildTerminal;
  final VoidCallback onEditProject;
  final VoidCallback onAddProject;
  // Handoff: the desktop (or another device) currently owns this session. Show a
  // placeholder instead of the live terminal; onTakeOver reclaims it to here.
  final bool handedAway;
  final bool takeOverPending;

  /// Host-configured AI shortcut shown in the tool FAB.
  final String handoffMessageKey;
  final VoidCallback onTakeOver;

  @override
  State<RemoteTerminalPane> createState() => _RemoteTerminalPaneState();
}

class _RemoteTerminalPaneState extends State<RemoteTerminalPane> {
  static const _swipeDistanceThreshold = 64.0;
  static const _swipeVelocityThreshold = 650.0;

  TerminalCursorMetrics? _cursorMetrics;
  bool _terminalToolsExpanded = false;
  final ValueNotifier<double> _terminalSwipeProgress = ValueNotifier(0);
  double _terminalSwipeDx = 0;
  String? _terminalSwipeNotice;
  Timer? _terminalSwipeNoticeTimer;

  @override
  void dispose() {
    _terminalSwipeNoticeTimer?.cancel();
    _terminalSwipeProgress.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant RemoteTerminalPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionId != oldWidget.sessionId) {
      _cursorMetrics = null;
    }
  }

  void _onTerminalSwipeStart(DragStartDetails details) {
    _terminalSwipeDx = 0;
    _terminalSwipeProgress.value = 0;
  }

  void _onTerminalSwipeUpdate(DragUpdateDetails details) {
    _terminalSwipeDx += details.primaryDelta ?? 0;
    _terminalSwipeProgress.value = (_terminalSwipeDx / 120).clamp(-1.0, 1.0);
  }

  void _onTerminalSwipeCancel() {
    _terminalSwipeDx = 0;
    _terminalSwipeProgress.value = 0;
  }

  void _onTerminalSwipeEnd(DragEndDetails details) {
    final distance = _terminalSwipeDx;
    final velocity = details.primaryVelocity ?? 0;
    _onTerminalSwipeCancel();
    if (distance.abs() < _swipeDistanceThreshold &&
        velocity.abs() < _swipeVelocityThreshold) {
      return;
    }
    final direction = distance != 0
        ? (distance < 0 ? 1 : -1)
        : (velocity < 0 ? 1 : -1);
    final label = widget.onSwipeTerminal?.call(direction);
    if (label == null || label.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    _terminalSwipeNoticeTimer?.cancel();
    setState(() => _terminalSwipeNotice = label);
    _terminalSwipeNoticeTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _terminalSwipeNotice = null);
    });
  }

  // Handoff placeholder: shown when the desktop/another device took the session
  // over. We deliberately do NOT render the live grid (it would be the other
  // device's size + would fight for ownership) — just a status + a button to
  // take it back here.
  Widget _buildHandedAwayPlaceholder(BuildContext context) {
    final prefs = AppPreferences.of(context);
    return ColoredBox(
      color: AppColors.terminalBg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.desktop_windows_outlined,
              size: 44,
              color: AppColors.terminalTextDim,
            ),
            const SizedBox(height: 16),
            Text(
              prefs.t(widget.handoffMessageKey),
              style: TextStyle(fontSize: 15, color: AppColors.terminalTextDim),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              key: const ValueKey('terminal-take-over'),
              onPressed: widget.takeOverPending ? null : widget.onTakeOver,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.takeOverPending) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    prefs.t(
                      widget.takeOverPending
                          ? 'terminal.handoff.takingBack'
                          : 'terminal.handoff.takeBack',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A handoff claim cannot be delivered while the transport is down. Keep
    // the reconnect affordance visible until the link is ready again; once it
    // is connected, preserve the ownership placeholder to avoid stealing a
    // desktop/other-device terminal during recovery.
    if (widget.handedAway && widget.connected) {
      return _buildHandedAwayPlaceholder(context);
    }
    final showTerminalToolbar =
        widget.workspaceMode == WorkspaceMode.terminal && widget.connected;
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomInset = viewPadding.bottom;
    final edgeInset = Toolbar.edgeInsetFor(viewPadding);
    final keyboardActiveThreshold = math.max(bottomInset + 8.0, 80.0);
    final effectiveKeyboardHeight = keyboardHeight > keyboardActiveThreshold
        ? keyboardHeight
        : 0.0;
    final imeOpen = widget.keyboardVisible || effectiveKeyboardHeight > 0;
    final toolbarBottom = effectiveKeyboardHeight > 0
        ? effectiveKeyboardHeight
        : 0.0;
    final toolbarSafeBottom = imeOpen ? 0.0 : edgeInset;
    final toolbarBaseHeight = Toolbar.heightFor(
      expanded: _terminalToolsExpanded,
    );
    // Inset the terminal grid from the panel edges so the content isn't flush
    // against the surrounding container.
    const terminalPadding = EdgeInsets.all(12);

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final terminalToolbarHeight = toolbarBaseHeight + toolbarSafeBottom;
            final viewportHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height;
            final terminalHeight =
                (viewportHeight -
                        (showTerminalToolbar ? terminalToolbarHeight : 0.0) -
                        effectiveKeyboardHeight)
                    .clamp(120.0, viewportHeight);
            final showHostSyncOverlay =
                widget.connected &&
                !widget.projectListLoaded &&
                widget.projectCount == 0;
            final showUploadOverlay =
                widget.showTerminal &&
                widget.workspaceMode == WorkspaceMode.terminal &&
                widget.terminalUploadLoading &&
                widget.terminalUploadStatus.isNotEmpty;
            final showHistoryOverlay =
                widget.showTerminal &&
                widget.workspaceMode == WorkspaceMode.terminal &&
                !widget.terminalUploadLoading &&
                widget.terminalBufferLoading &&
                widget.sessionId != null &&
                widget.pendingBufferSessionId == widget.sessionId;
            final showReconnectOverlay =
                widget.showTerminal && !widget.connected && widget.reconnecting;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: terminalHeight,
                  child: ColoredBox(
                    key: const ValueKey('remote-terminal-body'),
                    color: AppColors.terminalBg,
                    child: Padding(
                      padding: terminalPadding,
                      child: Stack(
                        children: [
                          if (widget.showTerminal)
                            // Self-drawn renderer: reads the Rust cell grid
                            // directly (single source of truth). Repaints on
                            // the per-output signal so a live frame rebuilds
                            // only this subtree, not the whole page (toolbar,
                            // overlays, keyboard inset / layout recompute).
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart:
                                  widget.onSwipeTerminal != null &&
                                      !widget.hasSelection
                                  ? _onTerminalSwipeStart
                                  : null,
                              onHorizontalDragUpdate:
                                  widget.onSwipeTerminal != null &&
                                      !widget.hasSelection
                                  ? _onTerminalSwipeUpdate
                                  : null,
                              onHorizontalDragEnd:
                                  widget.onSwipeTerminal != null &&
                                      !widget.hasSelection
                                  ? _onTerminalSwipeEnd
                                  : null,
                              onHorizontalDragCancel:
                                  widget.onSwipeTerminal != null &&
                                      !widget.hasSelection
                                  ? _onTerminalSwipeCancel
                                  : null,
                              child: SelfDrawnTerminalView(
                                sessionId: widget.sessionId,
                                controller: widget.outputController,
                                repaintSignal: widget.repaintSignal,
                                fontSize: widget.terminalFontSize,
                                onResize: widget.onResize,
                                onInput: widget.onInput,
                                onSendKey: widget.onSendKey,
                                onSelectionChanged: widget.onSelectionChanged,
                                selectionToolbar:
                                    showTerminalToolbar && widget.hasSelection
                                    ? _TerminalSelectionToolbar(
                                        onCopy: widget.onCopy,
                                        onCopyAndPaste: widget.onCopyAndPaste,
                                      )
                                    : null,
                                onRequestKeyboard: widget.onRequestKeyboard,
                                onOpenUrl: widget.onOpenUrl,
                                onRemoteViewportScroll:
                                    widget.onRemoteViewportScroll,
                                keyboardRequested: widget.keyboardRequested,
                                keyboardRequestSerial:
                                    widget.keyboardRequestSerial,
                                onCursorMetrics: (metrics) {
                                  if (_cursorMetrics == metrics) return;
                                  setState(() => _cursorMetrics = metrics);
                                },
                              ),
                            )
                          else
                            ConnectHint(
                              status: widget.status.isEmpty
                                  ? AppPreferences.of(
                                      context,
                                    ).t('app.notConnected')
                                  : widget.status,
                              hasDevice: widget.hasDevice,
                              reconnecting: widget.reconnecting,
                              onConnect: widget.onConnect,
                            ),
                          if (widget.showTerminal &&
                              showHostSyncOverlay &&
                              !widget.terminalUploadLoading &&
                              !widget.terminalBufferLoading)
                            _TerminalOverlay(
                              message: widget.connectionStatusText,
                            ),
                          if (widget.showTerminal &&
                              (showUploadOverlay || showHistoryOverlay))
                            _TerminalOverlay(
                              message: showUploadOverlay
                                  ? widget.terminalUploadStatus
                                  : widget.terminalHistoryLoadingText,
                              opacity: 0.72,
                            ),
                          if (showReconnectOverlay)
                            _TerminalOverlay(
                              message: AppPreferences.of(
                                context,
                              ).t('app.reconnectingShort'),
                              opacity: 0.72,
                            ),
                          if (widget.showTerminal &&
                              widget.onSwipeTerminal != null &&
                              !widget.hasSelection)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ValueListenableBuilder<double>(
                                  valueListenable: _terminalSwipeProgress,
                                  builder: (context, progress, _) =>
                                      _TerminalSwipeCue(progress: progress),
                                ),
                              ),
                            ),
                          if (widget.showTerminal &&
                              widget.onSwipeTerminal != null)
                            Positioned(
                              top: AppSpacing.s,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 160),
                                    child: _terminalSwipeNotice == null
                                        ? const SizedBox.shrink()
                                        : Container(
                                            key: ValueKey(_terminalSwipeNotice),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.m,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.terminalElevated
                                                  .withValues(alpha: 0.94),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.12,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              _terminalSwipeNotice!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: AppColors.terminalText,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (showTerminalToolbar)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: toolbarBottom,
                    child: Toolbar(
                      sessionId: widget.sessionId,
                      onSendKey: widget.onSendKey,
                      applicationCursor: false,
                      keyboardVisible: imeOpen,
                      bottomInset: toolbarSafeBottom,
                      onToggleKeyboard: widget.onToggleKeyboard,
                      onPaste: widget.onPaste,
                      expanded: _terminalToolsExpanded,
                      onToggleMore: () => setState(
                        () => _terminalToolsExpanded = !_terminalToolsExpanded,
                      ),
                      onUpload: widget.onUpload,
                      onUploadAndPastePath: widget.onUploadAndPastePath,
                      uploadLoading: widget.terminalUploadLoading,
                      onShowGit: widget.onShowGit,
                      onOpenSessions: widget.onOpenSessions,
                      onShowStats: widget.onShowStats,
                      onShowFiles: widget.onShowFiles,
                      onRebuildTerminal: widget.onRebuildTerminal,
                      onEditProject: widget.onEditProject,
                      onAddProject: widget.onAddProject,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TerminalSwipeCue extends StatelessWidget {
  const _TerminalSwipeCue({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    if (progress.abs() < 0.08) return const SizedBox.shrink();
    final swipingRight = progress > 0;
    final strength = progress.abs().clamp(0.0, 1.0);
    return Align(
      alignment: swipingRight ? Alignment.centerLeft : Alignment.centerRight,
      child: Transform.translate(
        offset: Offset(
          swipingRight ? -8 + strength * 12 : 8 - strength * 12,
          0,
        ),
        child: Opacity(
          opacity: (strength * 0.86).clamp(0.0, 0.86),
          child: Container(
            width: 34,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.terminalElevated.withValues(alpha: 0.9),
              borderRadius: BorderRadius.horizontal(
                right: swipingRight
                    ? const Radius.circular(AppRadius.md)
                    : Radius.zero,
                left: swipingRight
                    ? Radius.zero
                    : const Radius.circular(AppRadius.md),
              ),
            ),
            child: Icon(
              swipingRight
                  ? Icons.chevron_left_rounded
                  : Icons.chevron_right_rounded,
              size: 24,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TerminalSelectionToolbar extends StatelessWidget {
  const _TerminalSelectionToolbar({
    required this.onCopy,
    required this.onCopyAndPaste,
  });

  final VoidCallback onCopy;
  final VoidCallback? onCopyAndPaste;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.terminalElevated.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: const [_terminalSelectionToolbarShadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _action(
                icon: Icons.copy_rounded,
                label: prefs.t('toolbar.copy'),
                onTap: onCopy,
              ),
              if (onCopyAndPaste != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _action(
                  icon: Icons.copy_all_rounded,
                  label: prefs.t('toolbar.copyPaste'),
                  onTap: onCopyAndPaste!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.terminalText),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.terminalText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _terminalLiftForKeyboard({
  required double terminalHeight,
  required double keyboardLift,
  required TerminalCursorMetrics? cursorMetrics,
  double bottomMargin = 0,
}) {
  if (keyboardLift <= 0) return 0;
  final safeBottom = terminalHeight - keyboardLift;
  if (safeBottom <= 0) return keyboardLift;
  final metrics = cursorMetrics;
  if (metrics == null) return keyboardLift;
  // bottomMargin covers the grid's top inset (the content sits that much lower
  // than its row implies) plus a couple of rows, so the cursor AND the TUI input
  // box border just below it clear the toolbar instead of merely touching it.
  final cursorBottom =
      (metrics.row + 1) * math.max(1.0, metrics.lineHeight) + bottomMargin;
  final overflow = cursorBottom - safeBottom;
  if (overflow <= 0) return 0;
  return overflow.clamp(0.0, keyboardLift);
}

@visibleForTesting
double terminalLiftForKeyboardForTest({
  required double terminalHeight,
  required double keyboardLift,
  required TerminalCursorMetrics? cursorMetrics,
  double bottomMargin = 0,
}) {
  return _terminalLiftForKeyboard(
    terminalHeight: terminalHeight,
    keyboardLift: keyboardLift,
    cursorMetrics: cursorMetrics,
    bottomMargin: bottomMargin,
  );
}

class _TerminalOverlay extends StatelessWidget {
  const _TerminalOverlay({required this.message, this.opacity = 0.58});

  final String message;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.terminalBg.withValues(alpha: opacity),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.terminalTextDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
