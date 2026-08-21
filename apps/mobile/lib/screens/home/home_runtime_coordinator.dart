import 'package:flutter/foundation.dart';

import '../../services/remote_runtime_store.dart';
import '../../services/log_service.dart';
import '../../services/remote_capabilities.dart';
import '../../services/remote_terminal_binding_coordinator.dart';
import '../../services/remote_terminal_output_controller.dart';
import '../../services/terminal_input_batcher.dart';
import '../../services/terminal_input_reliable_sender.dart';
import '../../services/terminal_buffer_retry.dart';

class HomeRuntimeSnapshot {
  const HomeRuntimeSnapshot({
    required this.selectedProjectId,
    required this.selectedWorktreeId,
    required this.sessionId,
  });

  final String? selectedProjectId;
  final String? selectedWorktreeId;
  final String? sessionId;
}

class HomeRuntimeCoordinator {
  const HomeRuntimeCoordinator({
    required this.remoteProtocolReady,
    required this.selectedProjectId,
    required this.terminalBufferCapability,
    required this.outputController,
    required this.terminalInputSender,
    required this.terminalInputBatcher,
    required this.terminalBufferRetry,
    required this.terminalBindingCoordinator,
    required this.captureSnapshot,
    required this.syncRuntimeViewState,
    required this.setTerminalBufferLoading,
    required this.restoreTerminalSessionFromCache,
    required this.closeTerminalSwitcherAfterPendingWorktreeBuffer,
    required this.trackTerminalBaselineRequest,
    required this.removeTerminalSessionState,
    required this.releaseTerminalViewport,
    required this.clearTerminal,
    required this.requestTerminalList,
    required this.sendProjectSelect,
    required this.focusTerminalViewSoon,
    required this.onSessionStateChanged,
  });

  final bool remoteProtocolReady;
  final String? selectedProjectId;
  final TerminalBufferCapability terminalBufferCapability;
  final RemoteTerminalOutputController outputController;
  final TerminalInputReliableSender terminalInputSender;
  final TerminalInputBatcher terminalInputBatcher;
  final TerminalBufferRetryCoordinator terminalBufferRetry;
  final RemoteTerminalBindingCoordinator terminalBindingCoordinator;
  final HomeRuntimeSnapshot Function() captureSnapshot;
  final void Function() syncRuntimeViewState;
  final void Function(bool loading) setTerminalBufferLoading;
  final bool Function(String sessionId) restoreTerminalSessionFromCache;
  final void Function(String sessionId)
  closeTerminalSwitcherAfterPendingWorktreeBuffer;
  final void Function(String sessionId) trackTerminalBaselineRequest;
  final void Function(String sessionId) removeTerminalSessionState;
  final void Function({String? sessionId}) releaseTerminalViewport;
  final VoidCallback clearTerminal;
  final VoidCallback requestTerminalList;
  final void Function(String projectId, {required String reason})
  sendProjectSelect;
  final VoidCallback focusTerminalViewSoon;
  final void Function(HomeRuntimeSnapshot previous, String reason)
  onSessionStateChanged;

