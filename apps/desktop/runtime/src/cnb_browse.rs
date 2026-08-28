use crate::git::GitRemoteSummary;
use codux_runtime_live::cnb::{
    CnbRemote, CnbSite, CnbTokens, parse_git_remote, site_from_id, web_item_url,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CnbBrowseKind {
    #[default]
    Issues,
    Pulls,
    Builds,
}

impl CnbBrowseKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Issues => "issues",
            Self::Pulls => "prs",
            Self::Builds => "builds",
        }
    }

    pub fn list_command(self) -> &'static str {
        match self {
            Self::Issues => "issues",
            Self::Pulls => "prs",
            Self::Builds => "builds",
        }
    }

    pub fn detail_command(self) -> &'static str {
        match self {
            Self::Issues => "issue",
            Self::Pulls => "pr",
            Self::Builds => "build",
        }
    }

    pub fn comments_command(self) -> Option<&'static str> {
        match self {
            Self::Issues => Some("issue-comments"),
            Self::Pulls => Some("pr-comments"),
            Self::Builds => None,
        }
    }

    pub fn comment_command(self) -> Option<&'static str> {
        match self {
            Self::Issues => Some("issue-comment"),
            Self::Pulls => Some("pr-comment"),
            Self::Builds => None,
        }
    }

    pub fn update_command(self) -> Option<&'static str> {
        match self {
            Self::Issues => Some("issue-update"),
            Self::Pulls => Some("pr-update"),
            Self::Builds => None,
        }
    }
}

