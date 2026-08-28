use super::*;
use codux_runtime::cnb_browse::{CnbBrowseDetail, CnbBrowseKind, CnbBrowseRemote};

impl CoduxApp {
    pub(in crate::app) fn reset_cnb_panel_state(&mut self) {
        self.cnb_remote = None;
        self.cnb_items.clear();
        self.cnb_detail = None;
        self.cnb_selected_id = None;
        self.cnb_error = None;
        self.cnb_loading = false;
        self.cnb_detail_loading = false;
        self.cnb_action_busy = false;
        self.cnb_comment_draft.clear();
        self.cnb_comment_revision = self.cnb_comment_revision.saturating_add(1);
        self.cnb_list_generation = self.cnb_list_generation.saturating_add(1);
    }

    pub(in crate::app) fn set_cnb_comment_draft(&mut self, value: String) {
        if self.cnb_comment_draft == value {
            return;
        }
        self.cnb_comment_draft = value;
    }

    pub(in crate::app) fn set_cnb_kind(&mut self, kind: CnbBrowseKind, cx: &mut Context<Self>) {
        if self.cnb_kind == kind {
            return;
        }
        self.cnb_kind = kind;
        self.cnb_detail = None;
        self.cnb_selected_id = None;
        self.cnb_comment_draft.clear();
        self.cnb_comment_revision = self.cnb_comment_revision.saturating_add(1);
        self.refresh_cnb_panel_async(cx);
    }

    pub(in crate::app) fn set_cnb_state_filter(&mut self, filter: &str, cx: &mut Context<Self>) {
        if self.cnb_state_filter == filter {
            return;
        }
        self.cnb_state_filter = filter.to_string();
        self.cnb_detail = None;
        self.cnb_selected_id = None;
        self.cnb_comment_draft.clear();
        self.cnb_comment_revision = self.cnb_comment_revision.saturating_add(1);
        self.refresh_cnb_panel_async(cx);
    }

    pub(in crate::app) fn close_cnb_detail(&mut self, cx: &mut Context<Self>) {
        self.cnb_detail = None;
        self.cnb_selected_id = None;
        self.cnb_detail_loading = false;
        self.cnb_comment_draft.clear();
        self.cnb_comment_revision = self.cnb_comment_revision.saturating_add(1);
        self.invalidate_cnb_panel(cx);
    }

    pub(in crate::app) fn open_cnb_token_settings(&mut self, cx: &mut Context<Self>) {
        self.open_settings_window_with_pane(SettingsPane::Git, cx);
    }

    pub(in crate::app) fn open_cnb_url(&mut self, url: &str) {
        if url.is_empty() {
            return;
        }
        match self.runtime_service.open_url(url) {
            Ok(()) => self.status_message = format!("opened {url}"),
            Err(error) => self.status_message = format!("failed to open {url}: {error}"),
        }
    }

    pub(in crate::app) fn refresh_cnb_panel_async(&mut self, cx: &mut Context<Self>) {
        let Some(project_path) = self.selected_worktree_path() else {
            self.reset_cnb_panel_state();
            self.invalidate_cnb_panel(cx);
            return;
        };
        let Some(scope_key) = current_worktree_scope_key(&self.state) else {
            self.reset_cnb_panel_state();
            self.invalidate_cnb_panel(cx);
            return;
        };
        let generation = self.project_switch_generation;
        self.cnb_list_generation = self.cnb_list_generation.saturating_add(1);
        let list_generation = self.cnb_list_generation;
        let kind = self.cnb_kind;
        let state_filter = self.cnb_state_filter.clone();
        let runtime_service = self.runtime_service.clone();
        self.cnb_loading = true;
        self.cnb_error = None;
        self.invalidate_cnb_panel(cx);
        cx.spawn(async move |this: gpui::WeakEntity<Self>, cx| {
            let result = codux_runtime::async_runtime::run_limited_blocking_with_priority(
                codux_runtime::async_runtime::BLOCKING_PRIORITY_FOREGROUND + generation,
                move || runtime_service.cnb_list(&project_path, kind, &state_filter),
            )
            .await;
            let _ = this.update(cx, |app, cx| {
                if app.project_switch_generation != generation
                    || app.cnb_list_generation != list_generation
                    || current_worktree_scope_key(&app.state).as_ref() != Some(&scope_key)
                {
                    return;
                }
                app.cnb_loading = false;
                match result {
                    Ok(Ok(list)) => {
                        app.cnb_remote = list.remote;
                        app.cnb_items = list.items;
                        app.cnb_error = None;
                        app.status_message = format!("CNB loaded {} items", app.cnb_items.len());
                    }
                    Ok(Err(error)) => {
                        app.cnb_error = Some(error.clone());
                        app.status_message = format!("CNB error: {error}");
                    }
                    Err(error) => {
                        app.cnb_error = Some(error.to_string());
                        app.status_message = format!("CNB error: {error}");
                    }
                }
                app.invalidate_cnb_panel(cx);
                app.invalidate_status_bar(cx);
            });
        })
        .detach();
    }

