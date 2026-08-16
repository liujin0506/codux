class TerminalBufferCapability {
  const TerminalBufferCapability({
    this.chunking = false,
    this.maxChars = mobileMaxChars,
    this.chunkChars = 16384,
    this.requestId = false,
    this.screenData = false,
    this.baselineFailed = false,
    this.staleOutput = false,
    this.viewportKeyframe = false,
  });

  static const int mobileMaxChars = 200000;

  final bool chunking;
  final int maxChars;
  final int chunkChars;
  final bool requestId;
  final bool screenData;
  final bool baselineFailed;
  final bool staleOutput;
  final bool viewportKeyframe;

  static const fallback = TerminalBufferCapability();

  factory TerminalBufferCapability.fromHostInfo(
    Object? payload, {
    int clientMaxChars = mobileMaxChars,
  }) {
    if (payload is! Map) return fallback;
    final capabilities = payload['capabilities'];
    if (capabilities is! Map) return fallback;
    final terminalBuffer = capabilities['terminalBuffer'];
    if (terminalBuffer is! Map) return fallback;
    final terminalOutput = capabilities['terminalOutput'];
    final terminalViewport = capabilities['terminalViewport'];
    final effectiveClientMax = clientMaxChars < 1
        ? mobileMaxChars
        : clientMaxChars;
    return TerminalBufferCapability(
      chunking: terminalBuffer['chunking'] == true,
      maxChars: _clampInt(
        _intValue(terminalBuffer['maxChars']) ?? fallback.maxChars,
        1,
        effectiveClientMax,
      ),
      chunkChars: _clampInt(
        _intValue(terminalBuffer['chunkChars']) ?? fallback.chunkChars,
        4096,
        65536,
      ),
      requestId: terminalBuffer['requestId'] == true,
      screenData: terminalBuffer['screenData'] == true,
      baselineFailed: terminalBuffer['baselineFailed'] == true,
      staleOutput:
          terminalOutput is Map && terminalOutput['staleOutput'] == true,
      viewportKeyframe:
          terminalViewport is Map && terminalViewport['keyframe'] == true,
    );
  }
}

/// One host-configured shortcut in the terminal tool menu.
class MobileAiCommand {
  const MobileAiCommand({required this.command, this.label = ''});

  final String command;

  /// Host-supplied caption. Empty means "use the app's own translation".
  final String label;
}

/// Host-configured AI shortcuts for the terminal tool menu. The host decides
/// both which buttons exist and what they run, so the phone never invents a
/// command of its own.
class MobileAiToolCapability {
  const MobileAiToolCapability([this.commands = const []]);

  /// Matches the host-side cap, so a misconfigured host cannot push a menu
  /// taller than the screen.
  static const int maxCommands = 5;

  final List<MobileAiCommand> commands;

  static const fallback = MobileAiToolCapability();

  bool get enabled => commands.isNotEmpty;

  factory MobileAiToolCapability.fromHostInfo(Object? payload) {
    if (payload is! Map) return fallback;
    final capabilities = payload['capabilities'];
    if (capabilities is! Map) return fallback;
    final mobileTools = capabilities['mobileTools'];
    if (mobileTools is! Map) return fallback;
    final entries = mobileTools['aiCommands'];
    if (entries is! List) return fallback;
    final commands = <MobileAiCommand>[];
    for (final entry in entries) {
      if (commands.length >= maxCommands) break;
      if (entry is! Map) continue;
      final command = '${entry['command'] ?? ''}'.trim();
      if (command.isEmpty) continue;
      commands.add(
        MobileAiCommand(
          command: command,
          label: '${entry['label'] ?? ''}'.trim(),
        ),
      );
    }
    if (commands.isEmpty) return fallback;
    return MobileAiToolCapability(List.unmodifiable(commands));
  }
}

class RemoteResourceSubscriptionCapability {
  const RemoteResourceSubscriptionCapability([this.resources = const {}]);

  final Set<String> resources;

  static const fallback = RemoteResourceSubscriptionCapability();

  bool supports(String resource) => resources.contains(resource);

  factory RemoteResourceSubscriptionCapability.fromHostInfo(Object? payload) {
    if (payload is! Map) return fallback;
    final capabilities = payload['capabilities'];
    if (capabilities is! Map) return fallback;
    final resources = capabilities['resourceSubscriptions'];
    if (resources is! List) return fallback;
    return RemoteResourceSubscriptionCapability(
      resources
          .map((resource) => '$resource'.trim())
          .where((resource) => resource.isNotEmpty)
          .toSet(),
    );
  }
}

int? _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}');
}

int _clampInt(int value, int min, int max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}
