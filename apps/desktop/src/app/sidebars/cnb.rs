use super::*;
use crate::app::ui_helpers::{assistant_header_icon_button, header_icon_button_loading};
use codux_runtime::{
    cnb_browse::{CnbBrowseDetail, CnbBrowseItem, CnbBrowseKind, CnbBrowseRemote, is_live_build},
    i18n::translate,
    settings::locale_from_language_setting,
};
use std::time::{SystemTime, UNIX_EPOCH};

pub(in crate::app) fn cnb_section(
    input: CnbSectionInput<'_>,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let locale = locale_from_language_setting(input.language);
    let title = translate(&locale, "cnb.panel.title", "CNB");
    let labels = CnbPanelLabels::load(input.language);

    div()
        .flex()
        .flex_1()
        .h_full()
        .min_h_0()
        .flex_col()
        .relative()
        .child(assistant_panel_header(
            title,
            HeroIconName::QueueList,
            header_icon_button_loading(
                "cnb-refresh",
                HeroIconName::ArrowPath,
                input.loading,
                cx,
                |app, _event, _window, cx| app.refresh_cnb_panel_async(cx),
            ),
        ))
        .child(cnb_body(input, &labels, window, cx))
}

fn cnb_body(
    input: CnbSectionInput<'_>,
    labels: &CnbPanelLabels,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    if !input.selected_project {
        return cnb_empty_state(&labels.empty_no_project, None, cx).into_any_element();
    }

    let Some(remote) = input.remote else {
        return cnb_empty_state(
            &labels.empty_no_remote_title,
            Some(&labels.empty_no_remote_help),
            cx,
        )
        .into_any_element();
    };

    if !remote.token_configured {
        return cnb_empty_state(
            &labels.empty_no_token_title,
            Some(&labels.empty_no_token_help),
            cx,
        )
        .child(
            Button::new("cnb-open-settings")
                .compact()
                .primary()
                .mt(px(12.0))
                .on_click(cx.listener(|app, _event, _window, cx| {
                    app.open_cnb_token_settings(cx);
                }))
                .child(labels.configure.clone()),
        )
        .into_any_element();
    }

    if let Some(detail) = input.detail {
        return cnb_detail_view(
            detail,
            input.kind,
            input.detail_loading,
            input.action_busy,
            input.comment_draft,
            input.comment_revision,
            labels,
            window,
            cx,
        )
        .into_any_element();
    }

    let kind = input.kind;
    let state_filter = input.state_filter.to_string();
    let items = input.items.to_vec();
    let error = input.error.map(str::to_string);
    let loading = input.loading;
    let action_busy = input.action_busy;

    div()
        .flex()
        .flex_1()
        .min_h_0()
        .flex_col()
        .child(cnb_repo_row(remote, cx))
        .child(cnb_kind_row(kind, labels, cx))
        .when(kind != CnbBrowseKind::Builds, |this| {
            this.child(cnb_filter_row(&state_filter, labels, cx))
        })
        .children(error.map(|error| {
            div()
                .mx(px(12.0))
                .mb(px(8.0))
                .p(px(10.0))
                .rounded(px(8.0))
                .bg(ai_stats_surface(cx))
                .text_size(rems(0.75))
                .line_height(rems(1.0))
                .text_color(color(theme::ACCENT))
                .child(error)
        }))
        .child(
            div()
                .flex_1()
                .min_h_0()
                .px(px(12.0))
                .pb(px(12.0))
                .overflow_y_scrollbar()
                .child(if items.is_empty() && !loading {
                    cnb_empty_state(&labels.empty_no_items, None, cx).into_any_element()
                } else {
                    div()
                        .flex()
                        .flex_col()
                        .children(items.into_iter().map(|item| {
                            cnb_item_row(item, kind, action_busy, labels, cx).into_any_element()
                        }))
                        .into_any_element()
                }),
        )
        .into_any_element()
}