  void applyRuntimePlan(RemoteRuntimePlan plan, {String reason = ''}) {
    final previous = captureSnapshot();
    // A protocol-ready reconnect starts the terminal baseline immediately,
    // while the project/terminal list replies can arrive a moment later with
    // `resetTerminalBuffer`. Do not cancel that in-flight baseline merely
    // because the topology snapshot landed; doing so leaves the cached screen
    // in place and turns the host's valid response into a stale response.
    final preserveInFlightBaseline =
        plan.resetTerminalBuffer &&
        plan.bindSessionId != null &&
        outputController.hasActiveBufferRequest(plan.bindSessionId!);
    if (plan.stateChanged ||
        plan.clearTerminal ||
        plan.resetTerminalBuffer ||
        plan.requestTerminalList ||
        plan.requestProjectSelectId != null ||
        plan.bindSessionId != null ||
        plan.removedSessionIds.isNotEmpty) {
      CoduxLog.info(
        '[codux-flutter-runtime] plan reason=$reason state=${plan.stateChanged} clear=${plan.clearTerminal} resetBuffer=${plan.resetTerminalBuffer} requestTerminalList=${plan.requestTerminalList} requestProjectSelect=${plan.requestProjectSelectId ?? ''} bind=${plan.bindSessionId ?? ''} beforeProject=${previous.selectedProjectId ?? ''} beforeWorktree=${previous.selectedWorktreeId ?? ''} beforeSession=${previous.sessionId ?? ''}',
      );
    }
    for (final removed in plan.removedSessionIds) {
      terminalBindingCoordinator.unsubscribeSession(
        removed,
        reason: 'removed-$reason',
      );
      removeTerminalSessionState(removed);
    }
    if (plan.resetTerminalInput) {
      terminalInputBatcher.reset();
    }
    if (plan.resetTerminalBuffer) {
      terminalBufferRetry.reset();
      if (!preserveInFlightBaseline) {
        outputController.resetTransient();
        setTerminalBufferLoading(false);
      }
    }
    syncRuntimeViewState();

    // `resetTerminalBuffer` clears the visible binding, but a retained local
    // PTY cache is still authoritative for a known session. Only mark a
    // cache-miss or sequence-gap target stale so switching projects can reuse
    // its cached terminal without forcing another baseline transfer. When a
    // baseline is already in flight, the request itself is the freshness
    // marker and must be preserved above.
    final bindHasUsableCache =
        plan.bindSessionId != null &&
        outputController.hasCachedOutput(plan.bindSessionId!) &&
        !outputController.hasSequenceGap(plan.bindSessionId!);
    if (plan.resetTerminalBuffer &&
        plan.bindSessionId != null &&
        !preserveInFlightBaseline &&
        !bindHasUsableCache) {
      terminalBindingCoordinator.markSessionBaselineStale(plan.bindSessionId!);
    }

    final next = captureSnapshot();
    if (previous.sessionId != next.sessionId ||
        previous.selectedProjectId != next.selectedProjectId ||
        previous.selectedWorktreeId != next.selectedWorktreeId) {
      CoduxLog.info(
        '[codux-flutter-runtime] state reason=$reason project=${previous.selectedProjectId ?? ''}->${next.selectedProjectId ?? ''} worktree=${previous.selectedWorktreeId ?? ''}->${next.selectedWorktreeId ?? ''} session=${previous.sessionId ?? ''}->${next.sessionId ?? ''}',
      );
    }
    if (plan.bindSessionId != null &&
        previous.sessionId != null &&
        previous.sessionId != plan.bindSessionId) {
      terminalBufferRetry.resetSession(previous.sessionId!);
      releaseTerminalViewport(sessionId: previous.sessionId);
    }
    if (plan.clearTerminal) {
      clearTerminal();
    }
    if (plan.requestTerminalList) {
      requestTerminalList();
    }
    if (plan.requestProjectSelectId != null) {
      sendProjectSelect(plan.requestProjectSelectId!, reason: reason);
    }
    if (plan.bindSessionId != null && !remoteProtocolReady) {
      CoduxLog.debug(
        '[codux-flutter-terminal] defer bind session=${plan.bindSessionId} reason=$reason protocolReady=false',
      );
      return;
    }
    if (plan.bindSessionId != null) {
      applyTerminalBind(plan, reason);
      if (preserveInFlightBaseline) {
        // The topology reset above intentionally preserved the request, but
        // also reset the retry coordinator. Re-arm its watcher for the same
        // single-flight request so a stalled transfer still self-heals.
        trackTerminalBaselineRequest(plan.bindSessionId!);
      }
    }
    onSessionStateChanged(previous, reason);
  }

  void bindActiveTerminalAfterProtocolReady({required String reason}) {
    if (!remoteProtocolReady) return;
    final sessionId = captureSnapshot().sessionId;
    if (sessionId == null || sessionId.trim().isEmpty) return;
    applyTerminalBind(
      RemoteRuntimePlan(bindSessionId: sessionId, bindFullBuffer: true),
      reason,
    );
  }

  void applyTerminalBind(RemoteRuntimePlan plan, String reason) {
    final bindSessionId = plan.bindSessionId;
    if (bindSessionId == null) return;
    final restored = restoreTerminalSessionFromCache(bindSessionId);
    if (restored) {
      closeTerminalSwitcherAfterPendingWorktreeBuffer(bindSessionId);
    }
    // Read the project from the live snapshot, not the construction-time
    // `selectedProjectId`: a user-select plan updates the runtime's project via
    // `syncRuntimeViewState()` earlier in this same apply pass, so the captured
    // field is stale here and would bind the session to the previous project.
    final boundProjectId =
        captureSnapshot().selectedProjectId ?? selectedProjectId;
    final bindResult = terminalBindingCoordinator.bindSession(
      plan: plan,
      bindSessionId: bindSessionId,
      reason: reason,
      selectedProjectId: boundProjectId,
      capability: terminalBufferCapability,
      restored: restored,
    );
    CoduxLog.info(
      '[codux-flutter-terminal] bind session=$bindSessionId project=${boundProjectId ?? ''} cached=${bindResult.restored}',
    );
    focusTerminalViewSoon();
    final evicted = outputController.evictInactiveSessions(bindSessionId);
    for (final sessionId in evicted) {
      terminalBindingCoordinator.unsubscribeSession(
        sessionId,
        reason: 'lru-evict',
      );
      terminalInputSender.clear(sessionId: sessionId);
    }
    if (evicted.isNotEmpty) {
      CoduxLog.info(
        '[codux-flutter-terminal] evict inactive sessions=${evicted.length} keep=$bindSessionId',
      );
    }
    if (bindResult.baselineRequested) {
      trackTerminalBaselineRequest(bindSessionId);
    }
    if (plan.flushTerminalInput) {
      terminalInputBatcher.flush();
    }
  }
}
