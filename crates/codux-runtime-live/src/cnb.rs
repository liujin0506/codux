//! CNB (cnb.cool / cnb.woa.com) client used by `codux-cnb`.
//!
//! Token injection and HTTP happen in this process so the model never sees
//! credentials. When Codex runs on a remote/WSL agent, this code runs there
//! too — `cnb.woa.com` is reached from the host that can actually see it.

use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::{
    fs,
    io::Write,
    path::{Path, PathBuf},
    process::{Command, Stdio},
};

const CURL_TRAILER: &str = "\n--cnb-curl-trailer--\n";
const CURL_TIMEOUT_SECS: &str = "30";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct CnbSite {
    pub id: &'static str,
    pub label: &'static str,
    pub api: &'static str,
    pub web: &'static str,
}

pub const SITE_COOL: CnbSite = CnbSite {
    id: "cool",
    label: "cnb.cool",
    api: "https://api.cnb.cool",
    web: "https://cnb.cool",
};

pub const SITE_WOA: CnbSite = CnbSite {
    id: "woa",
    label: "cnb.woa.com",
    api: "https://api.cnb.woa.com",
    web: "https://cnb.woa.com",
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CnbRemote {
    pub site: CnbSite,
    pub repo: String,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CnbTokens {
    #[serde(default)]
    pub token_cool: String,
    #[serde(default)]
    pub token_woa: String,
}

impl CnbTokens {
    pub fn sanitized(self) -> Self {
        Self {
            token_cool: self.token_cool.trim().to_string(),
            token_woa: self.token_woa.trim().to_string(),
        }
    }

    pub fn token_for(&self, site: &CnbSite) -> Option<&str> {
        let token = match site.id {
            "woa" => self.token_woa.as_str(),
            _ => self.token_cool.as_str(),
        };
        (!token.is_empty()).then_some(token)
    }

    pub fn cool_configured(&self) -> bool {
        !self.token_cool.trim().is_empty()
    }

    pub fn woa_configured(&self) -> bool {
        !self.token_woa.trim().is_empty()
    }

    pub fn any_configured(&self) -> bool {
        self.cool_configured() || self.woa_configured()
    }

    pub fn redacted(&self) -> Value {
        json!({
            "tokenCoolConfigured": self.cool_configured(),
            "tokenWoaConfigured": self.woa_configured(),
        })
    }
}

pub fn tokens_file_path(support_dir: &Path) -> PathBuf {
    support_dir.join("cnb_tokens.json")
}

pub fn load_tokens(path: &Path) -> CnbTokens {
    fs::read_to_string(path)
        .ok()
        .and_then(|text| serde_json::from_str::<CnbTokens>(&text).ok())
        .unwrap_or_default()
        .sanitized()
}

pub fn save_tokens(path: &Path, tokens: &CnbTokens) -> Result<(), String> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let json = serde_json::to_string_pretty(tokens).map_err(|error| error.to_string())?;
    fs::write(path, format!("{json}\n")).map_err(|error| error.to_string())
}

pub fn site_from_id(id: &str) -> Option<CnbSite> {
    match id.trim().to_ascii_lowercase().as_str() {
        "cool" | "cnb.cool" => Some(SITE_COOL),
        "woa" | "cnb.woa.com" => Some(SITE_WOA),
        _ => None,
    }
}

pub fn site_from_host(host: &str) -> Option<CnbSite> {
    let host = host.to_ascii_lowercase();
    let host = host.split(':').next().unwrap_or(&host);
    if host == "cnb.cool" || host.ends_with(".cnb.cool") {
        Some(SITE_COOL)
    } else if host == "cnb.woa.com" || host.ends_with(".cnb.woa.com") {
        Some(SITE_WOA)
    } else {
        None
    }
}

pub fn parse_git_remote(url: &str) -> Option<CnbRemote> {
    let value = url.trim();
    if value.is_empty() {
        return None;
    }
    let (host, path) = if let Some(captures) = value
        .find("://")
        .and_then(|_| parse_http_remote(value))
    {
        captures
    } else {
        parse_scp_remote(value)?
    };
    let site = site_from_host(&host)?;
    let repo = path
        .trim_matches('/')
        .trim_end_matches(".git")
        .trim()
        .to_string();
    if repo.is_empty() {
        return None;
    }
    Some(CnbRemote { site, repo })
}

fn parse_http_remote(url: &str) -> Option<(String, String)> {
    let rest = url.splitn(2, "://").nth(1)?;
    let rest = rest.splitn(2, '@').last()?;
    let (host, path) = rest.split_once('/')?;
    Some((host.to_string(), path.to_string()))
}

fn parse_scp_remote(url: &str) -> Option<(String, String)> {
    let rest = url.splitn(2, '@').last()?;
    let (host, path) = rest.split_once(':')?;
    if host.contains('/') {
        return None;
    }
    Some((host.to_string(), path.to_string()))
}

pub fn parse_remote_list(stdout: &str) -> Option<CnbRemote> {
    let mut origin = None;
    let mut first = None;
    for line in stdout.lines() {
        let mut parts = line.split_whitespace();
        let name = parts.next()?;
        let url = parts.next()?;
        let Some(parsed) = parse_git_remote(url) else {
            continue;
        };
        if name == "origin" {
            origin = Some(parsed);
            break;
        }
        if first.is_none() {
            first = Some(parsed);
        }
    }
    origin.or(first)
}

pub fn encode_repo(repo: &str) -> String {
    repo.split('/')
        .filter(|part| !part.is_empty())
        .map(|part| {
            let mut encoded = String::new();
            for ch in part.chars() {
                match ch {
                    'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' | '~' => encoded.push(ch),
                    _ => {
                        for byte in ch.to_string().as_bytes() {
                            encoded.push_str(&format!("%{byte:02X}"));
                        }
                    }
                }
            }
            encoded
        })
        .collect::<Vec<_>>()
        .join("/")
}

pub fn detect_cnb_remote_from_cwd() -> Result<CnbRemote, String> {
    let output = Command::new("git")
        .args(["remote", "-v"])
        .output()
        .map_err(|error| format!("codux-cnb: failed to read git remotes: {error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    parse_remote_list(&stdout)
        .ok_or_else(|| "codux-cnb: current repository is not on cnb.cool or cnb.woa.com".to_string())
}

pub fn invoke(args: &[String], tokens_path: &Path) -> Result<Value, String> {
    let tokens = load_tokens(tokens_path);
    run_command(args, &tokens)
}

fn run_command(args: &[String], tokens: &CnbTokens) -> Result<Value, String> {
    let parsed = parse_invoke_args(args)?;
    if parsed.command == "help" || parsed.command == "-h" || parsed.command == "--help" {
        return Ok(json!({ "usage": usage_text() }));
    }
    if parsed.command == "status" {
        return status_payload(tokens, parsed.site, parsed.repo.as_deref());
    }

    let remote = resolve_remote(&parsed)?;
    let token = tokens.token_for(&remote.site).ok_or_else(|| {
        format!(
            "codux-cnb: no access token configured for {}. Add it in Codux Settings → Git.",
            remote.site.label
        )
    })?;
    let request = build_request(&parsed, &remote)?;
    let response = curl_json(remote.site, token, &request)?;
    Ok(response)
}

struct ParsedInvoke {
    command: String,
    positional: Vec<String>,
    flags: Map<String, Value>,
    site: Option<CnbSite>,
    repo: Option<String>,
}

fn parse_invoke_args(args: &[String]) -> Result<ParsedInvoke, String> {
    let mut command = String::new();
    let mut positional = Vec::new();
    let mut flags = Map::new();
    let mut site = None;
    let mut repo = None;
    let mut index = 0;
    while index < args.len() {
        let arg = &args[index];
        if arg == "--" {
            let rest = args[index + 1..].join(" ");
            if !rest.trim().is_empty() {
                flags.insert("body".to_string(), Value::String(rest));
            }
            break;
        }
        if let Some(flag) = arg.strip_prefix("--") {
            let value = if let Some((key, value)) = flag.split_once('=') {
                flags.insert(key.to_string(), Value::String(value.to_string()));
                index += 1;
                continue;
            } else {
                index += 1;
                args.get(index)
                    .cloned()
                    .ok_or_else(|| format!("codux-cnb: missing value for --{flag}"))?
            };
            match flag {
                "site" => {
                    site = Some(site_from_id(&value).ok_or_else(|| {
                        "codux-cnb: --site must be cool or woa".to_string()
                    })?);
                }
                "repo" => repo = Some(value),
                "json" | "body" => {
                    flags.insert(flag.to_string(), parse_json_or_string(&value));
                }
                _ => {
                    flags.insert(flag.to_string(), Value::String(value));
                }
            }
            index += 1;
            continue;
        }
        if command.is_empty() {
            command = arg.clone();
        } else {
            positional.push(arg.clone());
        }
        index += 1;
    }
    if command.is_empty() {
        return Err("codux-cnb: missing command".to_string());
    }
    Ok(ParsedInvoke {
        command,
        positional,
        flags,
        site,
        repo,
    })
}

fn parse_json_or_string(value: &str) -> Value {
    serde_json::from_str(value).unwrap_or_else(|_| Value::String(value.to_string()))
}

fn resolve_remote(parsed: &ParsedInvoke) -> Result<CnbRemote, String> {
    if let (Some(site), Some(repo)) = (parsed.site, parsed.repo.as_deref()) {
        return Ok(CnbRemote {
            site,
            repo: repo.trim().trim_matches('/').to_string(),
        });
    }
    let detected = detect_cnb_remote_from_cwd()?;
    Ok(CnbRemote {
        site: parsed.site.unwrap_or(detected.site),
        repo: parsed
            .repo
            .as_deref()
            .map(|repo| repo.trim().trim_matches('/').to_string())
            .filter(|repo| !repo.is_empty())
            .unwrap_or(detected.repo),
    })
}

fn status_payload(
    tokens: &CnbTokens,
    site: Option<CnbSite>,
    repo: Option<&str>,
) -> Result<Value, String> {
    let detected = detect_cnb_remote_from_cwd().ok();
    let site = site.or_else(|| detected.as_ref().map(|remote| remote.site));
    let repo = repo
        .map(str::to_string)
        .or_else(|| detected.as_ref().map(|remote| remote.repo.clone()));
    Ok(json!({
        "site": site.map(|site| site.label),
        "repo": repo,
        "detected": detected.is_some(),
        "tokenCoolConfigured": tokens.cool_configured(),
        "tokenWoaConfigured": tokens.woa_configured(),
        "apiHost": site.map(|site| site.api),
    }))
}

struct CnbRequest {
    method: String,
    path: String,
    query: Map<String, Value>,
    body: Option<Value>,
}

fn build_request(parsed: &ParsedInvoke, remote: &CnbRemote) -> Result<CnbRequest, String> {
    let base = format!("/{}", encode_repo(&remote.repo));
    let command = parsed.command.as_str();
    match command {
        "whoami" => Ok(get("/user")),
        "issues" => Ok(list_request(
            format!("{base}/-/issues"),
            &parsed.flags,
            &["state", "page", "page-size", "author", "assignee", "search"],
        )),
        "issue" => Ok(get(&format!("{base}/-/issues/{}", required_number(parsed)?))),
        "issue-create" => Ok(CnbRequest {
            method: "POST".into(),
            path: format!("{base}/-/issues"),
            query: Map::new(),
            body: Some(object_body(
                &parsed.flags,
                &[("title", true), ("body", false)],
            )?),
        }),
        "issue-update" => Ok(CnbRequest {
            method: "PATCH".into(),
            path: format!("{base}/-/issues/{}", required_number(parsed)?),
            query: Map::new(),
            body: Some(json_body(&parsed.flags)?),
        }),
        "issue-comment" => Ok(CnbRequest {
            method: "POST".into(),
            path: format!(
                "{base}/-/issues/{}/comments",
                required_number(parsed)?
            ),
            query: Map::new(),
            body: Some(object_body(&parsed.flags, &[("body", true)])?),
        }),
        "prs" | "pulls" => Ok(list_request(
            format!("{base}/-/pulls"),
            &parsed.flags,
            &["state", "page", "page-size", "author", "assignee", "search"],
        )),
        "pr" | "pull" => Ok(get(&format!(
            "{base}/-/pulls/{}",
            required_number(parsed)?
        ))),
        "pr-create" => Ok(CnbRequest {
            method: "POST".into(),
            path: format!("{base}/-/pulls"),
            query: Map::new(),
            body: Some(pr_create_body(&parsed.flags)?),
        }),
        "issue-comments" => Ok(list_request(
            format!("{base}/-/issues/{}/comments", required_number(parsed)?),
            &parsed.flags,
            &["page", "page-size", "sort"],
        )),
        "pr-comments" | "pull-comments" => Ok(list_request(
            format!("{base}/-/pulls/{}/comments", required_number(parsed)?),
            &parsed.flags,
            &["page", "page-size"],
        )),
        "pr-comment" => Ok(CnbRequest {
            method: "POST".into(),
            path: format!("{base}/-/pulls/{}/comments", required_number(parsed)?),
            query: Map::new(),
            body: Some(object_body(&parsed.flags, &[("body", true)])?),
        }),
        "pr-merge" => Ok(CnbRequest {
            method: "PUT".into(),
            path: format!("{base}/-/pulls/{}/merge", required_number(parsed)?),
            query: Map::new(),
            body: parsed
                .flags
                .get("json")
                .cloned()
                .or_else(|| parsed.flags.get("body").cloned())
                .or_else(|| Some(json!({}))),
        }),
        "pr-review" => Ok(CnbRequest {
            method: "POST".into(),
            path: format!("{base}/-/pulls/{}/reviews", required_number(parsed)?),
            query: Map::new(),
            body: Some(object_body(
                &parsed.flags,
                &[("event", true), ("body", false)],
            )?),
        }),
        "pr-files" => Ok(get(&format!(
            "{base}/-/pulls/{}/files",
            required_number(parsed)?
        ))),
        "pr-commits" => Ok(get(&format!(
            "{base}/-/pulls/{}/commits",
            required_number(parsed)?
        ))),
        "builds" => Ok(list_request(
            format!("{base}/-/build/logs"),
            &parsed.flags,
            &["page", "page-size", "status", "event", "ref"],
        )),
        "build" => Ok(get(&format!(
            "{base}/-/build/status/{}",
            required_positional(parsed, "build sn")?
        ))),
        "build-start" => Ok(CnbRequest {
            method: "POST".into(),
            path: format!("{base}/-/build/start"),
            query: Map::new(),
            body: Some(
                parsed
                    .flags
                    .get("json")
                    .cloned()
                    .or_else(|| parsed.flags.get("body").cloned())
                    .unwrap_or_else(|| json!({})),
            ),
        }),
        "build-stop" => Ok(CnbRequest {
            method: "POST".into(),
            path: format!(
                "{base}/-/build/stop/{}",
                required_positional(parsed, "build sn")?
            ),
            query: Map::new(),
            body: None,
        }),
        "releases" => Ok(list_request(
            format!("{base}/-/releases"),
            &parsed.flags,
            &["page", "page-size"],
        )),
        "members" => Ok(list_request(
            format!("{base}/-/members"),
            &parsed.flags,
            &["page", "page-size", "search"],
        )),
        "labels" => Ok(list_request(
            format!("{base}/-/labels"),
            &parsed.flags,
            &["page", "page-size", "keyword"],
        )),
        "api" => {
            let method = parsed
                .positional
                .first()
                .cloned()
                .ok_or_else(|| "codux-cnb api: missing METHOD".to_string())?;
            let path = parsed
                .positional
                .get(1)
                .cloned()
                .ok_or_else(|| "codux-cnb api: missing path".to_string())?;
            Ok(CnbRequest {
                method: method.to_ascii_uppercase(),
                path,
                query: Map::new(),
                body: parsed
                    .flags
                    .get("json")
                    .cloned()
                    .or_else(|| parsed.flags.get("body").cloned()),
            })
        }
        _ => Err(format!(
            "codux-cnb: unknown command '{}'\n{}",
            parsed.command,
            usage_text()
        )),
    }
}

fn get(path: &str) -> CnbRequest {
    CnbRequest {
        method: "GET".into(),
        path: path.to_string(),
        query: Map::new(),
        body: None,
    }
}

fn list_request(path: String, flags: &Map<String, Value>, keys: &[&str]) -> CnbRequest {
    let mut query = Map::new();
    for key in keys {
        if let Some(value) = flags.get(*key) {
            query.insert((*key).replace('-', "_"), value.clone());
        }
    }
    if !query.contains_key("page") {
        query.insert("page".into(), json!(1));
    }
    if !query.contains_key("page_size") {
        query.insert("page_size".into(), json!(20));
    }
    CnbRequest {
        method: "GET".into(),
        path,
        query,
        body: None,
    }
}

fn required_number(parsed: &ParsedInvoke) -> Result<&str, String> {
    required_positional(parsed, "number")
}

fn required_positional<'a>(parsed: &'a ParsedInvoke, label: &str) -> Result<&'a str, String> {
    parsed
        .positional
        .first()
        .map(String::as_str)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| format!("codux-cnb {}: missing {label}", parsed.command))
}

