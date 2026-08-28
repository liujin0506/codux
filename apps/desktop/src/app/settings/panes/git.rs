use super::options::*;
use super::widgets::*;
use super::*;

pub(super) fn settings_git_pane(
    settings: &SettingsSummary,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
) -> AnyElement {
    let language = settings.language.as_str();
    settings_form(vec![
        settings_card(
            Some(settings_text(
                language,
                "settings.ai.git_commit_message",
                "Git Commit Message",
            )),
            None,
            vec![
                settings_row(
                    settings_text(
                        language,
                        "settings.ai.git_commit_message_provider",
                        "AI Provider",
                    ),
                    None,
                    settings_select_impl(
                        "settings-git-provider-auto",
                        &settings.git_commit_provider_id,
                        git_provider_options(settings, language),
                        window,
                        cx,
                        language,
                        |app, value, window, cx| app.set_git_commit_provider(value, window, cx),
                    ),
                )
                .into_any_element(),
                settings_row(
                    settings_text(language, "settings.ai.git_commit_message_tone", "Tone"),
                    None,
                    settings_select_impl(
                        "settings-git-tone",
                        &settings.git_commit_tone,
                        git_tone_options(),
                        window,
                        cx,
                        language,
                        |app, value, window, cx| app.set_git_commit_tone(value, window, cx),
                    ),
                )
                .into_any_element(),
                settings_row(
                    settings_text(language, "settings.language", "Language"),
                    None,
                    settings_select_impl(
                        "settings-git-language",
                        &settings.git_commit_language,
                        git_language_options(language),
                        window,
                        cx,
                        language,
                        |app, value, window, cx| app.set_git_commit_language(value, window, cx),
                    ),
                )
                .into_any_element(),
            ],
            cx,
        )
        .into_any_element(),
        settings_card(
            Some(settings_text(language, "settings.cnb.title", "CNB")),
            Some(settings_text(
                language,
                "settings.cnb.description",
                "Personal access tokens for Codex and other AI CLIs. Tokens stay inside Codux; remote agents call the CNB API from the remote host.",
            )),
            vec![
                settings_row(
                    settings_text(language, "settings.cnb.token_cool", "cnb.cool token"),
                    Some(settings_text(
                        language,
                        "settings.cnb.token_cool_help",
                        "Used for https://api.cnb.cool. A cnb.woa.com token will not work here.",
                    )),
                    settings_text_input(
                        "settings-cnb-token-cool",
                        "",
                        if settings.cnb_token_cool_configured {
                            settings_text(language, "common.configured", "Configured")
                        } else {
                            settings_text(language, "settings.cnb.token_cool", "cnb.cool token")
                        },
                        true,
                        window,
                        cx,
                        |app, value, window, cx| {
                            if !value.trim().is_empty() {
                                app.set_cnb_token("cool".to_string(), value, window, cx);
                            }
                        },
                    ),
                )
                .into_any_element(),
                settings_row(
                    settings_text(language, "settings.cnb.token_woa", "cnb.woa.com token"),
                    Some(settings_text(
                        language,
                        "settings.cnb.token_woa_help",
                        "Used for https://api.cnb.woa.com. A cnb.cool token will not work here.",
                    )),
                    settings_text_input(
                        "settings-cnb-token-woa",
                        "",
                        if settings.cnb_token_woa_configured {
                            settings_text(language, "common.configured", "Configured")
                        } else {
                            settings_text(
                                language,
                                "settings.cnb.token_woa",
                                "cnb.woa.com token",
                            )
                        },
                        true,
                        window,
                        cx,
                        |app, value, window, cx| {
                            if !value.trim().is_empty() {
                                app.set_cnb_token("woa".to_string(), value, window, cx);
                            }
                        },
                    ),
                )
                .into_any_element(),
            ],
            cx,
        )
        .into_any_element(),
        settings_card_flush(
            Some(settings_text(
                language,
                "settings.ai.git_commit_message_style_rules",
                "Style Rules",
            )),
            Some(settings_text(
                language,
                "settings.ai.git_commit_message_style_rules_placeholder",
                "Example: use Conventional Commits, keep subject under 72 characters.",
            )),
            vec![settings_textarea(
                "git-style-rules",
                &settings.git_commit_style_rules,
                4,
                settings_text(
                    language,
                    "settings.ai.git_commit_message_style_rules",
                    "Style Rules",
                ),
                window,
                cx,
                |app, value, window, cx| app.set_git_commit_style_rules(value, window, cx),
            )],
            cx,
        )
        .into_any_element(),
    ])
    .into_any_element()
}
