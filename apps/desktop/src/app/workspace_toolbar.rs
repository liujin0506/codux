use super::*;
use crate::app::{
    ui_helpers::{titlebar_drag_area, with_codux_tooltip},
    workspace_shared::{workspace_header_button, workspace_i18n},
};
use codux_runtime::{i18n::translate, settings::locale_from_language_setting};
use gpui::Rems;
use gpui_component::menu::{DropdownMenu, PopupMenuItem};

const WORKSPACE_TAB_TEXT_SIZE: Rems = Rems(0.75);
const WORKSPACE_TAB_LINE_HEIGHT: Rems = Rems(1.0);
const WORKSPACE_WINDOW_CONTROL_BUTTON_WIDTH: f32 = 30.0;
const WORKSPACE_WINDOW_CONTROL_GAP: f32 = 2.0;
const WORKSPACE_WINDOW_CONTROL_LEADING_MARGIN: f32 = 4.0;
const WORKSPACE_WINDOW_CONTROLS_WIDTH: f32 = WORKSPACE_WINDOW_CONTROL_LEADING_MARGIN
    + WORKSPACE_WINDOW_CONTROL_BUTTON_WIDTH * 3.0
    + WORKSPACE_WINDOW_CONTROL_GAP * 2.0;

impl CoduxApp {
    pub(in crate::app) fn workspace_toolbar(
        &self,
        _window: &mut Window,
        cx: &mut Context<Self>,
    ) -> impl IntoElement {
        let active_index = match self.workspace_view {
            WorkspaceView::Terminal => 0,
            WorkspaceView::Files => 1,
            WorkspaceView::Review => 2,
            WorkspaceView::Stats => 3,
        };
        let has_project_context = self.state.selected_project.is_some();
        let remote_project_device_id = self
            .state
            .selected_project
            .as_ref()
            .and_then(|project| project.remote_device_id().map(str::to_string));
        let connected_remote_project_device_id =
            remote_project_device_id.as_ref().and_then(|device_id| {
                (self.remote_link_states.get(device_id)
                    == Some(&codux_runtime::remote::ControllerLinkState::Connected))
                .then(|| device_id.clone())
            });
        let task_column_reveal_button = if has_project_context && self.task_column_collapsed {
            task_column_expand_button(&self.state.settings.language, cx).into_any_element()
        } else {
            gpui::Empty.into_any_element()
        };
        column_header(
            // No `items_center` here: children stretch to full header height so the
            // draggable middle area fills it. Each side group centers its own content.
            div()
                .flex()
                .justify_between()
                .w_full()
                .h_full()
                .child(
                    div()
                        .flex()
                        .items_center()
                        .gap_2()
                        .when(self.project_column_collapsed, |this| this.pl(px(12.0)))
                        .child(task_column_reveal_button)
                        .child(workspace_segmented_tabs(
                            active_index,
                            &self.state.settings.language,
                            has_project_context,
                            cx,
                        )),
                )
                .child(titlebar_drag_area(
                    "workspace-titlebar-drag",
                    div().flex_1().h_full().bg(theme::title_bar_fill()),
                ))
                .child(
                    div()
                        .flex()
                        .items_center()
                        .gap_2()
                        .child(workspace_open_button(
                            &self.project_open_applications,
                            has_project_context,
                            &self.state.settings.language,
                            cx,
                        ))
                        .when_some(connected_remote_project_device_id, |this, device_id| {
                            this.child(workspace_remote_browser_button(
                                device_id,
                                &self.state.settings.language,
                                cx,
                            ))
                        })
                        .child(workspace_toolbar_separator(cx))
                        .child(workspace_assistant_button(
                            "SSH",
                            AssistantPanel::Ssh,
                            self.assistant_panel,
                            has_project_context,
                            cx,
                        ))
                        .child(workspace_assistant_button(
                            "DB",
                            AssistantPanel::DB,
                            self.assistant_panel,
                            has_project_context,
                            cx,
                        ))
                        .child(workspace_assistant_button(
                            "Files",
                            AssistantPanel::FileManager,
                            self.assistant_panel,
                            has_project_context,
                            cx,
                        ))
                        .child(workspace_assistant_button(
                            "Git",
                            AssistantPanel::Git,
                            self.assistant_panel,
                            has_project_context,
                            cx,
                        ))
                        .child(workspace_assistant_button(
                            "CNB",
                            AssistantPanel::Cnb,
                            self.assistant_panel,
                            has_project_context,
                            cx,
                        ))
                        .when(!cfg!(target_os = "macos"), |this| {
                            this.child(
                                div()
                                    .flex_none()
                                    .w(px(WORKSPACE_WINDOW_CONTROLS_WIDTH))
                                    .h(px(28.0)),
                            )
                        }),
                ),
            cx,
        )
    }
}