fn cnb_repo_row(remote: &CnbBrowseRemote, cx: &mut Context<CoduxApp>) -> impl IntoElement {
    let web = format!("{}/{}", remote.web, remote.repo);
    div()
        .px(px(12.0))
        .pt(px(10.0))
        .pb(px(6.0))
        .flex()
        .items_center()
        .justify_between()
        .gap(px(8.0))
        .child(
            div()
                .min_w_0()
                .flex()
                .flex_col()
                .gap(px(2.0))
                .child(
                    div()
                        .text_size(rems(0.6875))
                        .text_color(color(theme::TEXT_MUTED))
                        .child(remote.site_label.clone()),
                )
                .child(
                    div()
                        .text_size(rems(0.8125))
                        .font_weight(FontWeight::MEDIUM)
                        .text_color(color(theme::TEXT))
                        .truncate()
                        .child(remote.repo.clone()),
                ),
        )
        .child(assistant_header_icon_button(
            "cnb-open-repo",
            HeroIconName::ArrowTopRightOnSquare,
            cx,
            move |app, _event, _window, _cx| {
                app.open_cnb_url(&web);
            },
        ))
}

fn cnb_kind_row(
    kind: CnbBrowseKind,
    labels: &CnbPanelLabels,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    div()
        .px(px(12.0))
        .pt(px(4.0))
        .flex()
        .items_center()
        .gap(px(6.0))
        .child(cnb_chip(
            "cnb-kind-issues",
            &labels.kind_issues,
            kind == CnbBrowseKind::Issues,
            cx,
            |app, _event, _window, cx| app.set_cnb_kind(CnbBrowseKind::Issues, cx),
        ))
        .child(cnb_chip(
            "cnb-kind-prs",
            &labels.kind_prs,
            kind == CnbBrowseKind::Pulls,
            cx,
            |app, _event, _window, cx| app.set_cnb_kind(CnbBrowseKind::Pulls, cx),
        ))
        .child(cnb_chip(
            "cnb-kind-builds",
            &labels.kind_builds,
            kind == CnbBrowseKind::Builds,
            cx,
            |app, _event, _window, cx| app.set_cnb_kind(CnbBrowseKind::Builds, cx),
        ))
}

fn cnb_filter_row(
    state_filter: &str,
    labels: &CnbPanelLabels,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    div()
        .px(px(12.0))
        .pt(px(6.0))
        .pb(px(8.0))
        .flex()
        .items_center()
        .gap(px(6.0))
        .child(cnb_chip(
            "cnb-filter-open",
            &labels.filter_open,
            state_filter == "open",
            cx,
            |app, _event, _window, cx| app.set_cnb_state_filter("open", cx),
        ))
        .child(cnb_chip(
            "cnb-filter-closed",
            &labels.filter_closed,
            state_filter == "closed",
            cx,
            |app, _event, _window, cx| app.set_cnb_state_filter("closed", cx),
        ))
        .child(cnb_chip(
            "cnb-filter-all",
            &labels.filter_all,
            state_filter == "all",
            cx,
            |app, _event, _window, cx| app.set_cnb_state_filter("all", cx),
        ))
}

fn cnb_chip(
    id: &'static str,
    label: &str,
    active: bool,
    cx: &mut Context<CoduxApp>,
    on_click: impl Fn(&mut CoduxApp, &gpui::ClickEvent, &mut Window, &mut Context<CoduxApp>) + 'static,
) -> impl IntoElement {
    let label = label.to_string();
    Button::new(id)
        .compact()
        .when(active, |this| {
            this.bg(cx.theme().accent).text_color(cx.theme().primary)
        })
        .when(!active, |this| {
            this.ghost().text_color(cx.theme().secondary_foreground)
        })
        .on_click(cx.listener(on_click))
        .child(label)
}