fn object_body(flags: &Map<String, Value>, fields: &[(&str, bool)]) -> Result<Value, String> {
    if let Some(json) = flags.get("json") {
        return Ok(json.clone());
    }
    let mut body = Map::new();
    for (key, required) in fields {
        match flags.get(*key) {
            Some(value) => {
                body.insert((*key).to_string(), value.clone());
            }
            None if *required => {
                return Err(format!("codux-cnb: missing --{key}"));
            }
            None => {}
        }
    }
    Ok(Value::Object(body))
}

fn json_body(flags: &Map<String, Value>) -> Result<Value, String> {
    flags
        .get("json")
        .cloned()
        .or_else(|| flags.get("body").cloned())
        .ok_or_else(|| "codux-cnb: missing --json body".to_string())
}

fn pr_create_body(flags: &Map<String, Value>) -> Result<Value, String> {
    if let Some(json) = flags.get("json") {
        return Ok(json.clone());
    }
    let mut body = object_body(flags, &[("title", true), ("head", true), ("base", true), ("body", false)])?;
    if let Some(object) = body.as_object_mut() {
        if let Some(head) = object.remove("head") {
            object.insert("head".into(), json!({ "ref": head }));
        }
        if let Some(base) = object.remove("base") {
            object.insert("base".into(), json!({ "ref": base }));
        }
    }
    Ok(body)
}