fn task_column_expand_button(language: &str, cx: &mut Context<CoduxApp>) -> impl IntoElement {
    let label = workspace_i18n(language, "sidebar.expand", "Expand Sidebar");
    let button = workspace_header_button("task-column-expand", cx)
        .ghost()
        .w(px(28.0))
        .text_color(cx.theme().secondary_foreground)
        .on_click(cx.listener(|app, _event, window, cx| {
            app.toggle_task_column(window, cx);
        }))
        .child(Icon::new(HeroIconName::ChevronDoubleRight).size_3p5());

    with_codux_tooltip(cx.entity(), "task-column-expand-tooltip", button, label)
}

fn workspace_remote_browser_button(
    device_id: String,
    language: &str,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let app_entity = cx.entity();
    let tooltip_entity = app_entity.clone();
    let tooltip = workspace_i18n(
        language,
        "workspace.web_tunnel.browser.open",
        "Open Web Tunnel Browser",
    );

    let button = Button::new("workspace-open-remote-browser")
        .compact()
        .ghost()
        .h(px(28.0))
        .w(px(38.0))
        .cursor_pointer()
        .text_color(cx.theme().secondary_foreground)
        .on_click(move |_, _window, cx| {
            cx.update_entity(&app_entity, |app, cx| {
                app.open_remote_project_browser_session(device_id.clone(), cx);
            });
        })
        .child(Icon::new(HeroIconName::GlobeAlt).size_3p5());

    with_codux_tooltip(
        tooltip_entity,
        "workspace-open-remote-browser-tooltip",
        button,
        tooltip,
    )
}

fn workspace_open_button(
    applications: &[ProjectOpenApplicationSummary],
    has_project: bool,
    language: &str,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let applications = applications
        .iter()
        .filter(|application| application.installed)
        .cloned()
        .collect::<Vec<_>>();
    let app_entity = cx.entity();
    let reveal_entity = app_entity.clone();
    let language = language.to_string();

    div()
        .flex()
        .items_center()
        .rounded(px(6.0))
        .overflow_hidden()
        .bg(cx.theme().secondary)
        .child(
            div()
                .id("workspace-open-folder")
                .h(px(28.0))
                .w(px(26.0))
                .flex()
                .items_center()
                .justify_center()
                .cursor_pointer()
                .when(!has_project, |this| this.opacity(0.45))
                .hover(|style| style.bg(cx.theme().secondary_hover))
                .on_click(move |_, window, cx| {
                    if has_project {
                        cx.update_entity(&reveal_entity, |app, cx| {
                            app.reveal_selected_project_in_file_manager(window, cx);
                        });
                    }
                })
                .child(
                    Icon::new(HeroIconName::FolderOpen)
                        .size_3p5()
                        .text_color(cx.theme().foreground),
                ),
        )
        .child(div().w(px(1.0)).h(px(18.0)).bg(cx.theme().border))
        .child(
            Button::new("workspace-open-apps")
                .text()
                .h(px(28.0))
                .w(px(20.0))
                .cursor_pointer()
                .text_color(cx.theme().foreground)
                .child(
                    Icon::new(HeroIconName::ChevronDown)
                        .size_2()
                        .text_color(cx.theme().foreground),
                )
                .dropdown_menu(move |menu, _window, _cx| {
                    if applications.is_empty() {
                        let label = workspace_i18n(
                            &language,
                            "workspace.open.installed_apps_empty",
                            "No installed apps",
                        );
                        menu.item(
                            PopupMenuItem::new(label).icon(HeroIconName::ArrowTopRightOnSquare),
                        )
                    } else {
                        applications.iter().fold(menu, |menu, application| {
                            let app_entity = app_entity.clone();
                            let application_id = application.id.clone();
                            menu.item(
                                PopupMenuItem::new(application.label.clone())
                                    .icon(if application.category == "primary" {
                                        HeroIconName::ArrowTopRightOnSquare
                                    } else {
                                        HeroIconName::Document
                                    })
                                    .disabled(!has_project)
                                    .on_click(move |_, window, cx| {
                                        cx.update_entity(&app_entity, |app, cx| {
                                            app.open_selected_project_in_application(
                                                application_id.clone(),
                                                window,
                                                cx,
                                            );
                                        });
                                    }),
                            )
                        })
                    }
                }),
        )
}