fn cnb_item_row(
    item: CnbBrowseItem,
    kind: CnbBrowseKind,
    action_busy: bool,
    labels: &CnbPanelLabels,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let item_id = item.id.clone();
    let stop_id = item.id.clone();
    let hover_surface = ai_stats_track_surface(cx);
    let state_label = cnb_state_label(&item.state, kind, labels);
    let show_stop = kind == CnbBrowseKind::Builds && is_live_build(&item.state);
    let stop_label = labels.stop.clone();
    let meta = [
        format_item_id(kind, &item.id),
        item.author.clone(),
        relative_time(&item.updated_at),
        item.extra.clone(),
    ]
    .into_iter()
    .filter(|part| !part.is_empty())
    .collect::<Vec<_>>()
    .join(" · ");

    div()
        .id(SharedString::from(format!("cnb-item-{}", item.id)))
        .w_full()
        .min_w_0()
        .mb(px(8.0))
        .p(px(10.0))
        .rounded(px(8.0))
        .bg(ai_stats_surface(cx))
        .cursor_pointer()
        .hover(move |style| style.bg(hover_surface))
        .on_click(cx.listener(move |app, _event, _window, cx| {
            app.open_cnb_item(item_id.clone(), cx);
        }))
        .child(
            div()
                .flex()
                .items_start()
                .justify_between()
                .gap(px(8.0))
                .child(
                    div()
                        .min_w_0()
                        .flex_1()
                        .text_size(rems(0.8125))
                        .line_height(rems(1.125))
                        .font_weight(FontWeight::MEDIUM)
                        .text_color(color(theme::TEXT))
                        .child(item.title.clone()),
                )
                .child(
                    div()
                        .flex()
                        .items_center()
                        .gap(px(6.0))
                        .child(cnb_state_pill(&item.state, &state_label, cx))
                        .when(show_stop, |this| {
                            this.child(
                                Button::new(SharedString::from(format!("cnb-stop-{}", stop_id)))
                                    .compact()
                                    .ghost()
                                    .disabled(action_busy)
                                    .text_color(cx.theme().secondary_foreground)
                                    .on_click(cx.listener(move |app, _event, _window, cx| {
                                        cx.stop_propagation();
                                        app.stop_cnb_build(stop_id.clone(), cx);
                                    }))
                                    .child(stop_label.clone()),
                            )
                        }),
                ),
        )
        .child(
            div()
                .mt(px(6.0))
                .text_size(rems(0.6875))
                .line_height(rems(0.9375))
                .text_color(color(theme::TEXT_MUTED))
                .truncate()
                .child(meta),
        )
}

