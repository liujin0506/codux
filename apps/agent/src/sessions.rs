//! AI-session ops for the headless host. The controller routes a remote-hosted
//! project's session list / detail / rename / remove / fork here; the agent runs
//! the shared `codux-ai-sessions` op dispatch against its own `ai-usage.sqlite3`
//! — the same table the desktop host uses, so the two never drift.

use codux_ai_history::{indexer::AIHistoryIndexer, normalized::AIHistoryProjectRequest};
use codux_ai_sessions::AIHistoryService;
use serde_json::Value;

use crate::projects::{AgentProjectStore, agent_data_dir};

/// Serve an `ai.session` query. Returns `{op, result}` where `result` is the
/// operation's JSON value.
pub fn ai_session_payload(indexer: &AIHistoryIndexer, payload: &Value) -> Result<Value, String> {
    let project_id = string_field(payload, "projectId");
    let store = AgentProjectStore::new();
    let project = store.list().into_iter().find(|item| item.id == project_id);
    let worktree_id = payload
        .get("worktreeId")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty());
    let worktree = worktree_id.and_then(|id| {
        project
            .as_ref()
            .and_then(|project| crate::worktree::worktree_for_id(&project.id, &project.path, id))
            .map(|(path, name)| (id.to_string(), path, name))
    });
    let project_path = payload
        .get("projectPath")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .or_else(|| worktree.as_ref().map(|(_, path, _)| path.clone()))
        .or_else(|| project.as_ref().map(|project| project.path.clone()))
        .unwrap_or_default();
    let service = AIHistoryService::new(agent_data_dir());
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("");
    let result = codux_ai_sessions::session_op_result_with_indexer(
        &service,
        indexer,
        AIHistoryProjectRequest {
            id: worktree
                .as_ref()
                .map(|(id, _, _)| id.clone())
                .filter(|value| !value.is_empty())
                .or_else(|| {
                    payload
                        .get("projectId")
                        .and_then(Value::as_str)
                        .filter(|value| !value.is_empty())
                        .map(str::to_string)
                })
                .unwrap_or_default(),
            name: worktree
                .as_ref()
                .map(|(_, _, name)| name.clone())
                .or_else(|| {
                    payload
                        .get("projectName")
                        .and_then(Value::as_str)
                        .filter(|value| !value.is_empty())
                        .map(str::to_string)
                })
                .unwrap_or_default(),
            path: project_path,
        },
        payload,
    )?;
    Ok(serde_json::json!({ "op": op, "result": result }))
}

fn string_field(payload: &Value, key: &str) -> String {
    payload
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}
