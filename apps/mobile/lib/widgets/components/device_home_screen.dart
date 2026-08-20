import 'package:flutter/material.dart';
import '../../i18n.dart';
import '../../models/remote_models.dart';
import '../../theme/app_theme.dart';
import 'more_menu.dart';
import 'swipe_list_tile.dart';

class DeviceHomeScreen extends StatelessWidget {
  const DeviceHomeScreen({
    super.key,
    required this.devices,
    required this.activeDeviceId,
    required this.ready,
    this.connecting = false,
    required this.status,
    required this.latencyMs,
    required this.deviceSubtitle,
    required this.topInset,
    required this.bottomInset,
    required this.onOpen,
    required this.onConnect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
    required this.onSettings,
    required this.onLogs,
    required this.onCheckUpdate,
    required this.onAbout,
  });

  final List<StoredDevice> devices;
  final String? activeDeviceId;
  final bool ready;
  final bool connecting;
  final String status;
  final int? latencyMs;
  final String Function(StoredDevice device) deviceSubtitle;
  final double topInset;
  final double bottomInset;
  final ValueChanged<StoredDevice> onOpen;
  final ValueChanged<StoredDevice> onConnect;
  final VoidCallback onAdd;
  final ValueChanged<StoredDevice> onEdit;
  final ValueChanged<StoredDevice> onDelete;
  final Future<void> Function() onRefresh;
  final VoidCallback onSettings;
  final VoidCallback onLogs;
  final VoidCallback onCheckUpdate;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.secondary;
    final prefs = AppPreferences.of(context);
    // Pad-width screens lay devices out as a card grid; phones keep the list.
    // Same breakpoint as the pad workspace layout so the two switch together.
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Container(
      color: AppColors.bgBase,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.l,
        topInset + AppSpacing.l,
        AppSpacing.l,
        bottomInset + AppSpacing.l,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Codux',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        height: 1.05,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prefs.t('device.homeHint'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _CircleButton(icon: Icons.settings_outlined, onTap: onSettings),
              const SizedBox(width: AppSpacing.s),
              MoreMenu(
                onAddDevice: onAdd,
                onLogs: onLogs,
                onCheckUpdate: onCheckUpdate,
                onAbout: onAbout,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: RefreshIndicator(
              color: accent,
              backgroundColor: AppColors.bgSurface,
              onRefresh: onRefresh,
              child: devices.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      children: [
                        SizedBox(
                          height: 360,
                          child: _EmptyDeviceState(
                            accent: accent,
                            onAdd: onAdd,
                          ),
                        ),
                      ],
                    )
                  : isWide
                  ? _buildGrid(context, prefs, accent)
                  : _buildList(context, prefs, accent),
            ),
          ),
          // Wide layout folds "add" into the grid as its own card; the list keeps
          // the full-width button below.
          if (!isWide)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bgSurface,
                  foregroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: Text(prefs.t('device.addByScan')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, AppPreferences prefs, Color accent) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
      itemBuilder: (context, index) {
        final device = devices[index];
        final isActive = device.deviceId == activeDeviceId;
        final isReady = isActive && ready;
        final isConnecting = isActive && connecting && !isReady;
        final state = isActive ? status : prefs.t('app.notConnected');
        final title = device.hostName?.isNotEmpty == true
            ? device.hostName!
            : device.name;
        return SwipeListTile(
          title: title,
          subtitle: deviceSubtitle(device),
          leadingIcon: Icons.desktop_mac_outlined,
          active: isActive,
          onTap: isReady
              ? () => onOpen(device)
              : isConnecting
              ? null
              : () => onConnect(device),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _TransportText(
                active: isActive,
                ready: isReady,
                connecting: isConnecting,
                status: state,
              ),
              const SizedBox(height: 7),
              _LatencyText(
                latencyMs: isReady ? latencyMs : null,
                ready: isReady,
              ),
            ],
          ),
          actions: [
            SwipeListAction(
              label: prefs.t('device.edit'),
              color: accent,
              icon: Icons.edit_outlined,
              onTap: () => onEdit(device),
            ),
            SwipeListAction(
              label: prefs.t('device.delete'),
              color: AppColors.danger,
              icon: Icons.delete_outline_rounded,
              onTap: () => onDelete(device),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, AppPreferences prefs, Color accent) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 132,
        crossAxisSpacing: AppSpacing.m,
        mainAxisSpacing: AppSpacing.m,
      ),
      itemCount: devices.length + 1,
      itemBuilder: (context, index) {
        if (index == devices.length) {
          return _AddDeviceCard(accent: accent, onAdd: onAdd);
        }
        final device = devices[index];
        final isActive = device.deviceId == activeDeviceId;
        final isReady = isActive && ready;
        final isConnecting = isActive && connecting && !isReady;
        final state = isActive ? status : prefs.t('app.notConnected');
        final title = device.hostName?.isNotEmpty == true
            ? device.hostName!
            : device.name;
        return _DeviceCard(
          title: title,
          subtitle: deviceSubtitle(device),
          active: isActive,
          ready: isReady,
          connecting: isConnecting,
          status: state,
          latencyMs: isReady ? latencyMs : null,
          accent: accent,
          onTap: isReady
              ? () => onOpen(device)
              : isConnecting
              ? null
              : () => onConnect(device),
          onEdit: () => onEdit(device),
          onDelete: () => onDelete(device),
        );
      },
    );
  }
}