fn cnb_detail_view(
    detail: &CnbBrowseDetail,
    kind: CnbBrowseKind,
    loading: bool,
    action_busy: bool,
    comment_draft: &str,
    comment_revision: u64,
    labels: &CnbPanelLabels,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let web_url = detail.item.web_url.clone();
    let state_label = cnb_state_label(&detail.item.state, kind, labels);
    let close_action = cnb_close_action(&detail.item.state, kind);
    let show_stop = kind == CnbBrowseKind::Builds && is_live_build(&detail.item.state);
    let show_comments = kind != CnbBrowseKind::Builds;
    let meta = [
        format_item_id(kind, &detail.item.id),
        detail.item.author.clone(),
        relative_time(&detail.item.updated_at),
        detail.item.extra.clone(),
    ]
    .into_iter()
    .filter(|part| !part.is_empty())
    .collect::<Vec<_>>()
    .join(" · ");
    let body = if detail.body.trim().is_empty() {
        labels.no_body.clone()
    } else {
        detail.body.clone()
    };
    let action_label = match close_action {
        Some(true) => labels.close.clone(),
        Some(false) => labels.reopen.clone(),
        None => String::new(),
    };

    div()
        .flex()
        .flex_1()
        .min_h_0()
        .flex_col()
        .child(
            div()
                .h(px(40.0))
                .px(px(8.0))
                .flex()
                .items_center()
                .justify_between()
                .border_b_1()
                .border_color(color(theme::BORDER_SOFT).opacity(0.5))
                .child(
                    div()
                        .flex()
                        .items_center()
                        .gap(px(4.0))
                        .child(
                            Button::new("cnb-back")
                                .compact()
                                .ghost()
                                .text_color(cx.theme().secondary_foreground)
                                .on_click(cx.listener(|app, _event, _window, cx| {
                                    app.close_cnb_detail(cx);
                                }))
                                .child(labels.back.clone()),
                        )
                        .when_some(close_action, |this, close| {
                            this.child(
                                Button::new("cnb-toggle-state")
                                    .compact()
                                    .ghost()
                                    .disabled(action_busy)
                                    .text_color(cx.theme().secondary_foreground)
                                    .on_click(cx.listener(move |app, _event, _window, cx| {
                                        app.set_cnb_item_closed(close, cx);
                                    }))
                                    .child(action_label.clone()),
                            )
                        })
                        .when(show_stop, |this| {
                            let stop_id = detail.item.id.clone();
                            this.child(
                                Button::new("cnb-stop-detail")
                                    .compact()
                                    .ghost()
                                    .disabled(action_busy)
                                    .text_color(cx.theme().secondary_foreground)
                                    .on_click(cx.listener(move |app, _event, _window, cx| {
                                        app.stop_cnb_build(stop_id.clone(), cx);
                                    }))
                                    .child(labels.stop.clone()),
                            )
                        })
                        .when(action_busy, |this| {
                            this.child(
                                div()
                                    .text_size(rems(0.6875))
                                    .text_color(color(theme::TEXT_MUTED))
                                    .child(labels.busy.clone()),
                            )
                        }),
                )
                .child(assistant_header_icon_button(
                    "cnb-open-item",
                    HeroIconName::ArrowTopRightOnSquare,
                    cx,
                    move |app, _event, _window, _cx| {
                        app.open_cnb_url(&web_url);
                    },
                )),
        )
        .child(
            div()
                .flex_1()
                .min_h_0()
                .p(px(12.0))
                .overflow_y_scrollbar()
                .child(
                    div()
                        .flex()
                        .flex_col()
                        .gap(px(10.0))
                        .child(
                            div()
                                .flex()
                                .items_start()
                                .justify_between()
                                .gap(px(8.0))
                                .child(
                                    div()
                                        .min_w_0()
                                        .flex_1()
                                        .text_size(rems(0.9375))
                                        .line_height(rems(1.25))
                                        .font_weight(FontWeight::SEMIBOLD)
                                        .text_color(color(theme::TEXT))
                                        .child(detail.item.title.clone()),
                                )
                                .child(cnb_state_pill(&detail.item.state, &state_label, cx)),
                        )
                        .child(
                            div()
                                .text_size(rems(0.75))
                                .text_color(color(theme::TEXT_MUTED))
                                .child(meta),
                        )
                        .child(
                            div()
                                .p(px(10.0))
                                .rounded(px(8.0))
                                .bg(ai_stats_surface(cx))
                                .text_size(rems(0.8125))
                                .line_height(rems(1.125))
                                .text_color(color(theme::TEXT))
                                .child(body),
                        )
                        .when(show_comments, |this| {
                            this.child(
                                div()
                                    .mt(px(4.0))
                                    .text_size(rems(0.75))
                                    .font_weight(FontWeight::SEMIBOLD)
                                    .text_color(color(theme::TEXT))
                                    .child(labels.comments.clone()),
                            )
                            .child(if loading {
                                div()
                                    .text_size(rems(0.75))
                                    .text_color(color(theme::TEXT_MUTED))
                                    .child(labels.loading.clone())
                                    .into_any_element()
                            } else if detail.comments.is_empty() {
                                div()
                                    .text_size(rems(0.75))
                                    .text_color(color(theme::TEXT_MUTED))
                                    .child(labels.no_comments.clone())
                                    .into_any_element()
                            } else {
                                div()
                                    .flex()
                                    .flex_col()
                                    .gap(px(8.0))
                                    .children(detail.comments.iter().map(|comment| {
                                        div()
                                            .p(px(10.0))
                                            .rounded(px(8.0))
                                            .bg(ai_stats_surface(cx))
                                            .child(
                                                div()
                                                    .text_size(rems(0.6875))
                                                    .text_color(color(theme::TEXT_MUTED))
                                                    .child(format!(
                                                        "{} · {}",
                                                        comment.author,
                                                        relative_time(&comment.created_at)
                                                    )),
                                            )
                                            .child(
                                                div()
                                                    .mt(px(4.0))
                                                    .text_size(rems(0.8125))
                                                    .line_height(rems(1.125))
                                                    .text_color(color(theme::TEXT))
                                                    .child(comment.body.clone()),
                                            )
                                    }))
                                    .into_any_element()
                            })
                        }),
                ),
        )
        .when(show_comments, |this| {
            this.child(cnb_comment_composer(
                comment_draft,
                comment_revision,
                action_busy,
                labels,
                window,
                cx,
            ))
        })
}

