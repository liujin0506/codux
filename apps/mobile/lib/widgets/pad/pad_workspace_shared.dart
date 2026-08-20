import '../../models/remote_models.dart';

/// Compact local "MM-DD HH:mm" from an ISO-8601 timestamp (falls back to raw).
String formatCreatedAt(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

/// Compact local "MM-DD HH:mm" from epoch seconds (AI session `time`).
String formatEpochSeconds(double seconds) {
  if (seconds <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(
    (seconds * 1000).round(),
  ).toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

/// Compact token count, e.g. 1234 -> "1.2k", 2_000_000 -> "2.0M".
String formatTokenSize(int tokens) {
  if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
  if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}k';
  return '$tokens';
}

String _formatUsageValue(double value) {
  final decimals = value >= 100
      ? 1
      : value >= 1
      ? 2
      : value >= 0.01
      ? 4
      : 6;
  return value.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Compact, detailed usage text for the second line of a session row.
String formatSessionUsage(AISessionRecord session) {
  final parts = <String>[];
  if (session.size > 0) {
    parts.add(formatTokenSize(session.size));
  }
  final inputTokens = session.inputTokens > 0 ? session.inputTokens : 0;
  final outputTokens = session.outputTokens > 0 ? session.outputTokens : 0;
  final cachedInputTokens = session.cachedInputTokens > 0
      ? session.cachedInputTokens
      : 0;
  if (inputTokens > 0) {
    parts.add('↑ ${formatTokenSize(inputTokens)}');
  }
  if (outputTokens > 0) {
    parts.add('↓ ${formatTokenSize(outputTokens)}');
  }
  if (cachedInputTokens > 0) {
    final inputWithCache = inputTokens + cachedInputTokens;
    final cacheRate = inputWithCache > 0
        ? cachedInputTokens / inputWithCache * 100
        : 0;
    final rateText = cacheRate >= 10
        ? cacheRate.toStringAsFixed(0)
        : cacheRate.toStringAsFixed(1);
    parts.add('⚡ $rateText%');
  }
  if (session.requestCount > 0) {
    parts.add('${session.requestCount} req');
  }
  for (final amount in session.usageAmounts) {
    final unit = amount.unit.trim();
    if (unit.isEmpty || amount.value <= 0) continue;
    final value = _formatUsageValue(amount.value);
    parts.add(
      unit.toUpperCase() == 'USD' ? '\$$value' : '$unit $value',
    );
  }
  return parts.join(' · ');
}

ProjectInfo? selectedProjectOf(List<ProjectInfo> projects, String? selectedProjectId) {
  for (final project in projects) {
    if (project.id == selectedProjectId) return project;
  }
  return null;
}
