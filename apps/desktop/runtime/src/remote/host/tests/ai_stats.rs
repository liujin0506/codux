use super::*;

#[test]
fn ai_stats_watcher_tracks_one_project_per_device_and_clears_on_disconnect() {
    let support_dir = temp_support_dir("codux-remote-ai-stats-watcher");
    let runtime = RemoteHostRuntime::new(support_dir.clone());

    runtime.register_ai_stats_watcher("project-a", "device-1", "project-a");
    runtime.register_ai_stats_watcher("project-a", "device-2", "worktree-x");
    {
        let watchers = runtime.ai_stats_watchers.lock().unwrap();
        assert_eq!(watchers["project-a"].len(), 2);
        assert_eq!(watchers["project-a"]["device-2"], "worktree-x");
    }

    // Switching a device to another project drops its old-project entry.
    runtime.register_ai_stats_watcher("project-b", "device-1", "project-b");
    {
        let watchers = runtime.ai_stats_watchers.lock().unwrap();
        assert!(!watchers["project-a"].contains_key("device-1"));
        assert!(watchers["project-b"].contains_key("device-1"));
        assert!(watchers["project-a"].contains_key("device-2"));
    }

    // Disconnect drops the device from every project, pruning empties.
    runtime.clear_ai_stats_watcher_device("device-1");
    runtime.clear_ai_stats_watcher_device("device-2");
    assert!(runtime.ai_stats_watchers.lock().unwrap().is_empty());

    fs::remove_dir_all(support_dir).ok();
}

#[test]
fn ai_stats_resource_unsubscribe_removes_runtime_watcher() {
    let support_dir = temp_support_dir("codux-remote-ai-stats-unsubscribe");
    let runtime = RemoteHostRuntime::new(support_dir.clone());
    runtime.register_ai_stats_watcher("project-a", "device-1", "project-a");
    runtime.resource_subscriptions.subscribe(
        REMOTE_RESOURCE_AI_STATS,
        Some("project-a"),
        None,
        "device-1",
    );

    runtime.handle_resource_unsubscribe(&RemoteEnvelope {
        kind: REMOTE_RESOURCE_UNSUBSCRIBE.to_string(),
        device_id: Some("device-1".to_string()),
        session_id: None,
        request_id: None,
        seq: None,
        payload: json!({
            "resource": REMOTE_RESOURCE_AI_STATS,
            "projectId": "project-a",
        }),
    });

    assert!(runtime.ai_stats_watchers.lock().unwrap().is_empty());
    fs::remove_dir_all(support_dir).ok();
}

#[test]
fn ai_stats_rejects_unknown_project_instead_of_using_first_project() {
    let support_dir = temp_support_dir("codux-remote-ai-stats-project-scope");
    write_two_project_state(&support_dir);
    let runtime = RemoteHostRuntime::new(support_dir.clone());
    let transport = Arc::new(CapturingTransport::default());
    if let Ok(mut current) = runtime.transport.lock() {
        *current = Some(transport.clone());
    }

    runtime.handle_ai_stats(&RemoteEnvelope {
        kind: REMOTE_AI_STATS.to_string(),
        device_id: Some("device-1".to_string()),
        session_id: None,
        request_id: None,
        seq: None,
        payload: json!({
            "projectId": "missing-project",
            "worktreeId": "missing-worktree"
        }),
    });

    let messages = transport.take_messages();
    assert_eq!(messages.len(), 1);
    let envelope: RemoteEnvelope = serde_json::from_slice(&messages[0].1).expect("error envelope");
    assert_eq!(envelope.kind, REMOTE_ERROR);
    assert_eq!(
        envelope.payload["message"],
        "Project not found for AI stats."
    );
    assert!(runtime.ai_stats_watchers.lock().unwrap().is_empty());

    fs::remove_dir_all(support_dir).ok();
}

#[test]
fn ai_stats_reads_the_selected_worktree_scope_not_the_project_root() {
    let support_dir = temp_support_dir("codux-remote-ai-stats-worktree-scope");
    let (_project_a, project_b) = write_two_project_state(&support_dir);
    let worktree_b_path = support_dir.join("worktree-b-checkout");
    fs::create_dir_all(&worktree_b_path).expect("create worktree dir");
    let mut state: Value =
        serde_json::from_str(&fs::read_to_string(support_dir.join("state.json")).expect("read"))
            .expect("parse state");
    state["worktrees"][0]["path"] = json!(worktree_b_path.to_string_lossy());
    fs::write(
        support_dir.join("state.json"),
        serde_json::to_string_pretty(&state).expect("serialize state"),
    )
    .expect("write state");
    let runtime = RemoteHostRuntime::new(support_dir.clone());
    let project = ProjectStore::new(support_dir.clone())
        .projects_snapshot()
        .into_iter()
        .find(|project| project.id == "project-b")
        .expect("project-b");

    // A worktree scope must read that worktree's cwd, the same index the
    // session list uses; otherwise usage totals stay project-wide.
    let scoped = runtime.ai_history_request_for_scope(&project, "worktree-b");
    assert_eq!(scoped.id, "worktree-b");
    assert_eq!(scoped.path, worktree_b_path.to_string_lossy());

    // The project id doubles as the default scope and keeps the project root.
    let default_scope = runtime.ai_history_request_for_scope(&project, "project-b");
    assert_eq!(default_scope.id, "project-b");
    assert_eq!(default_scope.path, project_b.to_string_lossy());

    // Watchers stay keyed by project, so a worktree-scoped index still finds them.
    assert_eq!(
        runtime.ai_stats_watcher_project_id("worktree-b"),
        "project-b"
    );
    assert_eq!(
        runtime.ai_stats_watcher_project_id("project-b"),
        "project-b"
    );

    fs::remove_dir_all(support_dir).ok();
}

#[test]
fn ai_session_error_reply_preserves_request_id() {
    let support_dir = temp_support_dir("codux-remote-ai-session-error");
    let runtime = RemoteHostRuntime::new(support_dir.clone());
    let transport = Arc::new(CapturingTransport::default());
    if let Ok(mut current) = runtime.transport.lock() {
        *current = Some(transport.clone());
    }

    runtime.handle_ai_session(&RemoteEnvelope {
        kind: REMOTE_AI_SESSION.to_string(),
        device_id: Some("device-1".to_string()),
        session_id: None,
        request_id: Some("request-ai-error".to_string()),
        seq: None,
        payload: json!({
            "op": "detail",
            "projectPath": "/missing/project",
            "sessionId": "missing-session",
        }),
    });

    let messages = transport.take_messages();
    assert_eq!(messages.len(), 1);
    let envelope: Value = serde_json::from_slice(&messages[0].1).expect("error envelope");
    assert_eq!(envelope["type"], REMOTE_ERROR);
    assert_eq!(envelope["requestId"], "request-ai-error");
    assert!(envelope["payload"]["message"].is_string());

    fs::remove_dir_all(support_dir).ok();
}
