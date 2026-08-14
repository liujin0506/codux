impl SettingsService {
    pub fn set_runtime_tool_permission(
        &self,
        tool_key: &str,
        permission: &str,
    ) -> Result<SettingsSummary, String> {
        if matches!(tool_key, "kiro" | "kimi") {
            return self.update_runtime_tool_string(tool_key, "default".to_string());
        }
        self.update_runtime_tool_string(tool_key, sanitize_tool_permission(permission))
    }

    pub fn set_runtime_tool_model(
        &self,
        model_key: &str,
        model: &str,
    ) -> Result<SettingsSummary, String> {
        self.update_runtime_tool_string(model_key, model.trim().chars().take(160).collect())
    }

    pub fn set_runtime_tool_path(
        &self,
        path_key: &str,
        path: &str,
    ) -> Result<SettingsSummary, String> {
        self.update_runtime_tool_string(path_key, sanitize_runtime_tool_path(path))
    }

    pub fn set_codex_effort(&self, effort: &str) -> Result<SettingsSummary, String> {
        self.update_runtime_tool_string("codexEffort", sanitize_codex_effort(effort))
    }
}
