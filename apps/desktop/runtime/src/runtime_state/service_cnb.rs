impl RuntimeService {
    pub fn cnb_invoke(&self, project_path: &str, args: &[String]) -> Result<Value, String> {
        if let Some(result) = self.hosted_cnb_invoke(project_path, args) {
            return result;
        }
        crate::cnb::invoke_from_payload(&self.support_dir, json!({ "args": args }))
    }

    pub fn cnb_list(
        &self,
        project_path: &str,
        kind: crate::cnb_browse::CnbBrowseKind,
        state: &str,
    ) -> Result<crate::cnb_browse::CnbBrowseListResult, String> {
        let remotes = self.reload_project_git(project_path).remotes;
        let tokens = crate::cnb::CnbStore::from_support_dir(self.support_dir.clone());
        let Some(remote) = crate::cnb_browse::detect_cnb_browse_remote(&remotes, tokens.tokens())
        else {
            return Ok(crate::cnb_browse::CnbBrowseListResult {
                remote: None,
                items: Vec::new(),
            });
        };
        if !remote.token_configured {
            return Ok(crate::cnb_browse::CnbBrowseListResult {
                remote: Some(remote),
                items: Vec::new(),
            });
        }
        let mut args = crate::cnb_browse::invoke_args(kind.list_command(), &[], &remote);
        match kind {
            crate::cnb_browse::CnbBrowseKind::Builds => {}
            _ => {
                let state = state.trim();
                if !state.is_empty() && state != "all" {
                    args.push("--state".into());
                    args.push(state.to_string());
                }
            }
        }
        args.push("--page".into());
        args.push("1".into());
        args.push("--page-size".into());
        args.push("30".into());
        let value = self.cnb_invoke(project_path, &args)?;
        Ok(crate::cnb_browse::CnbBrowseListResult {
            items: crate::cnb_browse::parse_list(kind, &value, &remote),
            remote: Some(remote),
        })
    }

    pub fn cnb_detail(
        &self,
        project_path: &str,
        kind: crate::cnb_browse::CnbBrowseKind,
        id: &str,
        remote: &crate::cnb_browse::CnbBrowseRemote,
    ) -> Result<crate::cnb_browse::CnbBrowseDetail, String> {
        let value = self.cnb_invoke(
            project_path,
            &crate::cnb_browse::invoke_args(kind.detail_command(), &[id], remote),
        )?;
        let comments = kind
            .comments_command()
            .and_then(|command| {
                self.cnb_invoke(
                    project_path,
                    &crate::cnb_browse::invoke_args(command, &[id], remote),
                )
                .ok()
            })
            .map(|value| crate::cnb_browse::parse_comments(&value))
            .unwrap_or_default();
        crate::cnb_browse::parse_detail(kind, &value, &comments, remote)
            .ok_or_else(|| "CNB item could not be parsed.".to_string())
    }

    pub fn cnb_comment(
        &self,
        project_path: &str,
        kind: crate::cnb_browse::CnbBrowseKind,
        id: &str,
        remote: &crate::cnb_browse::CnbBrowseRemote,
        body: &str,
    ) -> Result<crate::cnb_browse::CnbBrowseDetail, String> {
        let command = kind.comment_command().ok_or_else(|| {
            "Comments are only supported for issues and pull requests.".to_string()
        })?;
        let mut args = crate::cnb_browse::invoke_args(command, &[id], remote);
        args.push("--body".into());
        args.push(body.to_string());
        self.cnb_invoke(project_path, &args)?;
        self.cnb_detail(project_path, kind, id, remote)
    }

    pub fn cnb_set_item_state(
        &self,
        project_path: &str,
        kind: crate::cnb_browse::CnbBrowseKind,
        id: &str,
        remote: &crate::cnb_browse::CnbBrowseRemote,
        close: bool,
    ) -> Result<crate::cnb_browse::CnbBrowseDetail, String> {
        let command = kind.update_command().ok_or_else(|| {
            "State changes are only supported for issues and pull requests.".to_string()
        })?;
        let mut args = crate::cnb_browse::invoke_args(command, &[id], remote);
        args.push("--state".into());
        args.push(if close { "closed" } else { "open" }.into());
        if kind == crate::cnb_browse::CnbBrowseKind::Issues {
            args.push("--state_reason".into());
            args.push(if close { "completed" } else { "reopened" }.into());
        }
        self.cnb_invoke(project_path, &args)?;
        self.cnb_detail(project_path, kind, id, remote)
    }

    pub fn cnb_stop_build(
        &self,
        project_path: &str,
        id: &str,
        remote: &crate::cnb_browse::CnbBrowseRemote,
    ) -> Result<crate::cnb_browse::CnbBrowseDetail, String> {
        self.cnb_invoke(
            project_path,
            &crate::cnb_browse::invoke_args("build-stop", &[id], remote),
        )?;
        self.cnb_detail(
            project_path,
            crate::cnb_browse::CnbBrowseKind::Builds,
            id,
            remote,
        )
    }
}