fn cnb_comment_composer(
    comment_draft: &str,
    comment_revision: u64,
    action_busy: bool,
    labels: &CnbPanelLabels,
    window: &mut Window,
    cx: &mut Context<CoduxApp>,
) -> impl IntoElement {
    let value = comment_draft.to_string();
    let placeholder = labels.comment_placeholder.clone();
    let input_state = window.use_keyed_state(
        SharedString::from(format!("cnb-comment-{comment_revision}")),
        cx,
        |window, cx| {
            InputState::new(window, cx)
                .multi_line(true)
                .rows(2)
                .default_value(value.clone())
                .placeholder(placeholder)
        },
    );
    cx.subscribe_in(
        &input_state,
        window,
        |app, state, event, _window, cx| match event {
            InputEvent::Change => {
                app.set_cnb_comment_draft(state.read(cx).value().to_string());
            }
            InputEvent::PressEnter { shift, .. } if !*shift => {
                app.submit_cnb_comment(cx);
            }
            _ => {}
        },
    )
    .detach();

    div()
        .flex_shrink_0()
        .p(px(12.0))
        .border_t_1()
        .border_color(color(theme::BORDER_SOFT).opacity(0.5))
        .child(
            Input::new(&input_state)
                .with_size(gpui_component::Size::Medium)
                .h(px(64.0)),
        )
        .child(
            Button::new("cnb-submit-comment")
                .compact()
                .primary()
                .mt(px(8.0))
                .disabled(action_busy)
                .on_click(cx.listener(|app, _event, _window, cx| {
                    app.submit_cnb_comment(cx);
                }))
                .child(labels.comment.clone()),
        )
}

fn cnb_close_action(state: &str, kind: CnbBrowseKind) -> Option<bool> {
    match kind {
        CnbBrowseKind::Builds => None,
        _ if state == "merged" => None,
        _ if state == "closed" => Some(false),
        _ => Some(true),
    }
}

fn cnb_empty_state(title: &str, help: Option<&str>, cx: &mut Context<CoduxApp>) -> gpui::Div {
    div()
        .size_full()
        .flex()
        .flex_col()
        .items_center()
        .justify_center()
        .text_center()
        .px(px(20.0))
        .gap(px(8.0))
        .child(
            div()
                .size(px(44.0))
                .rounded(px(12.0))
                .flex()
                .items_center()
                .justify_center()
                .bg(ai_stats_surface(cx))
                .child(
                    Icon::new(HeroIconName::QueueList)
                        .size_5()
                        .text_color(color(theme::TEXT_MUTED)),
                ),
        )
        .child(
            div()
                .text_size(rems(0.8125))
                .line_height(rems(1.125))
                .text_color(color(theme::TEXT))
                .child(title.to_string()),
        )
        .children(help.map(|help| {
            div()
                .text_size(rems(0.75))
                .line_height(rems(1.0))
                .text_color(color(theme::TEXT_MUTED))
                .child(help.to_string())
        }))
}

