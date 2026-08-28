//! CNB tokens owned by the headless runtime.
//!
//! The desktop syncs tokens here so `codux-cnb` on a remote agent can call
//! cnb.cool / cnb.woa.com from the host that actually has network access.

use codux_runtime_live::cnb::{CnbTokens, invoke, load_tokens, save_tokens, tokens_file_path};
use serde_json::Value;
use std::sync::{Mutex, OnceLock};

static STORE_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

fn store_lock() -> &'static Mutex<()> {
    STORE_LOCK.get_or_init(|| Mutex::new(()))
}

fn tokens_path() -> std::path::PathBuf {
    tokens_file_path(&crate::projects::agent_data_dir())
}

pub fn get_payload() -> Result<Value, String> {
    let _guard = store_lock()
        .lock()
        .map_err(|_| "CNB token store lock poisoned.".to_string())?;
    let tokens = load_tokens(&tokens_path());
    Ok(tokens.redacted())
}

pub fn set_payload(payload: Value) -> Result<Value, String> {
    let _guard = store_lock()
        .lock()
        .map_err(|_| "CNB token store lock poisoned.".to_string())?;
    let tokens = CnbTokens {
        token_cool: payload
            .get("tokenCool")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string(),
        token_woa: payload
            .get("tokenWoa")
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_string(),
    }
    .sanitized();
    save_tokens(&tokens_path(), &tokens)?;
    Ok(tokens.redacted())
}

pub fn invoke_payload(payload: Value) -> Result<Value, String> {
    let args = payload
        .get("args")
        .and_then(Value::as_array)
        .ok_or_else(|| "cnb.invoke: args must be an array of strings".to_string())?
        .iter()
        .map(|value| {
            value
                .as_str()
                .map(str::to_string)
                .ok_or_else(|| "cnb.invoke: args must be strings".to_string())
        })
        .collect::<Result<Vec<_>, _>>()?;
    if args.is_empty() {
        return Err("cnb.invoke: args cannot be empty".to_string());
    }
    let _guard = store_lock()
        .lock()
        .map_err(|_| "CNB token store lock poisoned.".to_string())?;
    invoke(&args, &tokens_path())
}
