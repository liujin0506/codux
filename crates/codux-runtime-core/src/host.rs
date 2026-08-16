use codux_protocol::{REMOTE_PROTOCOL_VERSION, RemoteTransportCandidate, host_capabilities};
use serde_json::{Value, json};

/// Host-configured shortcut the mobile terminal offers in its tool menu. The
/// host owns both the command text and whether the button is shown at all, so
/// phones never hard-code a command the host may not have installed.
#[derive(Clone, Debug, Default)]
pub struct MobileAiTool {
    pub enabled: bool,
    pub command: String,
    /// Optional button caption; phones fall back to their own translation.
    pub label: String,
}

impl MobileAiTool {
    /// A shortcut is only advertised when it is switched on and actually has a
    /// command to run.
    fn advertised(&self) -> Option<(&str, &str)> {
        if !self.enabled {
            return None;
        }
        let command = self.command.trim();
        if command.is_empty() {
            return None;
        }
        Some((command, self.label.trim()))
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
    if let Some((command, label)) = input.mobile_ai_tool.advertised() {
        capabilities["mobileTools"] = json!({
            "aiCommand": {
                "command": command,
                "label": label,
            }
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
    fn mobile_ai_command_is_advertised_when_enabled() {
        let payload = payload_with(MobileAiTool {
            enabled: true,
            command: "  claude  ".to_string(),
            label: " Claude ".to_string(),
        });

        assert_eq!(
            payload["capabilities"]["mobileTools"]["aiCommand"]["command"],
            "claude"
        );
        assert_eq!(
            payload["capabilities"]["mobileTools"]["aiCommand"]["label"],
            "Claude"
        );
    }

    #[test]
    fn mobile_ai_command_is_hidden_when_switched_off_or_empty() {
        let disabled = payload_with(MobileAiTool {
            enabled: false,
            command: "claude".to_string(),
            label: String::new(),
        });
        assert!(disabled["capabilities"]["mobileTools"].is_null());

        let blank = payload_with(MobileAiTool {
            enabled: true,
            command: "   ".to_string(),
            label: String::new(),
        });
        assert!(blank["capabilities"]["mobileTools"].is_null());
    }
}
