use serde_json::Value;
use std::{fs, path::Path};

pub fn write_runtime_tools(data_dir: &Path, runtime_tools: Option<&Value>) -> Result<(), String> {
    let Some(runtime_tools) = runtime_tools.filter(|value| value.is_object()) else {
        return Ok(());
    };
    fs::create_dir_all(data_dir).map_err(|error| error.to_string())?;
    let path = data_dir.join("tool_permissions.json");
    let content = serde_json::to_string(runtime_tools).map_err(|error| error.to_string())?;
    fs::write(path, content).map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn writes_runtime_tools_object_and_ignores_non_objects() {
        let dir = std::env::temp_dir().join(format!(
            "codux-agent-tool-permissions-{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .expect("clock")
                .as_nanos()
        ));
        fs::create_dir_all(&dir).unwrap();

        write_runtime_tools(&dir, Some(&json!("codex"))).unwrap();
        assert!(!dir.join("tool_permissions.json").exists());

        write_runtime_tools(
            &dir,
            Some(&json!({
                "codexPath": "/opt/custom/codex",
                "codexModel": "gpt-5.6"
            })),
        )
        .unwrap();
        let written: Value =
            serde_json::from_str(&fs::read_to_string(dir.join("tool_permissions.json")).unwrap())
                .unwrap();
        assert_eq!(written["codexPath"], "/opt/custom/codex");
        assert_eq!(written["codexModel"], "gpt-5.6");

        fs::remove_dir_all(dir).ok();
    }
}
