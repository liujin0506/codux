//! AI usage stats for the headless host. The shared `codux-ai-history` engine
//! parses each CLI's session history, caches it in SQLite under the agent data
//! dir, and serves per-project usage snapshots — the same engine the desktop
//! runs, so the controller's AI stats panel renders with full parity.
//!
//! Single-reply, mirroring the desktop remote host: `project_state` returns the
//! cached snapshot (and queues a background refresh on a cold cache), and we
//! build the `ai.stats` payload from the same shared snapshot/current-session
//! wire builder the desktop host uses. The controller re-requests to pick up
//! freshly indexed data.

use codux_ai_history::indexer::AIHistoryIndexer;
use codux_ai_history::normalized::AIHistoryProjectRequest;
use codux_runtime_core::ai_stats::RemoteAICurrentSessionProvider;
use serde_json::{Value, json};
use std::path::Path;

use crate::projects::AgentProjectStore;

/// Open the indexer against the agent data dir's usage cache.
pub fn open_indexer() -> AIHistoryIndexer {
    open_indexer_at(&crate::projects::agent_data_dir())
}

pub fn open_indexer_at(data_dir: &Path) -> AIHistoryIndexer {
    AIHistoryIndexer::with_database_path(data_dir.join("ai-usage.sqlite3"))
}

/// Resolve the AI-history request for a device's selected scope. History is
/// indexed per worktree cwd (same as the desktop host / session list), so a
/// selected worktree must read that worktree's path instead of the project
/// root. The project id doubles as the default worktree's id and keeps the
/// project record.
pub fn ai_history_request_for_scope(
    project_id: &str,
    project_name: &str,
    project_path: &str,
    scope_id: &str,
) -> AIHistoryProjectRequest {
    let scope_id = scope_id.trim();
    if !scope_id.is_empty()
        && scope_id != project_id
        && let Some((path, name)) =
            crate::worktree::worktree_for_id(project_id, project_path, scope_id)
    {
        return AIHistoryProjectRequest {
            id: scope_id.to_string(),
            name,
            path,
        };
    }
    AIHistoryProjectRequest {
        id: project_id.to_string(),
        name: project_name.to_string(),
        path: project_path.to_string(),
    }
}

/// Map an indexed scope back to the project its watchers are keyed under.
/// A worktree-scoped index reports the worktree id, not the project id.
pub fn ai_stats_watcher_project_id(scope_id: &str) -> String {
    let scope_id = scope_id.trim();
    if scope_id.is_empty() {
        return String::new();
    }
    let projects = AgentProjectStore::new().list();
    if projects.iter().any(|project| project.id == scope_id) {
        return scope_id.to_string();
    }
    for project in projects {
        if crate::worktree::worktree_for_id(&project.id, &project.path, scope_id).is_some() {
            return project.id;
        }
    }
    scope_id.to_string()
}

/// Build the `ai.stats` payload for a project (or one of its worktrees).
///
/// The wire identity stays the project (`project_id` / `name`) so the phone's
/// stats panel keeps attributing the snapshot to the open project; the index
/// path follows `current_session_scope_id` so usage totals match the session
/// list for that worktree.
pub fn ai_stats_payload(
    indexer: &AIHistoryIndexer,
    current_sessions: &dyn RemoteAICurrentSessionProvider,
    project_id: &str,
    name: &str,
    path: &str,
    current_session_scope_id: &str,
) -> Value {
    let request =
        ai_history_request_for_scope(project_id, name, path, current_session_scope_id);
    let live_sessions = current_sessions.current_sessions(current_session_scope_id);
    match indexer.project_state(request) {
        Ok(state) => stats_payload_from_state(project_id, name, state, live_sessions),
        Err(_) => {
            let mut payload =
                codux_runtime_core::ai_stats::empty_ai_stats_payload(project_id, name);
            if let Some(object) = payload.as_object_mut() {
                object.insert("currentSessions".to_string(), json!(live_sessions));
            }
            payload
        }
    }
}