pub fn is_live_build(state: &str) -> bool {
    matches!(state, "pending" | "running" | "waiting")
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CnbBrowseRemote {
    pub site_id: String,
    pub site_label: String,
    pub repo: String,
    pub web: String,
    pub token_configured: bool,
}

impl CnbBrowseRemote {
    fn from_detected(remote: CnbRemote, tokens: &CnbTokens) -> Self {
        Self {
            site_id: remote.site.id.to_string(),
            site_label: remote.site.label.to_string(),
            repo: remote.repo.clone(),
            web: remote.site.web.to_string(),
            token_configured: tokens.token_for(&remote.site).is_some(),
        }
    }

    fn site(&self) -> Option<CnbSite> {
        site_from_id(&self.site_id)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CnbBrowseItem {
    pub id: String,
    pub title: String,
    pub state: String,
    pub author: String,
    pub updated_at: String,
    pub extra: String,
    pub web_url: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CnbBrowseComment {
    pub author: String,
    pub body: String,
    pub created_at: String,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CnbBrowseDetail {
    pub item: CnbBrowseItem,
    pub body: String,
    pub comments: Vec<CnbBrowseComment>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CnbBrowseListResult {
    pub remote: Option<CnbBrowseRemote>,
    pub items: Vec<CnbBrowseItem>,
}

pub fn detect_cnb_browse_remote(
    remotes: &[GitRemoteSummary],
    tokens: &CnbTokens,
) -> Option<CnbBrowseRemote> {
    detect_cnb_remote(remotes).map(|remote| CnbBrowseRemote::from_detected(remote, tokens))
}

fn detect_cnb_remote(remotes: &[GitRemoteSummary]) -> Option<CnbRemote> {
    let mut origin = None;
    let mut first = None;
    for remote in remotes {
        let Some(parsed) = parse_git_remote(&remote.url) else {
            continue;
        };
        if remote.name == "origin" {
            origin = Some(parsed);
            break;
        }
        if first.is_none() {
            first = Some(parsed);
        }
    }
    origin.or(first)
}

pub fn invoke_args(command: &str, positional: &[&str], remote: &CnbBrowseRemote) -> Vec<String> {
    let mut args = vec![
        command.to_string(),
        "--site".into(),
        remote.site_id.clone(),
        "--repo".into(),
        remote.repo.clone(),
    ];
    for value in positional {
        args.push((*value).to_string());
    }
    args
}

pub fn parse_list(
    kind: CnbBrowseKind,
    value: &Value,
    remote: &CnbBrowseRemote,
) -> Vec<CnbBrowseItem> {
    json_items(value)
        .into_iter()
        .filter_map(|item| parse_item(kind, item, remote))
        .collect()
}

fn json_items(value: &Value) -> Vec<&Value> {
    if let Some(items) = value.as_array() {
        return items.iter().collect();
    }
    for key in ["data", "items", "list"] {
        if let Some(items) = value.get(key).and_then(Value::as_array) {
            return items.iter().collect();
        }
    }
    Vec::new()
}

fn parse_item(
    kind: CnbBrowseKind,
    value: &Value,
    remote: &CnbBrowseRemote,
) -> Option<CnbBrowseItem> {
    let site = remote.site()?;
    match kind {
        CnbBrowseKind::Builds => {
            let id = json_string(value, &["sn", "id"]);
            if id.is_empty() {
                return None;
            }
            let status = json_string(value, &["status"]).to_ascii_lowercase();
            let title =
                first_nonempty(&[json_string(value, &["title", "commitTitle"]), id.clone()]);
            Some(CnbBrowseItem {
                extra: first_nonempty(&[
                    json_string(value, &["sourceRef", "event"]),
                    format_duration_ms(value.get("duration").and_then(Value::as_i64).unwrap_or(0)),
                ]),
                web_url: web_item_url(site, &remote.repo, "builds", &id),
                author: first_nonempty(&[json_string(value, &["userName", "nickName"])]),
                updated_at: json_string(value, &["createTime", "created_at", "updated_at"]),
                state: status,
                title,
                id,
            })
        }
        CnbBrowseKind::Issues | CnbBrowseKind::Pulls => {
            let id = json_string(value, &["number", "id"]);
            if id.is_empty() {
                return None;
            }
            let mut state = json_string(value, &["state"]).to_ascii_lowercase();
            if value
                .get("is_merged")
                .and_then(Value::as_bool)
                .unwrap_or(false)
                || state == "merged"
            {
                state = "merged".into();
            } else if value
                .get("is_wip")
                .and_then(Value::as_bool)
                .unwrap_or(false)
            {
                state = "draft".into();
            } else if state.is_empty() {
                state = "open".into();
            }
            let extra = match kind {
                CnbBrowseKind::Pulls => first_nonempty(&[
                    branch_name(value.get("head")),
                    json_string(value, &["headRefName"]),
                ]),
                _ => String::new(),
            };
            Some(CnbBrowseItem {
                web_url: web_item_url(site, &remote.repo, kind.as_str(), &id),
                author: user_name(value.get("author")),
                updated_at: json_string(value, &["updated_at", "last_acted_at", "created_at"]),
                title: json_string(value, &["title"]),
                extra,
                state,
                id,
            })
        }
    }
}

pub fn parse_detail(
    kind: CnbBrowseKind,
    value: &Value,
    comments: &[CnbBrowseComment],
    remote: &CnbBrowseRemote,
) -> Option<CnbBrowseDetail> {
    let item = parse_item(kind, value, remote)?;
    Some(CnbBrowseDetail {
        body: json_string(value, &["body", "commitTitle"]),
        comments: comments.to_vec(),
        item,
    })
}

pub fn parse_comments(value: &Value) -> Vec<CnbBrowseComment> {
    json_items(value)
        .into_iter()
        .map(|item| CnbBrowseComment {
            author: user_name(item.get("author")),
            body: json_string(item, &["body"]),
            created_at: json_string(item, &["created_at", "submitted_at"]),
        })
        .filter(|comment| !comment.body.is_empty() || !comment.author.is_empty())
        .collect()
}

fn json_string(value: &Value, keys: &[&str]) -> String {
    for key in keys {
        if let Some(text) = value.get(*key).and_then(value_as_text) {
            if !text.is_empty() {
                return text;
            }
        }
    }
    String::new()
}

fn value_as_text(value: &Value) -> Option<String> {
    match value {
        Value::String(text) => Some(text.trim().to_string()),
        Value::Number(number) => Some(number.to_string()),
        Value::Bool(flag) => Some(flag.to_string()),
        _ => None,
    }
}

fn user_name(value: Option<&Value>) -> String {
    let Some(value) = value else {
        return String::new();
    };
    if let Some(text) = value.as_str() {
        return text.trim().to_string();
    }
    json_string(value, &["username", "nickname", "name", "login"])
}

fn branch_name(value: Option<&Value>) -> String {
    let Some(value) = value else {
        return String::new();
    };
    let raw = if let Some(text) = value.as_str() {
        text.to_string()
    } else {
        json_string(value, &["ref", "name"])
    };
    raw.trim().trim_start_matches("refs/heads/").to_string()
}

fn first_nonempty(values: &[String]) -> String {
    values
        .iter()
        .map(|value| value.trim())
        .find(|value| !value.is_empty())
        .unwrap_or_default()
        .to_string()
}

fn format_duration_ms(ms: i64) -> String {
    if ms <= 0 {
        return String::new();
    }
    let sec = ((ms as f64) / 1000.0).round() as i64;
    if sec < 60 {
        return format!("{sec}s");
    }
    let min = sec / 60;
    let rem = sec % 60;
    if min < 60 {
        return if rem == 0 {
            format!("{min}m")
        } else {
            format!("{min}m {rem}s")
        };
    }
    format!("{}h {}m", min / 60, min % 60)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn action_commands_match_kind() {
        assert_eq!(
            CnbBrowseKind::Issues.comment_command(),
            Some("issue-comment")
        );
        assert_eq!(CnbBrowseKind::Pulls.comment_command(), Some("pr-comment"));
        assert_eq!(CnbBrowseKind::Builds.comment_command(), None);
        assert_eq!(CnbBrowseKind::Issues.update_command(), Some("issue-update"));
        assert_eq!(CnbBrowseKind::Pulls.update_command(), Some("pr-update"));
        assert!(is_live_build("running"));
        assert!(is_live_build("pending"));
        assert!(!is_live_build("success"));
    }

    #[test]
    fn detect_prefers_origin_cnb_remote() {
        let remotes = vec![
            GitRemoteSummary {
                name: "upstream".into(),
                url: "https://cnb.cool/other/repo.git".into(),
            },
            GitRemoteSummary {
                name: "origin".into(),
                url: "git@cnb.woa.com:team/app.git".into(),
            },
        ];
        let tokens = CnbTokens {
            token_cool: String::new(),
            token_woa: "secret".into(),
        };
        let remote = detect_cnb_browse_remote(&remotes, &tokens).unwrap();
        assert_eq!(remote.site_id, "woa");
        assert_eq!(remote.repo, "team/app");
        assert!(remote.token_configured);
    }

    #[test]
    fn parse_issue_and_build_rows() {
        let remote = CnbBrowseRemote {
            site_id: "cool".into(),
            site_label: "cnb.cool".into(),
            repo: "group/repo".into(),
            web: "https://cnb.cool".into(),
            token_configured: true,
        };
        let issues = parse_list(
            CnbBrowseKind::Issues,
            &json!([{
                "number": 12,
                "title": "Fix login",
                "state": "open",
                "author": { "username": "ada" },
                "updated_at": "2026-08-28T00:00:00Z"
            }]),
            &remote,
        );
        assert_eq!(issues[0].id, "12");
        assert_eq!(issues[0].author, "ada");
        assert!(issues[0].web_url.ends_with("/-/issues/12"));

        let builds = parse_list(
            CnbBrowseKind::Builds,
            &json!({
                "data": [{
                    "sn": "abc",
                    "title": "ci",
                    "status": "SUCCESS",
                    "userName": "ada",
                    "createTime": "2026-08-28T00:00:00Z",
                    "duration": 90000
                }]
            }),
            &remote,
        );
        assert_eq!(builds[0].id, "abc");
        assert_eq!(builds[0].state, "success");
        assert_eq!(builds[0].extra, "1m 30s");
    }
}
