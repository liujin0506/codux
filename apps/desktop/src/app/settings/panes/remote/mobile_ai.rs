use super::*;

/// The phone truncates anything past this, so the pane stops offering rows the
/// host could never advertise.
const MOBILE_AI_COMMAND_LIMIT: usize = 5;

/// Toggle plus the editable shortcut list. Rows are saved as typed — a blank
/// command is filtered out when host.info is built, so clearing a field while
/// editing does not make the row vanish under the cursor.
pub(super) fn settings_remote_mobile_ai_section(
    settings: &SettingsSummary,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
    language: &str,
) -> AnyElement {
    let enabled = settings.remote_mobile_ai_button;
    let commands: Vec<(String, String)> = settings
        .remote_mobile_ai_commands
        .iter()
        .map(|entry| (entry.command.clone(), entry.label.clone()))
        .collect();

    let toggle_row = settings_row(
        settings_text(language, "settings.remote.mobile_ai", "Phone AI Shortcuts"),
        Some(settings_text(
            language,
            "settings.remote.mobile_ai.help",
            "Show these commands in the phone's terminal tool menu. Tapping one runs it.",
        )),
        settings_toggle(
            "settings-remote-mobile-ai-enabled",
            enabled,
            cx,
            |app, window, cx| app.toggle_remote_mobile_ai_button(window, cx),
        ),
    );

    let mut section = div().flex().flex_col().gap(px(12.0)).child(toggle_row);

    if enabled {
        let mut rows = div().flex().flex_col().gap(px(8.0));
        for (index, (command, label)) in commands.iter().enumerate() {
            rows = rows.child(mobile_ai_command_row(
                index, command, label, &commands, window, cx, language,
            ));
        }
        section = section.child(rows);

        if commands.len() < MOBILE_AI_COMMAND_LIMIT {
            let existing = commands.clone();
            section = section.child(
                div().child(
                    Button::new("settings-remote-mobile-ai-add")
                        .compact()
                        .ghost()
                        .icon(Icon::new(HeroIconName::Plus).size_3p5())
                        .on_click(cx.listener(move |app, _event, window, cx| {
                            let mut next = existing.clone();
                            next.push((String::new(), String::new()));
                            app.set_remote_mobile_ai_commands(next, window, cx);
                        }))
                        .child(div().text_size(rems(0.8125)).child(settings_text(
                            language,
                            "settings.remote.mobile_ai.add",
                            "Add shortcut",
                        ))),
                ),
            );
        }
    }

    section.into_any_element()
}

fn mobile_ai_command_row(
    index: usize,
    command: &str,
    label: &str,
    commands: &[(String, String)],
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
    language: &str,
) -> AnyElement {
    let command_input = {
        let commands = commands.to_vec();
        settings_text_input(
            format!("remote-mobile-ai-command-{index}"),
            command,
            settings_text(
                language,
                "settings.remote.mobile_ai.command_placeholder",
                "Command, for example claude",
            ),
            false,
            window,
            cx,
            move |app, value, window, cx| {
                let mut next = commands.clone();
                if let Some(entry) = next.get_mut(index) {
                    entry.0 = value;
                }
                app.set_remote_mobile_ai_commands(next, window, cx);
            },
        )
    };
    let label_input = {
        let commands = commands.to_vec();
        settings_text_input(
            format!("remote-mobile-ai-label-{index}"),
            label,
            settings_text(
                language,
                "settings.remote.mobile_ai.label_placeholder",
                "Caption (optional)",
            ),
            false,
            window,
            cx,
            move |app, value, window, cx| {
                let mut next = commands.clone();
                if let Some(entry) = next.get_mut(index) {
                    entry.1 = value;
                }
                app.set_remote_mobile_ai_commands(next, window, cx);
            },
        )
    };
    let remove = {
        let commands = commands.to_vec();
        settings_icon_button_state(
            format!("remote-mobile-ai-remove-{index}"),
            HeroIconName::Trash,
            false,
            cx,
            move |app, _event, window, cx| {
                let mut next = commands.clone();
                if index < next.len() {
                    next.remove(index);
                }
                app.set_remote_mobile_ai_commands(next, window, cx);
            },
        )
    };

    div()
        .w_full()
        .min_w_0()
        .flex()
        .items_center()
        .gap(px(8.0))
        .child(div().flex_1().min_w_0().child(command_input))
        .child(div().w(px(140.0)).min_w_0().child(label_input))
        .child(remove)
        .into_any_element()
}