/// One device tile in the pad grid: status-tinted icon, name + endpoint, and the
/// transport/latency footer. Long-press opens edit/delete (the grid can't swipe).
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.ready,
    required this.connecting,
    required this.status,
    required this.latencyMs,
    required this.accent,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final bool active;
  final bool ready;
  final bool connecting;
  final String status;
  final int? latencyMs;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _openMenu(BuildContext context) async {
    final prefs = AppPreferences.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.m,
            0,
            AppSpacing.m,
            AppSpacing.m,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DeviceMenuItem(
                  icon: Icons.edit_outlined,
                  label: prefs.t('device.edit'),
                  onTap: onEdit,
                ),
                Divider(height: 0.5, color: AppColors.border),
                _DeviceMenuItem(
                  icon: Icons.delete_outline_rounded,
                  label: prefs.t('device.delete'),
                  danger: true,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = !active
        ? AppColors.textSubtle
        : ready
        ? AppColors.success
        : connecting
        ? AppColors.warning
        : _isFailureStatus(context, status)
        ? AppColors.danger
        : AppColors.textMuted;
    // Borderless white cards; the active device is shown by its connected
    // status + latency, not a tinted background.
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _openMenu(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.desktop_mac_outlined,
                      size: 20,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: AppTextSize.body,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: AppTextSize.small,
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Row(
                children: [
                  Expanded(
                    child: _TransportText(
                      active: active,
                      ready: ready,
                      connecting: connecting,
                      status: status,
                    ),
                  ),
                  _LatencyText(latencyMs: latencyMs, ready: ready),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed-feel "add device" tile that closes the grid.
class _AddDeviceCard extends StatelessWidget {
  const _AddDeviceCard({required this.accent, required this.onAdd});

  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    return Material(
      color: AppColors.bgSurface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 24, color: accent),
              const SizedBox(height: AppSpacing.s),
              Text(
                prefs.t('device.addByScan'),
                style: TextStyle(
                  color: accent,
                  fontSize: AppTextSize.small,
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

class _DeviceMenuItem extends StatelessWidget {
  const _DeviceMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.l,
          vertical: AppSpacing.m,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: AppSpacing.m),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.bgElevated,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    ),
  );
}

class _EmptyDeviceState extends StatelessWidget {
  const _EmptyDeviceState({required this.accent, required this.onAdd});
  final Color accent;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.devices_other_outlined, size: 48, color: accent),
          const SizedBox(height: AppSpacing.m),
          Text(
            prefs.t('device.emptyTitle'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: AppTextSize.title,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            prefs.t('device.emptySubtitle'),
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: AppTextSize.small,
            ),
          ),
          const SizedBox(height: AppSpacing.l),
          FilledButton(
            onPressed: onAdd,
            child: Text(prefs.t('device.scanAdd')),
          ),
        ],
      ),
    );
  }
}

class _TransportText extends StatelessWidget {
  const _TransportText({
    required this.active,
    required this.ready,
    this.connecting = false,
    required this.status,
  });
  final bool active;
  final bool ready;
  final bool connecting;
  final String status;

  @override
  Widget build(BuildContext context) {
    final prefs = AppPreferences.of(context);
    final label = connecting ? prefs.t('app.connecting') : status;
    final relayLabel = prefs.t('connection.relay');
    final pending =
        connecting ||
        status == prefs.t('app.connecting') ||
        status == prefs.t('app.syncing') ||
        status == prefs.t('app.reconnecting') ||
        status == prefs.t('app.reconnectingShort');
    final color = !active
        ? AppColors.textMuted
        : pending
        ? AppColors.warning
        : ready
        ? status == relayLabel || status.toLowerCase() == 'relay'
              ? AppColors.cyan
              : AppColors.success
        : _isFailureStatus(context, status)
        ? AppColors.danger
        : AppColors.textMuted;
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 12,
        height: 1,
        fontWeight: FontWeight.w800,
      ),
    );
    if (!connecting) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 13,
          height: 13,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        text,
      ],
    );
  }
}

bool _isFailureStatus(BuildContext context, String status) {
  final prefs = AppPreferences.of(context);
  return status == prefs.t('app.connectError') ||
      status == prefs.t('status.failed') ||
      status == prefs.t('status.rejected');
}

class _LatencyText extends StatelessWidget {
  const _LatencyText({required this.latencyMs, required this.ready});
  final int? latencyMs;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    if (!ready || latencyMs == null) return const SizedBox.shrink();
    final text = '${latencyMs}ms';
    final color = AppColors.textSubtle;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: color,
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