    pub(in crate::app) fn open_cnb_item(&mut self, id: String, cx: &mut Context<Self>) {
        let Some(project_path) = self.selected_worktree_path() else {
            return;
        };
        let Some(remote) = self.cnb_remote.clone() else {
            return;
        };
        let Some(scope_key) = current_worktree_scope_key(&self.state) else {
            return;
        };
        let generation = self.project_switch_generation;
        let list_generation = self.cnb_list_generation;
        let kind = self.cnb_kind;
        let runtime_service = self.runtime_service.clone();
        self.cnb_selected_id = Some(id.clone());
        self.cnb_comment_draft.clear();
        self.cnb_comment_revision = self.cnb_comment_revision.saturating_add(1);
        self.cnb_detail_loading = true;
        if let Some(item) = self.cnb_items.iter().find(|item| item.id == id).cloned() {
            self.cnb_detail = Some(CnbBrowseDetail {
                item,
                body: String::new(),
                comments: Vec::new(),
            });
        }
        self.invalidate_cnb_panel(cx);
        cx.spawn(async move |this: gpui::WeakEntity<Self>, cx| {
            let result = codux_runtime::async_runtime::run_limited_blocking_with_priority(
                codux_runtime::async_runtime::BLOCKING_PRIORITY_FOREGROUND + generation,
                move || runtime_service.cnb_detail(&project_path, kind, &id, &remote),
            )
            .await;
            let _ = this.update(cx, |app, cx| {
                if app.project_switch_generation != generation
                    || app.cnb_list_generation != list_generation
                    || current_worktree_scope_key(&app.state).as_ref() != Some(&scope_key)
                {
                    return;
                }
                app.cnb_detail_loading = false;
                match result {
                    Ok(Ok(detail)) => {
                        app.cnb_detail = Some(detail);
                        app.cnb_error = None;
                    }
                    Ok(Err(error)) => {
                        app.cnb_error = Some(error.clone());
                        app.status_message = format!("CNB error: {error}");
                    }
                    Err(error) => {
                        app.cnb_error = Some(error.to_string());
                        app.status_message = format!("CNB error: {error}");
                    }
                }
                app.invalidate_cnb_panel(cx);
            });
        })
        .detach();
    }

    pub(in crate::app) fn submit_cnb_comment(&mut self, cx: &mut Context<Self>) {
        let body = self.cnb_comment_draft.trim().to_string();
        if body.is_empty() {
            return;
        }
        let Some(id) = self.cnb_selected_id.clone() else {
            return;
        };
        let kind = self.cnb_kind;
        self.run_cnb_detail_action(cx, false, move |service, project_path, remote| {
            service.cnb_comment(&project_path, kind, &id, &remote, &body)
        });
        self.cnb_comment_draft.clear();
        self.cnb_comment_revision = self.cnb_comment_revision.saturating_add(1);
    }

    pub(in crate::app) fn set_cnb_item_closed(&mut self, close: bool, cx: &mut Context<Self>) {
        let Some(id) = self.cnb_selected_id.clone() else {
            return;
        };
        let kind = self.cnb_kind;
        self.run_cnb_detail_action(cx, true, move |service, project_path, remote| {
            service.cnb_set_item_state(&project_path, kind, &id, &remote, close)
        });
    }

    pub(in crate::app) fn stop_cnb_build(&mut self, id: String, cx: &mut Context<Self>) {
        self.run_cnb_detail_action(cx, true, move |service, project_path, remote| {
            service.cnb_stop_build(&project_path, &id, &remote)
        });
    }

    fn run_cnb_detail_action(
        &mut self,
        cx: &mut Context<Self>,
        refresh_list: bool,
        action: impl FnOnce(RuntimeService, String, CnbBrowseRemote) -> Result<CnbBrowseDetail, String>
        + Send
        + 'static,
    ) {
        if self.cnb_action_busy {
            return;
        }
        let Some(project_path) = self.selected_worktree_path() else {
            return;
        };
        let Some(remote) = self.cnb_remote.clone() else {
            return;
        };
        let Some(scope_key) = current_worktree_scope_key(&self.state) else {
            return;
        };
        let generation = self.project_switch_generation;
        let list_generation = self.cnb_list_generation;
        let runtime_service = self.runtime_service.clone();
        self.cnb_action_busy = true;
        self.cnb_error = None;
        self.invalidate_cnb_panel(cx);
        cx.spawn(async move |this: gpui::WeakEntity<Self>, cx| {
            let result = codux_runtime::async_runtime::run_limited_blocking_with_priority(
                codux_runtime::async_runtime::BLOCKING_PRIORITY_FOREGROUND + generation,
                move || action(runtime_service, project_path, remote),
            )
            .await;
            let _ = this.update(cx, |app, cx| {
                if app.project_switch_generation != generation
                    || app.cnb_list_generation != list_generation
                    || current_worktree_scope_key(&app.state).as_ref() != Some(&scope_key)
                {
                    return;
                }
                app.cnb_action_busy = false;
                match result {
                    Ok(Ok(detail)) => {
                        app.cnb_detail = Some(detail.clone());
                        app.cnb_selected_id = Some(detail.item.id.clone());
                        if let Some(item) = app
                            .cnb_items
                            .iter_mut()
                            .find(|item| item.id == detail.item.id)
                        {
                            *item = detail.item;
                        }
                        app.cnb_error = None;
                        app.status_message = "CNB updated".to_string();
                        if refresh_list {
                            app.refresh_cnb_panel_async(cx);
                            return;
                        }
                    }
                    Ok(Err(error)) => {
                        app.cnb_error = Some(error.clone());
                        app.status_message = format!("CNB error: {error}");
                    }
                    Err(error) => {
                        app.cnb_error = Some(error.to_string());
                        app.status_message = format!("CNB error: {error}");
                    }
                }
                app.invalidate_cnb_panel(cx);
                app.invalidate_status_bar(cx);
            });
        })
        .detach();
    }
}