pub fn web_item_url(site: CnbSite, repo: &str, kind: &str, id: &str) -> String {
    match kind {
        "prs" | "pulls" | "pr" | "pull" => format!("{}/{}/-/pulls/{id}", site.web, repo),
        "builds" | "build" => format!("{}/{}/-/build/{id}", site.web, repo),
        _ => format!("{}/{}/-/issues/{id}", site.web, repo),
    }
}

fn usage_text() -> &'static str {
    "usage: codux-cnb status|whoami|issues|issue|issue-create|issue-update|issue-comment|issue-comments|prs|pr|pr-create|pr-comment|pr-comments|pr-merge|pr-review|pr-files|pr-commits|builds|build|build-start|build-stop|releases|members|labels|api\n\
Run `codux-cnb status` first to confirm the current CNB repo and which tokens are configured.\n\
Tokens stay inside Codux; never print, infer, or hardcode them."
}

fn curl_json(site: CnbSite, token: &str, request: &CnbRequest) -> Result<Value, String> {
    let mut url = format!("{}{}", site.api, request.path);
    if !request.query.is_empty() {
        let mut pairs = Vec::new();
        for (key, value) in &request.query {
            let text = match value {
                Value::String(text) => text.clone(),
                Value::Number(number) => number.to_string(),
                Value::Bool(flag) => flag.to_string(),
                Value::Null => continue,
                other => other.to_string(),
            };
            if text.is_empty() {
                continue;
            }
            pairs.push(format!("{}={}", urlencode(&key), urlencode(&text)));
        }
        if !pairs.is_empty() {
            url.push('?');
            url.push_str(&pairs.join("&"));
        }
    }

    let mut config = vec![
        format!("url = \"{}\"", escape_curl(&url)),
        format!("request = \"{}\"", escape_curl(&request.method)),
        format!(
            "header = \"{}\"",
            escape_curl("Accept: application/vnd.cnb.api+json")
        ),
        format!(
            "header = \"{}\"",
            escape_curl(&format!("Authorization: Bearer {token}"))
        ),
    ];
    let payload = request.body.as_ref().map(|body| {
        if let Value::String(text) = body {
            text.clone()
        } else {
            body.to_string()
        }
    });
    if payload.is_some() {
        config.push(format!(
            "header = \"{}\"",
            escape_curl("Content-Type: application/json")
        ));
    }
    if let Some(payload) = payload.as_ref() {
        config.push(format!("data = \"{}\"", escape_curl(payload)));
    }

    let mut command = Command::new("curl");
    command
        .arg("--silent")
        .arg("--show-error")
        .arg("--max-time")
        .arg(CURL_TIMEOUT_SECS)
        .arg("--write-out")
        .arg(format!("{CURL_TRAILER}%{{http_code}}"))
        .arg("--config")
        .arg("-")
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped());
    if request.method == "GET" || request.method == "HEAD" {
        command.arg("--location");
    }

    let mut child = command
        .spawn()
        .map_err(|error| format!("codux-cnb: failed to start curl: {error}"))?;
    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(format!("{}\n", config.join("\n")).as_bytes())
            .map_err(|error| format!("codux-cnb: failed to send request: {error}"))?;
    }
    let output = child
        .wait_with_output()
        .map_err(|error| format!("codux-cnb: curl failed: {error}"))?;
    let stdout = String::from_utf8_lossy(&output.stdout);
    let stderr = String::from_utf8_lossy(&output.stderr);
    let (status, body) = parse_curl_output(&stdout);
    if !output.status.success() && status == 0 {
        return Err(format!(
            "codux-cnb: {}",
            stderr.trim().if_empty("curl failed")
        ));
    }
    if status >= 400 {
        let detail = parse_api_error(&body).unwrap_or_else(|| {
            body.trim()
                .chars()
                .take(240)
                .collect::<String>()
        });
        return Err(format!("codux-cnb: HTTP {status}: {detail}"));
    }
    if body.trim().is_empty() {
        return Ok(json!({ "ok": true, "status": status }));
    }
    serde_json::from_str(body.trim()).or_else(|_| Ok(json!({ "raw": body, "status": status })))
}

