use codux_protocol::{REMOTE_PROTOCOL_VERSION, RemoteTransportCandidate, host_capabilities};
use serde_json::{Value, json};

/// One host-configured shortcut in the mobile terminal's tool menu.
#[derive(Clone, Debug, Default)]
pub struct MobileAiCommand {
    pub command: String,
    /// Optional button caption; phones fall back to their own translation.
    pub label: String,
}

/// The host-configured AI shortcuts the mobile terminal offers. The host owns
/// both the command list and whether the buttons are shown at all, so phones
/// never hard-code a command the host may not have installed.
#[derive(Clone, Debug, Default)]
pub struct MobileAiTool {
    pub enabled: bool,
    pub commands: Vec<MobileAiCommand>,
}

impl MobileAiTool {
    /// The tool menu is a vertical stack above the FAB, so cap how many
    /// shortcuts a host can push before it runs off a phone screen.
    pub const MAX_COMMANDS: usize = 5;

    /// Shortcuts are only advertised when the switch is on and they actually
    /// carry a command to run.
    fn advertised(&self) -> Vec<(&str, &str)> {
        if !self.enabled {
            return Vec::new();
        }
        self.commands
            .iter()
            .filter_map(|entry| {
                let command = entry.command.trim();
                (!command.is_empty()).then_some((command, entry.label.trim()))
            })
            .take(Self::MAX_COMMANDS)
            .collect()
    }
}

pub struct HostInfoPayload {
    pub host_id: String,
    pub runtime_instance_id: String,
    pub name: String,
    pub platform: String,
    pub app: String,
    pub resource_subscriptions: Vec<String>,
    pub transports: Vec<RemoteTransportCandidate>,
    pub mobile_ai_tool: MobileAiTool,
}

pub fn host_info_payload(input: HostInfoPayload) -> Value {
    let mut capabilities = host_capabilities();
    capabilities["resourceSubscriptions"] = json!(input.resource_subscriptions);
    let commands = input.mobile_ai_tool.advertised();
    if !commands.is_empty() {
        capabilities["mobileTools"] = json!({
            "aiCommands": commands
                .into_iter()
                .map(|(command, label)| json!({ "command": command, "label": label }))
                .collect::<Vec<_>>(),
        });
    }
    json!({
        "hostId": input.host_id,
        "runtimeInstanceId": input.runtime_instance_id,
        "name": input.name,
        "platform": input.platform,
        "app": input.app,
        "protocolVersion": REMOTE_PROTOCOL_VERSION,
        "capabilities": capabilities,
        "transports": input.transports,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use codux_protocol::iroh_transport_candidate;

    fn command(command: &str, label: &str) -> MobileAiCommand {
        MobileAiCommand {
            command: command.to_string(),
            label: label.to_string(),
        }
    }

    fn payload_with(mobile_ai_tool: MobileAiTool) -> Value {
        host_info_payload(HostInfoPayload {
            host_id: "host-1".to_string(),
            runtime_instance_id: "runtime-1".to_string(),
            name: "Codux Mac".to_string(),
            platform: "macos".to_string(),
            app: "Codux".to_string(),
            resource_subscriptions: vec!["terminals".to_string()],
            transports: Vec::new(),
            mobile_ai_tool,
        })
    }

    #[test]
    fn host_info_payload_advertises_protocol_capabilities_and_transports() {
        let payload = host_info_payload(HostInfoPayload {
            host_id: "host-1".to_string(),
            runtime_instance_id: "runtime-1".to_string(),
            name: "Codux Mac".to_string(),
            platform: "macos".to_string(),
            app: "Codux".to_string(),
            resource_subscriptions: vec!["projects".to_string(), "terminals".to_string()],
            transports: vec![iroh_transport_candidate(
                "https://relay.example/v3",
                "node-1",
                "https://relay.example",
            )],
            mobile_ai_tool: MobileAiTool::default(),
        });

        assert_eq!(payload["hostId"], "host-1");
        assert_eq!(payload["runtimeInstanceId"], "runtime-1");
        assert_eq!(payload["protocolVersion"], REMOTE_PROTOCOL_VERSION);
        assert_eq!(payload["capabilities"]["domains"]["terminal"], true);
        assert_eq!(
            payload["capabilities"]["resourceSubscriptions"],
            json!(["projects", "terminals"])
        );
        assert_eq!(payload["transports"][0]["kind"], "iroh");
        assert_eq!(payload["transports"][0]["nodeId"], "node-1");
        assert_eq!(
            payload["transports"][0]["relayUrl"],
            "https://relay.example"
        );
    }

    #[test]
    fn mobile_ai_commands_are_advertised_in_configured_order() {
        let payload = payload_with(MobileAiTool {
            enabled: true,
            commands: vec![
                command("  claude  ", " Claude "),
                command("codex", ""),
                // Blank commands are dropped rather than shipped as dead buttons.
                command("   ", "Ghost"),
            ],
        });

        let advertised = &payload["capabilities"]["mobileTools"]["aiCommands"];
        assert_eq!(advertised.as_array().map(Vec::len), Some(2));
        assert_eq!(advertised[0]["command"], "claude");
        assert_eq!(advertised[0]["label"], "Claude");
        assert_eq!(advertised[1]["command"], "codex");
        assert_eq!(advertised[1]["label"], "");
    }

    #[test]
    fn mobile_ai_commands_are_capped_so_the_menu_stays_usable() {
        let payload = payload_with(MobileAiTool {
            enabled: true,
            commands: (0..MobileAiTool::MAX_COMMANDS + 3)
                .map(|index| command(&format!("cmd-{index}"), ""))
                .collect(),
        });

        let advertised = &payload["capabilities"]["mobileTools"]["aiCommands"];
        assert_eq!(
            advertised.as_array().map(Vec::len),
            Some(MobileAiTool::MAX_COMMANDS)
        );
        assert_eq!(advertised[0]["command"], "cmd-0");
    }

    #[test]
    fn mobile_ai_commands_are_hidden_when_switched_off_or_empty() {
        let disabled = payload_with(MobileAiTool {
            enabled: false,
            commands: vec![command("claude", "")],
        });
        assert!(disabled["capabilities"]["mobileTools"].is_null());

        let blank = payload_with(MobileAiTool {
            enabled: true,
            commands: vec![command("   ", "")],
        });
        assert!(blank["capabilities"]["mobileTools"].is_null());

        let none = payload_with(MobileAiTool {
            enabled: true,
            commands: Vec::new(),
        });
        assert!(none["capabilities"]["mobileTools"].is_null());
    }
}