fn workspace_window_controls(cx: &mut Context<CoduxApp>) -> impl IntoElement {
    div()
        .ml(px(WORKSPACE_WINDOW_CONTROL_LEADING_MARGIN))
        .flex()
        .items_center()
        .gap(px(WORKSPACE_WINDOW_CONTROL_GAP))
        .child(workspace_window_control_button(
            "workspace-window-minimize",
            HeroIconName::Minus,
            WindowControlArea::Min,
            cx,
        ))
        .child(workspace_window_control_button(
            "workspace-window-zoom",
            HeroIconName::Window,
            WindowControlArea::Max,
            cx,
        ))
        .child(window_close_control(
            "workspace-window-close",
            WORKSPACE_WINDOW_CONTROL_BUTTON_WIDTH,
            false,
            cx,
        ))
}

pub(in crate::app) fn workspace_window_controls_overlay(
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    // Keep native window-control hitboxes outside the cached workspace column.
    div()
        .absolute()
        .top(px(12.0))
        .right(px(10.0))
        .w(px(WORKSPACE_WINDOW_CONTROLS_WIDTH))
        .h(px(28.0))
        .child(workspace_window_controls(cx))
}

fn workspace_window_control_button(
    id: &'static str,
    icon: HeroIconName,
    area: WindowControlArea,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    Button::new(id)
        .compact()
        .ghost()
        .h(px(28.0))
        .w(px(WORKSPACE_WINDOW_CONTROL_BUTTON_WIDTH))
        .text_color(cx.theme().muted_foreground)
        .window_control_area(area)
        .child(Icon::new(icon).size_3())
}

