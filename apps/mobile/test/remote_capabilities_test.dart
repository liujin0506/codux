import 'package:codux_flutter/services/remote_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile default terminal buffer window matches host default', () {
    expect(TerminalBufferCapability.mobileMaxChars, 200000);
    expect(TerminalBufferCapability.fallback.maxChars, 200000);
  });

  test('parses terminal buffer capability from host info', () {
    final capability = TerminalBufferCapability.fromHostInfo({
      'protocolVersion': 'v3.2',
      'capabilities': {
        'terminalBuffer': {
          'chunking': true,
          'maxChars': 180000,
          'chunkChars': 32768,
          'screenData': true,
          'baselineFailed': true,
        },
        'terminalOutput': {'staleOutput': true},
        'terminalViewport': {'keyframe': true},
      },
    }, clientMaxChars: 200000);

    expect(capability.chunking, isTrue);
    expect(capability.maxChars, 180000);
    expect(capability.chunkChars, 32768);
    expect(capability.requestId, isFalse);
    expect(capability.screenData, isTrue);
    expect(capability.baselineFailed, isTrue);
    expect(capability.staleOutput, isTrue);
    expect(capability.viewportKeyframe, isTrue);
  });

  test('parses request id capability', () {
    final capability = TerminalBufferCapability.fromHostInfo({
      'protocolVersion': 'v3.2',
      'capabilities': {
        'terminalBuffer': {
          'chunking': true,
          'maxChars': 65536,
          'chunkChars': 16384,
          'requestId': true,
        },
      },
    });

    expect(capability.requestId, isTrue);
  });

  test('limits terminal buffer capability to mobile default', () {
    final capability = TerminalBufferCapability.fromHostInfo({
      'protocolVersion': 'v3.2',
      'capabilities': {
        'terminalBuffer': {
          'chunking': true,
          'maxChars': 250000,
          'chunkChars': 32768,
        },
      },
    });

    expect(capability.chunking, isTrue);
    expect(capability.maxChars, TerminalBufferCapability.mobileMaxChars);
    expect(capability.chunkChars, 32768);
  });

  test('clamps terminal buffer capability to mobile limits', () {
    final capability = TerminalBufferCapability.fromHostInfo({
      'capabilities': {
        'terminalBuffer': {
          'chunking': true,
          'maxChars': 999999,
          'chunkChars': 999999,
        },
      },
    });

    expect(capability.maxChars, TerminalBufferCapability.mobileMaxChars);
    expect(capability.chunkChars, 65536);
  });

  test('falls back when host info has no terminal capability', () {
    final capability = TerminalBufferCapability.fromHostInfo({
      'protocolVersion': 'v3.0',
    });

    expect(capability.chunking, isFalse);
    expect(capability.maxChars, TerminalBufferCapability.mobileMaxChars);
    expect(capability.chunkChars, 16384);
  });

  test('resource subscription capability reads advertised resources', () {
    final capability = RemoteResourceSubscriptionCapability.fromHostInfo({
      'capabilities': {
        'resourceSubscriptions': ['projects', 'git.status'],
      },
    });

    expect(capability.supports('projects'), isTrue);
    expect(capability.supports('git.status'), isTrue);
    expect(capability.supports('worktrees'), isFalse);
  });

  test('ai shortcuts read the host commands in order', () {
    final capability = MobileAiToolCapability.fromHostInfo({
      'capabilities': {
        'mobileTools': {
          'aiCommands': [
            {'command': '  claude  ', 'label': '  Claude  '},
            {'command': 'codex'},
            // Blank commands never become dead buttons.
            {'command': '   ', 'label': 'Ghost'},
          ],
        },
      },
    });

    expect(capability.enabled, isTrue);
    expect(capability.commands.length, 2);
    expect(capability.commands.first.command, 'claude');
    expect(capability.commands.first.label, 'Claude');
    expect(capability.commands.last.command, 'codex');
    // No caption means the app falls back to its own translation.
    expect(capability.commands.last.label, isEmpty);
  });

  test('ai shortcuts are capped so the menu stays usable', () {
    final capability = MobileAiToolCapability.fromHostInfo({
      'capabilities': {
        'mobileTools': {
          'aiCommands': [
            for (var index = 0; index < MobileAiToolCapability.maxCommands + 3; index += 1)
              {'command': 'cmd-$index'},
          ],
        },
      },
    });

    expect(capability.commands.length, MobileAiToolCapability.maxCommands);
    expect(capability.commands.first.command, 'cmd-0');
  });

  test('ai shortcuts stay off when the host advertises nothing usable', () {
    expect(
      MobileAiToolCapability.fromHostInfo({'protocolVersion': 'v3.0'}).enabled,
      isFalse,
    );
    expect(
      MobileAiToolCapability.fromHostInfo({
        'capabilities': {
          'mobileTools': {
            'aiCommands': [
              {'command': '   '},
            ],
          },
        },
      }).enabled,
      isFalse,
    );
  });
}