fn parse_curl_output(stdout: &str) -> (u16, String) {
    match stdout.rfind(CURL_TRAILER) {
        Some(at) => {
            let body = stdout[..at].to_string();
            let status = stdout[at + CURL_TRAILER.len()..]
                .lines()
                .next()
                .and_then(|line| line.trim().parse().ok())
                .unwrap_or(0);
            (status, body)
        }
        None => (0, stdout.to_string()),
    }
}

fn parse_api_error(body: &str) -> Option<String> {
    let value: Value = serde_json::from_str(body).ok()?;
    value
        .get("errmsg")
        .or_else(|| value.get("message"))
        .or_else(|| value.get("error"))
        .and_then(Value::as_str)
        .map(str::to_string)
}

fn escape_curl(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('"', "\\\"")
        .replace('\n', "\\n")
}

fn urlencode(value: &str) -> String {
    let mut encoded = String::new();
    for byte in value.as_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                encoded.push(*byte as char);
            }
            _ => encoded.push_str(&format!("%{byte:02X}")),
        }
    }
    encoded
}

trait IfEmpty {
    fn if_empty(self, fallback: &str) -> String;
}

impl IfEmpty for &str {
    fn if_empty(self, fallback: &str) -> String {
        if self.is_empty() {
            fallback.to_string()
        } else {
            self.to_string()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_https_and_ssh_cnb_remotes() {
        let https = parse_git_remote("https://cnb.cool/group/repo.git").unwrap();
        assert_eq!(https.site.id, "cool");
        assert_eq!(https.repo, "group/repo");

        let ssh = parse_git_remote("git@cnb.woa.com:org/app.git").unwrap();
        assert_eq!(ssh.site.id, "woa");
        assert_eq!(ssh.repo, "org/app");

        assert!(parse_git_remote("https://github.com/org/repo.git").is_none());
    }

    #[test]
    fn parse_remote_list_prefers_origin() {
        let parsed = parse_remote_list(
            "upstream\thttps://cnb.cool/other/repo.git (fetch)\n\
             origin\tgit@cnb.woa.com:team/app.git (fetch)\n",
        )
        .unwrap();
        assert_eq!(parsed.site.id, "woa");
        assert_eq!(parsed.repo, "team/app");
    }

    #[test]
    fn encode_repo_preserves_slashes() {
        assert_eq!(encode_repo("group/sub/repo"), "group/sub/repo");
    }

    #[test]
    fn parse_invoke_reads_flags_and_json() {
        let parsed = parse_invoke_args(&[
            "issues".into(),
            "--state".into(),
            "open".into(),
            "--page".into(),
            "2".into(),
        ])
        .unwrap();
        assert_eq!(parsed.command, "issues");
        assert_eq!(parsed.flags.get("state").and_then(Value::as_str), Some("open"));
        assert_eq!(parsed.flags.get("page").and_then(Value::as_str), Some("2"));
    }

    #[test]
    fn build_issue_comment_request() {
        let parsed = parse_invoke_args(&[
            "issue-comment".into(),
            "12".into(),
            "--body".into(),
            "looks good".into(),
        ])
        .unwrap();
        let request = build_request(
            &parsed,
            &CnbRemote {
                site: SITE_COOL,
                repo: "group/repo".into(),
            },
        )
        .unwrap();
        assert_eq!(request.method, "POST");
        assert_eq!(request.path, "/group/repo/-/issues/12/comments");
        assert_eq!(request.body, Some(json!({ "body": "looks good" })));
    }

    #[test]
    fn build_issue_comments_list_request() {
        let parsed = parse_invoke_args(&["issue-comments".into(), "12".into()]).unwrap();
        let request = build_request(
            &parsed,
            &CnbRemote {
                site: SITE_COOL,
                repo: "group/repo".into(),
            },
        )
        .unwrap();
        assert_eq!(request.method, "GET");
        assert_eq!(request.path, "/group/repo/-/issues/12/comments");
    }

    #[test]
    fn web_urls_match_cnb_site_paths() {
        assert_eq!(
            web_item_url(SITE_COOL, "group/repo", "issues", "12"),
            "https://cnb.cool/group/repo/-/issues/12"
        );
        assert_eq!(
            web_item_url(SITE_WOA, "org/app", "prs", "3"),
            "https://cnb.woa.com/org/app/-/pulls/3"
        );
        assert_eq!(
            web_item_url(SITE_COOL, "group/repo", "builds", "sn-1"),
            "https://cnb.cool/group/repo/-/build/sn-1"
        );
    }

    #[test]
    fn tokens_redact_secrets() {
        let tokens = CnbTokens {
            token_cool: "secret".into(),
            token_woa: String::new(),
        };
        let redacted = tokens.redacted();
        assert_eq!(redacted["tokenCoolConfigured"], true);
        assert_eq!(redacted["tokenWoaConfigured"], false);
        assert!(!redacted.to_string().contains("secret"));
    }
}
