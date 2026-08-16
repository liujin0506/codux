import 'package:codux_flutter/services/terminal_handoff_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('agent host with desktop owner shows idle copy', () {
    expect(
      terminalHandoffMessageKey(
        isHeadlessAgentHost: true,
        viewportOwner: 'desktop',
      ),
      'terminal.handoff.idle',
    );
  });

  test('desktop host with desktop owner keeps desktop copy', () {
    expect(
      terminalHandoffMessageKey(
        isHeadlessAgentHost: false,
        viewportOwner: 'desktop',
      ),
      'terminal.handoff.takenOver',
    );
  });

  test('remote owner shows other-device copy', () {
    expect(
      terminalHandoffMessageKey(
        isHeadlessAgentHost: true,
        viewportOwner: 'remote:phone-b',
      ),
      'terminal.handoff.takenOverOtherDevice',
    );
  });

  test('detects headless agent from host.info app field', () {
    expect(isHeadlessAgentHostApp({'app': 'codux-agent'}), isTrue);
    expect(isHeadlessAgentHostApp({'app': 'Codux'}), isFalse);
    expect(
      isHeadlessAgentHostApp({'runtimeInstanceId': 'host-1-agent'}),
      isTrue,
    );
  });
}
