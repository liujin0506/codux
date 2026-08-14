use super::options::*;
use super::widgets::*;
use super::*;

pub(super) fn settings_developer_pane(
    settings: &SettingsSummary,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
) -> AnyElement {
    let language = settings.language.as_str();
    settings_form(vec![
        settings_card(
            None,
            None,
            vec![
                settings_row(
                    settings_text(
                        language,
                        "settings.developer.performance_monitor",
                        "Performance Monitor HUD",
                    ),
                    None,
                    settings_toggle(
                        "settings-dev-hud",
                        settings.developer_hud,
                        cx,
                        |app, window, cx| app.toggle_developer_hud(window, cx),
                    ),
                )
                .into_any_element(),
                settings_row(
                    settings_text(
                        language,
                        "settings.developer.performance_monitor_interval",
                        "Performance Monitor Interval",
                    ),
                    None,
                    settings_select_impl(
                        "settings-dev-refresh",
                        &settings.developer_refresh,
                        developer_refresh_options(),
                        window,
                        cx,
                        language,
                        |app, value, window, cx| app.set_developer_refresh(value, window, cx),
                    ),
                )
                .into_any_element(),
            ],
            cx,
        )
        .into_any_element(),
    ])
    .into_any_element()
}

pub(super) struct RuntimeToolBlockInput<'a> {
    pub(super) label: String,
    pub(super) tool_key: &'static str,
    pub(super) model_key: &'static str,
    pub(super) path_key: &'static str,
    pub(super) permission: &'a str,
    pub(super) model: &'a str,
    pub(super) path: &'a str,
    pub(super) placeholder: &'static str,
    pub(super) path_placeholder: &'static str,
    pub(super) include_permission: bool,
    pub(super) include_codex_effort: bool,
    pub(super) codex_effort: &'a str,
    pub(super) language: &'a str,
}

pub(super) fn settings_runtime_tool_block(
    input: RuntimeToolBlockInput<'_>,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
) -> AnyElement {
    let RuntimeToolBlockInput {
        label,
        tool_key,
        model_key,
        path_key,
        permission,
        model,
        path,
        placeholder,
        path_placeholder,
        include_permission,
        include_codex_effort,
        codex_effort,
        language,
    } = input;
    let mut children = Vec::new();
    if include_permission {
        children.push(
            settings_row(
                settings_text(
                    language,
                    "settings.ai.permission.full_access_toggle",
                    "Full Access",
                ),
                None,
                settings_select_impl(
                    tool_key,
                    permission,
                    runtime_tool_permission_options(language),
                    window,
                    cx,
                    language,
                    move |app, value, window, cx| {
                        app.set_runtime_tool_permission(tool_key, value, window, cx)
                    },
                ),
            )
            .into_any_element(),
        );
    }
    children.push(
        settings_row(
            settings_text(language, "settings.ai.tool.executable", "Launch Command"),
            Some(settings_text(
                language,
                "settings.ai.tool.executable_help",
                "Leave empty to use the default command.",
            )),
            settings_text_input(
                SharedString::from(format!("settings-{path_key}")),
                path,
                path_placeholder,
                false,
                window,
                cx,
                move |app, value, window, cx| {
                    app.set_runtime_tool_path(path_key, value, window, cx)
                },
            ),
        )
        .into_any_element(),
    );
    children.push(
        settings_row(
            settings_text(language, "settings.ai.tool.default_model", "Default Model"),
            None,
            settings_text_input(
                SharedString::from(format!("settings-{model_key}")),
                model,
                placeholder,
                false,
                window,
                cx,
                move |app, value, window, cx| {
                    app.set_runtime_tool_model(model_key, value, window, cx)
                },
            ),
        )
        .into_any_element(),
    );
    if include_codex_effort {
        children.push(
            settings_row(
                settings_text(
                    language,
                    "settings.ai.tool.reasoning_effort",
                    "Reasoning Effort",
                ),
                None,
                settings_select_impl(
                    "settings-codex-effort",
                    codex_effort,
                    codex_effort_options(language),
                    window,
                    cx,
                    language,
                    |app, value, window, cx| app.set_codex_effort(value, window, cx),
                ),
            )
            .into_any_element(),
        );
    }

    settings_card(Some(label), None, children, cx).into_any_element()
}
