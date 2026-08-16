/// Resolve the handoff placeholder copy from host kind and viewport owner.
///
/// On headless agents the host-local owner string is still `desktop`, but no
/// desktop UI exists — show reconnect copy instead of "taken over on desktop".
String terminalHandoffMessageKey({
  required bool isHeadlessAgentHost,
  required String viewportOwner,
}) {
  final owner = viewportOwner.trim();
  if (owner.startsWith('remote:')) {
    return 'terminal.handoff.takenOverOtherDevice';
  }
  if (isHeadlessAgentHost) {
    return 'terminal.handoff.idle';
  }
  return 'terminal.handoff.takenOver';
}

bool isHeadlessAgentHostApp(Object? hostInfoPayload) {
  if (hostInfoPayload is! Map) return false;
  final app = hostInfoPayload['app']?.toString().trim().toLowerCase();
  if (app == 'codux-agent') return true;
  final runtimeId =
      hostInfoPayload['runtimeInstanceId']?.toString().trim().toLowerCase();
  return runtimeId != null && runtimeId.endsWith('-agent');
}