fn cnb_state_pill(state: &str, label: &str, cx: &mut Context<CoduxApp>) -> impl IntoElement {
    let tone = match state {
        "open" | "success" | "merged" => color(theme::GREEN),
        "closed" | "failed" | "error" | "cancelled" | "cancel" => color(theme::ACCENT),
        _ => color(theme::TEXT_MUTED),
    };
    let _ = cx;
    div()
        .flex_none()
        .px(px(6.0))
        .py(px(2.0))
        .rounded(px(999.0))
        .text_size(rems(0.625))
        .line_height(rems(0.875))
        .text_color(tone)
        .child(label.to_string())
}

fn cnb_state_label(state: &str, kind: CnbBrowseKind, labels: &CnbPanelLabels) -> String {
    match (kind, state) {
        (_, "merged") => labels.state_merged.clone(),
        (_, "draft") => labels.state_draft.clone(),
        (_, "success") => labels.state_success.clone(),
        (_, "failed" | "error") => labels.state_failed.clone(),
        (_, "cancelled" | "cancel") => labels.state_cancelled.clone(),
        (_, "running") => labels.state_running.clone(),
        (_, "pending" | "waiting") => labels.state_pending.clone(),
        (_, "closed") => labels.state_closed.clone(),
        (_, "open") => labels.state_open.clone(),
        _ if state.is_empty() => labels.state_open.clone(),
        _ => {
            let mut chars = state.chars();
            match chars.next() {
                Some(first) => format!("{}{}", first.to_uppercase(), chars.as_str()),
                None => labels.state_pending.clone(),
            }
        }
    }
}

fn format_item_id(kind: CnbBrowseKind, id: &str) -> String {
    match kind {
        CnbBrowseKind::Builds => id.to_string(),
        _ => format!("#{id}"),
    }
}

fn relative_time(value: &str) -> String {
    let Some(then) = parse_unix_seconds(value) else {
        return String::new();
    };
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(then);
    let delta = (now - then).max(0);
    if delta < 60 {
        return format!("{delta}s");
    }
    if delta < 3600 {
        return format!("{}m", delta / 60);
    }
    if delta < 86400 {
        return format!("{}h", delta / 3600);
    }
    if delta < 2_592_000 {
        return format!("{}d", delta / 86400);
    }
    format!("{}mo", delta / 2_592_000)
}

fn parse_unix_seconds(value: &str) -> Option<i64> {
    let value = value.trim();
    if value.is_empty() {
        return None;
    }
    if let Ok(seconds) = value.parse::<i64>() {
        return Some(if seconds > 10_000_000_000 {
            seconds / 1000
        } else {
            seconds
        });
    }
    let normalized = value.trim_end_matches('Z').replace('T', " ");
    let date = normalized.get(0..10)?;
    let time = normalized.get(11..19).unwrap_or("00:00:00");
    let mut parts = date.split('-');
    let year = parts.next()?.parse::<i64>().ok()?;
    let month = parts.next()?.parse::<i64>().ok()?;
    let day = parts.next()?.parse::<i64>().ok()?;
    let mut time_parts = time.split(':');
    let hour = time_parts.next()?.parse::<i64>().ok()?;
    let minute = time_parts.next()?.parse::<i64>().ok()?;
    let second = time_parts.next()?.parse::<i64>().ok()?;
    Some(days_from_civil(year, month, day) * 86400 + hour * 3600 + minute * 60 + second)
}

fn days_from_civil(year: i64, month: i64, day: i64) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = if year >= 0 { year } else { year - 399 } / 400;
    let yoe = year - era * 400;
    let month_adj = if month > 2 { month - 3 } else { month + 9 };
    let doy = (153 * month_adj + 2) / 5 + day - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

pub(in crate::app) struct CnbSectionInput<'a> {
    pub language: &'a str,
    pub selected_project: bool,
    pub remote: Option<&'a CnbBrowseRemote>,
    pub kind: CnbBrowseKind,
    pub state_filter: &'a str,
    pub items: &'a [CnbBrowseItem],
    pub detail: Option<&'a CnbBrowseDetail>,
    pub loading: bool,
    pub detail_loading: bool,
    pub action_busy: bool,
    pub comment_draft: &'a str,
    pub comment_revision: u64,
    pub error: Option<&'a str>,
}

