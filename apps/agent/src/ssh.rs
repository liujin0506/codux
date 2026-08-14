//! SSH profiles owned by the headless runtime.
//!
//! The desktop and a headless agent can both host terminals.  Keeping the
//! profile file in the runtime's data directory means `codux-ssh` resolves
//! credentials on the same side where the terminal is actually running.

use chrono::Utc;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::{
    fs,
    path::PathBuf,
    sync::{Mutex, OnceLock},
};
use uuid::Uuid;

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct SSHProfile {
    id: String,
    name: String,
    host: String,
    port: u16,
    username: String,
    credential_kind: String,
    private_key_path: String,
    updated_at: i64,
    #[serde(default)]
    password: Option<String>,
    #[serde(default)]
    key_passphrase: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct SSHProfileUpsertRequest {
    id: Option<String>,
    name: String,
    host: String,
    port: u16,
    username: String,
    credential_kind: String,
    private_key_path: Option<String>,
    password: Option<String>,
    key_passphrase: Option<String>,
}

static STORE_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

fn store_lock() -> &'static Mutex<()> {
    STORE_LOCK.get_or_init(|| Mutex::new(()))
}

fn profiles_path() -> PathBuf {
    crate::projects::agent_data_dir().join("ssh_profiles.json")
}

pub fn ensure_store() -> Result<(), String> {
    let _guard = store_lock()
        .lock()
        .map_err(|_| "SSH profile store lock poisoned.".to_string())?;
    let path = profiles_path();
    if path.exists() {
        return Ok(());
    }
    save_profiles(&path, &[])
}

pub fn list_payload() -> Result<Value, String> {
    let _guard = store_lock()
        .lock()
        .map_err(|_| "SSH profile store lock poisoned.".to_string())?;
    let profiles = load_profiles(&profiles_path())?;
    Ok(public_profiles(&profiles))
}

pub fn upsert_payload(payload: Value) -> Result<Value, String> {
    let request: SSHProfileUpsertRequest =
        serde_json::from_value(payload).map_err(|error| format!("Invalid SSH profile: {error}"))?;
    let profile = sanitize_request(request)?;
    let _guard = store_lock()
        .lock()
        .map_err(|_| "SSH profile store lock poisoned.".to_string())?;
    let path = profiles_path();
    let mut profiles = load_profiles(&path)?;
    if let Some(index) = profiles.iter().position(|item| item.id == profile.id) {
        profiles[index] = profile;
    } else {
        profiles.push(profile);
    }
    save_profiles(&path, &profiles)?;
    Ok(public_profiles(&profiles))
}

pub fn remove_payload(payload: &Value) -> Result<Value, String> {
    let id = payload
        .get("id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| "SSH profile id is required.".to_string())?;
    let _guard = store_lock()
        .lock()
        .map_err(|_| "SSH profile store lock poisoned.".to_string())?;
    let path = profiles_path();
    let mut profiles = load_profiles(&path)?;
    profiles.retain(|profile| profile.id != id);
    save_profiles(&path, &profiles)?;
    Ok(public_profiles(&profiles))
}

fn load_profiles(path: &PathBuf) -> Result<Vec<SSHProfile>, String> {
    let Ok(text) = fs::read_to_string(path) else {
        return Ok(Vec::new());
    };
    if text.trim().is_empty() {
        return Ok(Vec::new());
    }
    let root: Value = serde_json::from_str(&text)
        .map_err(|error| format!("Unable to load ssh_profiles.json: {error}"))?;
    let profiles = root
        .get("sshProfiles")
        .cloned()
        .or_else(|| root.as_array().map(|_| root.clone()))
        .unwrap_or(Value::Array(Vec::new()));
    serde_json::from_value(profiles).map_err(|error| format!("Invalid ssh_profiles.json: {error}"))
}

fn save_profiles(path: &PathBuf, profiles: &[SSHProfile]) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let text = serde_json::to_string_pretty(profiles).map_err(|error| error.to_string())?;
    fs::write(path, text).map_err(|error| error.to_string())
}

fn public_profiles(profiles: &[SSHProfile]) -> Value {
    json!({
        "profiles": profiles.iter().map(|profile| {
            json!({
                "id": profile.id,
                "name": if profile.name.is_empty() {
                    format!("{}@{}", profile.username, profile.host)
                } else {
                    profile.name.clone()
                },
                "endpoint": format!("{}@{}:{}", profile.username, profile.host, profile.port),
                "credential": profile.credential_kind,
            })
        }).collect::<Vec<_>>(),
    })
}

fn sanitize_request(request: SSHProfileUpsertRequest) -> Result<SSHProfile, String> {
    let host = request.host.trim().to_string();
    let username = request.username.trim().to_string();
    if host.is_empty() {
        return Err("Host cannot be empty.".to_string());
    }
    if username.is_empty() {
        return Err("Username cannot be empty.".to_string());
    }
    let credential_kind = match request.credential_kind.as_str() {
        "password" => "password",
        "privateKey" => "privateKey",
        _ => "none",
    }
    .to_string();
    let private_key_path = request
        .private_key_path
        .unwrap_or_default()
        .trim()
        .to_string();
    let password = normalized(request.password);
    let key_passphrase = normalized(request.key_passphrase);
    if credential_kind == "password" && password.is_none() {
        return Err("Password cannot be empty.".to_string());
    }
    if credential_kind == "privateKey" && private_key_path.is_empty() {
        return Err("Private key path cannot be empty.".to_string());
    }
    Ok(SSHProfile {
        id: request
            .id
            .and_then(|value| normalized(Some(value)))
            .unwrap_or_else(|| Uuid::new_v4().to_string()),
        name: request.name.trim().to_string(),
        host,
        port: request.port.clamp(1, 65535),
        username,
        credential_kind,
        private_key_path,
        updated_at: Utc::now().timestamp(),
        password,
        key_passphrase,
    })
}

fn normalized(value: Option<String>) -> Option<String> {
    value
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn public_profiles_never_include_credentials() {
        let profiles = vec![SSHProfile {
            id: "profile-1".to_string(),
            name: "staging".to_string(),
            host: "example.test".to_string(),
            port: 22,
            username: "root".to_string(),
            credential_kind: "password".to_string(),
            private_key_path: String::new(),
            updated_at: 1,
            password: Some("secret".to_string()),
            key_passphrase: Some("passphrase".to_string()),
        }];

        let value = public_profiles(&profiles);
        let text = value.to_string();
        assert!(text.contains("profile-1"));
        assert!(!text.contains("secret"));
        assert!(!text.contains("passphrase"));
    }

    #[test]
    fn sanitize_requires_credentials_for_selected_modes() {
        let request = SSHProfileUpsertRequest {
            id: None,
            name: String::new(),
            host: "example.test".to_string(),
            port: 22,
            username: "root".to_string(),
            credential_kind: "password".to_string(),
            private_key_path: None,
            password: None,
            key_passphrase: None,
        };
        assert_eq!(
            sanitize_request(request).unwrap_err(),
            "Password cannot be empty."
        );
    }
}
