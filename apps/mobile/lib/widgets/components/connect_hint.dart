import 'package:flutter/material.dart';
import '../../i18n.dart';
import '../../theme/app_theme.dart';

class ConnectHint extends StatelessWidget {
  const ConnectHint({
    super.key,
    required this.status,
    required this.hasDevice,
    required this.onConnect,
    this.reconnecting = false,
  });
  final String status;
  final bool hasDevice;
  final VoidCallback onConnect;
  final bool reconnecting;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    final prefs = AppPreferences.of(context);
    final title = hasDevice
        ? (reconnecting
              ? prefs.t('app.reconnectingShort')
              : prefs.t('app.tapToReconnect'))
        : prefs.t('app.addDevice');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reconnecting)
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accent,
                ),
              )
            else
              InkWell(
                onTap: hasDevice ? onConnect : null,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.l),
                  child: Icon(Icons.refresh_rounded, size: 40, color: accent),
                ),
              ),
            const SizedBox(height: AppSpacing.m),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.terminalText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (status.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.s),
              Text(
                status,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.terminalTextDim,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            if (hasDevice) ...[
              const SizedBox(height: AppSpacing.l),
              FilledButton.tonal(
                onPressed: onConnect,
                child: Text(
                  reconnecting
                      ? prefs.t('app.reconnectNow')
                      : prefs.t('app.reconnect'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