fn workspace_assistant_button(
    label: &'static str,
    panel: AssistantPanel,
    active_panel: Option<AssistantPanel>,
    enabled: bool,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let active = enabled && active_panel == Some(panel);

    let button = workspace_header_button(
        match panel {
            AssistantPanel::AIStats => "workspace-assistant-ai",
            AssistantPanel::ServerInfo => "workspace-assistant-server",
            AssistantPanel::Ssh => "workspace-assistant-ssh",
            AssistantPanel::DB => "workspace-assistant-db",
            AssistantPanel::FileManager => "workspace-assistant-files",
            AssistantPanel::Git => "workspace-assistant-git",
            AssistantPanel::Cnb => "workspace-assistant-cnb",
        },
        cx,
    );
    let button = if active {
        button
            .ghost()
            .bg(cx.theme().accent)
            .text_color(cx.theme().primary)
    } else {
        button.ghost().text_color(cx.theme().secondary_foreground)
    };

    let button = button
        .disabled(!enabled)
        .when(!enabled, |this| this.opacity(0.45))
        .when(enabled, |this| {
            this.on_click(cx.listener(move |app, _event, window, cx| {
                app.toggle_assistant_panel(panel, window, cx)
            }))
        })
        .child(
            div()
                .h(px(20.0))
                .w(px(20.0))
                .flex()
                .items_center()
                .justify_center()
                .child(
                    Icon::new(match panel {
                        AssistantPanel::AIStats => HeroIconName::CpuChip,
                        AssistantPanel::ServerInfo => HeroIconName::ServerStack,
                        AssistantPanel::Ssh => HeroIconName::CommandLine,
                        AssistantPanel::DB => HeroIconName::CircleStack,
                        AssistantPanel::FileManager => HeroIconName::Folder,
                        AssistantPanel::Git => HeroIconName::Share,
                        AssistantPanel::Cnb => HeroIconName::QueueList,
                    })
                    .size_3p5()
                    .text_color(if active {
                        cx.theme().primary
                    } else {
                        cx.theme().secondary_foreground
                    }),
                ),
        );

    with_codux_tooltip(
        cx.entity(),
        match panel {
            AssistantPanel::AIStats => "workspace-assistant-ai-tooltip",
            AssistantPanel::ServerInfo => "workspace-assistant-server-tooltip",
            AssistantPanel::Ssh => "workspace-assistant-ssh-tooltip",
            AssistantPanel::DB => "workspace-assistant-db-tooltip",
            AssistantPanel::FileManager => "workspace-assistant-files-tooltip",
            AssistantPanel::Git => "workspace-assistant-git-tooltip",
            AssistantPanel::Cnb => "workspace-assistant-cnb-tooltip",
        },
        button,
        label,
    )
}
fn workspace_segmented_tabs(
    active_index: usize,
    language: &str,
    enabled: bool,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let app_entity = cx.entity();
    let locale = locale_from_language_setting(language);
    let terminal_label = translate(&locale, "workspace.create_split.terminal", "Terminal");
    let files_label = translate(&locale, "titlebar.files", "Files");
    let review_label = translate(&locale, "titlebar.review", "Review");
    let stats_label = translate(&locale, "titlebar.stats", "Stats");
    let tabs = [
        (HeroIconName::CommandLine, terminal_label),
        (HeroIconName::Document, files_label),
        (HeroIconName::ArrowPathRoundedSquare, review_label),
        (HeroIconName::ChartBar, stats_label),
    ];
    div()
        .flex()
        .items_center()
        .gap(px(2.0))
        .when(!enabled, |this| this.opacity(0.45))
        .children(tabs.into_iter().enumerate().map(|(index, (icon, label))| {
            let active = index == active_index;
            let click_entity = app_entity.clone();
            div()
                .id(SharedString::from(format!("workspace-view-tab-{index}")))
                .flex()
                .items_center()
                .gap(px(6.0))
                .h(px(24.0))
                .px(px(12.0))
                .rounded(px(6.0))
                .text_size(WORKSPACE_TAB_TEXT_SIZE)
                .line_height(WORKSPACE_TAB_LINE_HEIGHT)
                .map(|this| {
                    if active {
                        this.bg(cx.theme().primary)
                            .text_color(cx.theme().primary_foreground)
                    } else {
                        this.text_color(cx.theme().tab_foreground)
                            .hover(|style| style.bg(cx.theme().secondary_hover))
                    }
                })
                .when(enabled, |this| {
                    this.cursor_pointer().on_click(move |_, window, cx| {
                        cx.update_entity(&click_entity, |app, cx| {
                            if index == 3 {
                                app.show_stats_workspace_view(window, cx);
                            } else {
                                let view = match index {
                                    0 => WorkspaceView::Terminal,
                                    1 => WorkspaceView::Files,
                                    _ => WorkspaceView::Review,
                                };
                                app.set_workspace_view(view, window, cx);
                            }
                        });
                    })
                })
                .child(Icon::new(icon).size_3p5())
                .child(div().child(label))
        }))
}

fn workspace_toolbar_separator(cx: &mut Context<CoduxApp>) -> impl IntoElement {
    div()
        .w(px(1.0))
        .h(px(16.0))
        .flex_none()
        .bg(theme::divider_for_surface(cx.theme().title_bar))
}