fn stats_payload_from_state(
    id: &str,
    name: &str,
    state: codux_ai_history::indexer::AIHistoryProjectState,
    current_sessions: Vec<codux_protocol::RemoteAICurrentSession>,
) -> Value {
    codux_runtime_core::ai_stats::ai_stats_payload_from_state(id, name, state, current_sessions)
        .unwrap_or_else(|_| codux_runtime_core::ai_stats::empty_ai_stats_payload(id, name))
}

/// The full `AIHistoryProjectState` (incl. snapshot) for a desktop controller,
/// indexed from the payload's project path directly (the controller owns the
/// project record; the agent just indexes the host's history for that path).
pub fn ai_state_payload(
    indexer: &AIHistoryIndexer,
    id: &str,
    name: &str,
    path: &str,
    refresh: bool,
) -> Result<Value, String> {
    let request = AIHistoryProjectRequest {
        id: id.to_string(),
        name: name.to_string(),
        path: path.to_string(),
    };
    if refresh {
        indexer.refresh_project(request.clone())?;
    }
    serde_json::to_value(indexer.project_state(request)?).map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn temp_dir(name: &str) -> std::path::PathBuf {
        let dir = std::env::temp_dir().join(format!(
            "codux-agent-ai-stats-{name}-{}-{}",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        fs::create_dir_all(&dir).expect("create temp dir");
        dir
    }

    #[test]
    fn ai_history_request_keeps_project_root_for_default_scope() {
        let project = temp_dir("project");
        let request = ai_history_request_for_scope(
            "project-1",
            "Project 1",
            project.to_str().unwrap(),
            "project-1",
        );
        assert_eq!(request.id, "project-1");
        assert_eq!(request.name, "Project 1");
        assert_eq!(request.path, project.to_string_lossy());
        fs::remove_dir_all(project).ok();
    }

    #[test]
    fn ai_history_request_falls_back_to_project_when_worktree_is_unknown() {
        let project = temp_dir("project");
        let request = ai_history_request_for_scope(
            "project-1",
            "Project 1",
            project.to_str().unwrap(),
            "missing-worktree",
        );
        // Unknown non-default scope must not invent a path — fall back to project.
        assert_eq!(request.id, "project-1");
        assert_eq!(request.path, project.to_string_lossy());
        fs::remove_dir_all(project).ok();
    }

    #[test]
    fn ai_history_request_reads_worktree_cwd_for_non_default_scope() {
        let project = temp_dir("project-with-worktree");
        init_repo(&project);
        let created = crate::worktree::worktree_create_payload(
            "project-1",
            project.to_str().unwrap(),
            "feature/stats-scope",
            None,
        )
        .expect("create worktree");
        let worktree = created["worktrees"]
            .as_array()
            .and_then(|worktrees| {
                worktrees
                    .iter()
                    .find(|item| !item["isDefault"].as_bool().unwrap_or(false))
            })
            .expect("created worktree");
        let worktree_id = worktree["id"].as_str().expect("worktree id");
        let worktree_path = worktree["path"].as_str().expect("worktree path");

        let request = ai_history_request_for_scope(
            "project-1",
            "Project 1",
            project.to_str().unwrap(),
            worktree_id,
        );
        assert_eq!(request.id, worktree_id);
        assert_eq!(request.path, worktree_path);

        fs::remove_dir_all(project).ok();
    }

    fn init_repo(path: &std::path::Path) {
        std::process::Command::new("git")
            .args(["init", "-b", "main"])
            .current_dir(path)
            .status()
            .expect("git init");
        fs::write(path.join("README.md"), "hello\n").expect("write readme");
        std::process::Command::new("git")
            .args(["add", "."])
            .current_dir(path)
            .status()
            .expect("git add");
        std::process::Command::new("git")
            .args([
                "-c",
                "user.name=Codux",
                "-c",
                "user.email=codux@example.com",
                "commit",
                "-m",
                "init",
            ])
            .current_dir(path)
            .status()
            .expect("git commit");
    }
}