struct CnbPanelLabels {
    kind_issues: String,
    kind_prs: String,
    kind_builds: String,
    filter_open: String,
    filter_closed: String,
    filter_all: String,
    empty_no_project: String,
    empty_no_remote_title: String,
    empty_no_remote_help: String,
    empty_no_token_title: String,
    empty_no_token_help: String,
    empty_no_items: String,
    configure: String,
    back: String,
    comments: String,
    comment: String,
    comment_placeholder: String,
    close: String,
    reopen: String,
    stop: String,
    busy: String,
    no_body: String,
    no_comments: String,
    loading: String,
    state_open: String,
    state_closed: String,
    state_merged: String,
    state_draft: String,
    state_success: String,
    state_failed: String,
    state_cancelled: String,
    state_running: String,
    state_pending: String,
}

impl CnbPanelLabels {
    fn load(language: &str) -> Self {
        let locale = locale_from_language_setting(language);
        Self {
            kind_issues: translate(&locale, "cnb.kind.issues", "Issues"),
            kind_prs: translate(&locale, "cnb.kind.prs", "PRs"),
            kind_builds: translate(&locale, "cnb.kind.builds", "Builds"),
            filter_open: translate(&locale, "cnb.filter.open", "Open"),
            filter_closed: translate(&locale, "cnb.filter.closed", "Closed"),
            filter_all: translate(&locale, "cnb.filter.all", "All"),
            empty_no_project: translate(&locale, "cnb.empty.no_project", "Select a project first"),
            empty_no_remote_title: translate(
                &locale,
                "cnb.empty.no_remote.title",
                "Not a CNB repository",
            ),
            empty_no_remote_help: translate(
                &locale,
                "cnb.empty.no_remote.help",
                "This project's git remotes are not on cnb.cool or cnb.woa.com.",
            ),
            empty_no_token_title: translate(&locale, "cnb.empty.no_token.title", "Add a CNB token"),
            empty_no_token_help: translate(
                &locale,
                "cnb.empty.no_token.help",
                "Save a personal access token in Settings → Git to browse issues, pull requests, and builds.",
            ),
            empty_no_items: translate(&locale, "cnb.empty.no_items", "No items"),
            configure: translate(&locale, "cnb.panel.configure", "Add Token"),
            back: translate(&locale, "cnb.panel.back", "Back"),
            comments: translate(&locale, "cnb.detail.comments", "Comments"),
            comment: translate(&locale, "cnb.action.comment", "Comment"),
            comment_placeholder: translate(
                &locale,
                "cnb.action.comment_placeholder",
                "Write a comment…",
            ),
            close: translate(&locale, "cnb.action.close", "Close"),
            reopen: translate(&locale, "cnb.action.reopen", "Reopen"),
            stop: translate(&locale, "cnb.action.stop", "Stop"),
            busy: translate(&locale, "cnb.action.busy", "Working…"),
            no_body: translate(&locale, "cnb.detail.no_body", "No description"),
            no_comments: translate(&locale, "cnb.detail.no_comments", "No comments"),
            loading: translate(&locale, "cnb.status.loading", "Loading CNB…"),
            state_open: translate(&locale, "cnb.state.open", "Open"),
            state_closed: translate(&locale, "cnb.state.closed", "Closed"),
            state_merged: translate(&locale, "cnb.state.merged", "Merged"),
            state_draft: translate(&locale, "cnb.state.draft", "Draft"),
            state_success: translate(&locale, "cnb.state.success", "Success"),
            state_failed: translate(&locale, "cnb.state.failed", "Failed"),
            state_cancelled: translate(&locale, "cnb.state.cancelled", "Cancelled"),
            state_running: translate(&locale, "cnb.state.running", "Running"),
            state_pending: translate(&locale, "cnb.state.pending", "Pending"),
        }
    }
}
