use super::*;
use crate::cnb::CnbStore;
use codux_runtime_live::cnb::CnbTokens;

impl RemoteHostRuntime {
    pub(super) fn handle_cnb_tokens_get(&self, envelope: &RemoteEnvelope) {
        self.reply_cnb_tokens(envelope);
    }

    pub(super) fn handle_cnb_tokens_set(&self, envelope: &RemoteEnvelope) {
        let tokens = CnbTokens {
            token_cool: envelope
                .payload
                .get("tokenCool")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
            token_woa: envelope
                .payload
                .get("tokenWoa")
                .and_then(Value::as_str)
                .unwrap_or_default()
                .to_string(),
        };
        match CnbStore::from_support_dir(self.support_dir.clone()).replace(tokens) {
            Ok(_) => self.reply_cnb_tokens(envelope),
            Err(error) => self.send_error(envelope, &error),
        }
    }

    fn reply_cnb_tokens(&self, envelope: &RemoteEnvelope) {
        self.reply(envelope, REMOTE_CNB_TOKENS_RESULT, self.cnb_tokens_payload());
    }

    fn cnb_tokens_payload(&self) -> Value {
        let snapshot = CnbStore::from_support_dir(self.support_dir.clone()).snapshot();
        json!({
            "tokenCoolConfigured": snapshot.token_cool_configured,
            "tokenWoaConfigured": snapshot.token_woa_configured,
        })
    }

    pub(super) fn handle_cnb_invoke(&self, envelope: &RemoteEnvelope) {
        match crate::cnb::invoke_from_payload(&self.support_dir, envelope.payload.clone()) {
            Ok(result) => self.reply(envelope, REMOTE_CNB_INVOKE_RESULT, result),
            Err(error) => self.send_error(envelope, &error),
        }
    }
}
