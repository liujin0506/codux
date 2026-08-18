import 'package:codux_flutter/models/remote_models.dart';
import 'package:codux_flutter/services/storage_service.dart';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('project list cache is scoped by host without relay url', () async {
    final storage = StorageService();
    const device = StoredDevice(
      server: 'https://relay-a.example',
      hostId: 'host-1',
      deviceId: 'device-1',
      token: 'token',
      name: 'Phone',
      transports: [
        RemoteTransportCandidate(
          kind: RemoteTransportKind.iroh,
          url: 'https://relay-a.example',
          nodeId: 'node-1',
          relayUrl: 'https://relay.example',
        ),
      ],
    );
    const sameHostWithDifferentServer = StoredDevice(
      server: 'https://relay-b.example',
      hostId: 'host-1',
      deviceId: 'device-1',
      token: 'token',
      name: 'Phone',
      transports: [
        RemoteTransportCandidate(
          kind: RemoteTransportKind.iroh,
          url: 'https://relay-b.example',
          nodeId: 'node-1',
          relayUrl: 'https://relay.example',
        ),
      ],
    );

    await storage.saveCachedProjects(device, const [
      ProjectInfo(id: 'project-1', name: 'Codux', path: '/Volumes/Web/codux'),
    ]);

    final cached = await storage.loadCachedProjects(
      sameHostWithDifferentServer,
    );

    expect(cached, hasLength(1));
    expect(cached.single.id, 'project-1');
    expect(cached.single.name, 'Codux');
    expect(cached.single.path, '/Volumes/Web/codux');
  });

  test('loadDevices keeps iroh transports from cached devices', () async {
    SharedPreferences.setMockInitialValues({
      'flutter.${StorageService.devicesKey}': jsonEncode([
        {
          'server': 'https://relay.example',
          'hostId': 'host-1',
          'deviceId': 'device-1',
          'token': '',
          'name': 'Phone',
          'transports': [
            {
              'kind': RemoteTransportKind.iroh,
              'role': 'host',
              'url': 'https://relay.example',
              'nodeId': 'node-1',
              'relayUrl': 'https://relay.example',
              'ticket': 'endpoint-ticket',
            },
          ],
        },
      ]),
    });

    final devices = await StorageService().loadDevices();

    expect(devices.single.transports, hasLength(1));
    final iroh = devices.single.transportByKind(RemoteTransportKind.iroh);
    expect(iroh?.nodeId, 'node-1');
    expect(iroh?.relayUrl, 'https://relay.example');
    expect(iroh?.ticket, isEmpty);
  });

  test(
    'workspace selection is scoped by host and keeps each project choice',
    () async {
      const device = StoredDevice(
        server: 'https://relay-a.example',
        hostId: 'host-1',
        deviceId: 'device-1',
        token: 'token',
        name: 'Phone',
      );
      const sameHost = StoredDevice(
        server: 'https://relay-b.example',
        hostId: 'host-1',
        deviceId: 'device-1',
        token: 'token',
        name: 'Phone',
      );
      final storage = StorageService();

      await storage.saveWorkspaceSelection(
        device,
        projectId: 'project-1',
        worktreeId: 'worktree-1',
      );
      await storage.saveWorkspaceSelection(
        device,
        projectId: 'project-2',
        worktreeId: 'project-2',
      );

      final selection = await storage.loadWorkspaceSelection(sameHost);

      expect(selection.projectId, 'project-2');
      expect(selection.worktreeIdForProject('project-1'), 'worktree-1');
      expect(selection.worktreeIdForProject('project-2'), 'project-2');
    },
  );
}
