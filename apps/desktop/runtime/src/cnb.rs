use crate::runtime_paths::app_support_dir;
use crate::settings::SettingsSummary;
use codux_runtime_live::cnb::{CnbTokens, invoke, load_tokens, save_tokens, tokens_file_path};
use serde_json::Value;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct CnbTokensSnapshot {
    pub token_cool_configured: bool,
    pub token_woa_configured: bool,
}

pub struct CnbStore {
    state_file: PathBuf,
    tokens: CnbTokens,
}

impl CnbStore {
    pub fn from_support_dir(support_dir: PathBuf) -> Self {
        let state_file = tokens_file_path(&support_dir);
        Self {
            tokens: load_tokens(&state_file),
            state_file,
        }
    }

    pub fn load_or_seed() -> Self {
        Self::from_support_dir(app_support_dir())
    }

    pub fn snapshot(&self) -> CnbTokensSnapshot {
        CnbTokensSnapshot {
            token_cool_configured: self.tokens.cool_configured(),
            token_woa_configured: self.tokens.woa_configured(),
        }
    }

    pub fn tokens(&self) -> &CnbTokens {
        &self.tokens
    }

    pub fn set_token(&mut self, site: &str, token: &str) -> Result<CnbTokensSnapshot, String> {
        let token = token.trim();
        match site.trim().to_ascii_lowercase().as_str() {
            "cool" | "cnb.cool" | "tokencool" => {
                self.tokens.token_cool = token.to_string();
            }
            "woa" | "cnb.woa.com" | "tokenwoa" => {
                self.tokens.token_woa = token.to_string();
            }
            _ => return Err("CNB site must be cool or woa.".to_string()),
        }
        save_tokens(&self.state_file, &self.tokens)?;
        Ok(self.snapshot())
    }

    pub fn replace(&mut self, tokens: CnbTokens) -> Result<CnbTokensSnapshot, String> {
        self.tokens = tokens.sanitized();
        save_tokens(&self.state_file, &self.tokens)?;
        Ok(self.snapshot())
    }
}

pub fn overlay_token_flags(summary: &mut SettingsSummary, settings_path: &Path) {
    let Some(support_dir) = settings_path.parent() else {
        return;
    };
    let snapshot = CnbStore::from_support_dir(support_dir.to_path_buf()).snapshot();
    summary.cnb_token_cool_configured = snapshot.token_cool_configured;
    summary.cnb_token_woa_configured = snapshot.token_woa_configured;
}

pub fn invoke_from_payload(support_dir: &Path, payload: Value) -> Result<Value, String> {
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
    invoke(&args, &tokens_file_path(support_dir))
}

pub fn render_cnb_launch_context_from_support_dir(support_dir: PathBuf) -> Option<String> {
    let store = CnbStore::from_support_dir(support_dir);
    if !store.tokens().any_configured() {
        return None;
    }
    Some(
        [
            "Codux saved CNB tokens for cnb.cool and cnb.woa.com are available through terminal commands.".to_string(),
            "Always run `codux-cnb status` at the time of use to confirm the current repository and which site tokens are configured.".to_string(),
            "Use `codux-cnb issues`, `codux-cnb prs`, `codux-cnb builds`, and related subcommands for the current git remote. Add `--site cool|woa` or `--repo group/name` only when the working tree is not a CNB checkout.".to_string(),
            "Do not grep the repository or inspect Codux config files to discover CNB tokens; use the wrapper.".to_string(),
            "Do not ask for, print, infer, or hardcode CNB access tokens.".to_string(),
        ]
        .join("\n"),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    #[test]
    fn store_saves_tokens_without_exposing_them_in_snapshot() {
        let dir = std::env::temp_dir().join(format!("codux-cnb-store-{}", Uuid::new_v4()));
        std::fs::create_dir_all(&dir).unwrap();
        let mut store = CnbStore::from_support_dir(dir.clone());
        let snapshot = store.set_token("cool", " secret-token ").unwrap();
        assert!(snapshot.token_cool_configured);
        assert!(!snapshot.token_woa_configured);
        assert!(!format!("{snapshot:?}").contains("secret-token"));

        let context = render_cnb_launch_context_from_support_dir(dir.clone()).unwrap();
        assert!(context.contains("codux-cnb status"));
        assert!(!context.contains("secret-token"));

        store.set_token("cool", "").unwrap();
        assert!(render_cnb_launch_context_from_support_dir(dir.clone()).is_none());
        let _ = std::fs::remove_dir_all(dir);
    }
}
