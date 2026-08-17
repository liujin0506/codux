//! `codux update` — check GitHub Releases for a newer build, then download,
//! verify, atomically replace this binary, and restart the host if it was up.

use dialoguer::Confirm;
use dialoguer::theme::ColorfulTheme;
use semver::Version;
use serde::Deserialize;
use std::time::Duration;

use crate::{cmd_service, cmd_start, runstate};

const LATEST_RELEASE_API: &str = "https://api.github.com/repos/liujin0506/codux/releases/latest";
const RELEASES_API: &str = "https://api.github.com/repos/liujin0506/codux/releases";
const STABLE_MANIFEST_URL: &str =
    "https://raw.githubusercontent.com/liujin0506/codux/main/updates/stable/latest.json";
const BETA_MANIFEST_URL: &str =
    "https://raw.githubusercontent.com/liujin0506/codux/main/updates/beta/latest.json";
const REPO_DOWNLOAD_BASE: &str = "https://github.com/liujin0506/codux/releases/download";
const USER_AGENT: &str = "codux-agent-updater";

#[derive(Deserialize)]
struct Release {
    tag_name: String,
    #[serde(default)]
    prerelease: bool,
    #[serde(default)]
    assets: Vec<Asset>,
}

#[derive(Deserialize)]
struct Asset {
    name: String,
    browser_download_url: String,
}

#[derive(Deserialize)]
struct UpdateManifest {
    version: String,
}

pub fn run(current: &str, beta: bool) -> Result<(), String> {
    let client = reqwest::blocking::Client::builder()
        .user_agent(USER_AGENT)
        .timeout(Duration::from_secs(30))
        .build()
        .map_err(|error| error.to_string())?;

    println!("Checking for {}updates…", if beta { "beta " } else { "" });
    let release = fetch_release(&client, beta)?;

    let latest = release.tag_name.trim_start_matches('v');
    if !is_newer(latest, current) {
        println!("Already up to date (v{current}).");
        return Ok(());
    }
    println!("A newer version is available: v{latest} (current v{current}).");

    let asset = pick_asset(&release.assets, latest)?;
    let proceed = Confirm::with_theme(&ColorfulTheme::default())
        .with_prompt(format!("Download and install {} now?", asset.name))
        .default(true)
        .interact()
        .map_err(|error| error.to_string())?;
    if !proceed {
        println!("Update cancelled.");
        return Ok(());
    }

    let was_running = runstate::is_running();
    println!("Downloading {}…", asset.name);
    let bytes = download_asset(&client, &release.assets, latest, &asset.name)?;
    if bytes.is_empty() {
        return Err("downloaded an empty file".to_string());
    }

    replace_self(&bytes)?;
    println!("Installed v{latest}.");

    if was_running {
        println!("Restarting the host…");
        let _ = cmd_service::stop();
        std::thread::sleep(Duration::from_millis(400));
        cmd_start::run(true)?;
    }
    Ok(())
}

fn fetch_release(client: &reqwest::blocking::Client, beta: bool) -> Result<Release, String> {
    if !beta {
        return fetch_manifest_release(client, STABLE_MANIFEST_URL, Channel::Stable).or_else(
            |error| {
                eprintln!(
                    "warning: stable manifest lookup failed: {error}; falling back to GitHub releases API"
                );
                fetch_latest_release(client)
            },
        );
    }

    match fetch_manifest_release(client, BETA_MANIFEST_URL, Channel::Beta) {
        Ok(release) => return Ok(release),
        Err(error) => eprintln!(
            "warning: beta manifest lookup failed: {error}; falling back to GitHub releases API"
        ),
    }

    let releases = client
        .get(RELEASES_API)
        .send()
        .map_err(|error| format!("failed to reach GitHub: {error}"))?
        .error_for_status()
        .map_err(|error| format!("release lookup failed: {error}"))?
        .json::<Vec<Release>>()
        .map_err(|error| format!("invalid release payload: {error}"))?;
    select_beta_release(releases)
}

fn fetch_latest_release(client: &reqwest::blocking::Client) -> Result<Release, String> {
    client
        .get(LATEST_RELEASE_API)
        .send()
        .map_err(|error| format!("failed to reach GitHub: {error}"))?
        .error_for_status()
        .map_err(|error| format!("release lookup failed: {error}"))?
        .json()
        .map_err(|error| format!("invalid release payload: {error}"))
}

#[derive(Clone, Copy)]
enum Channel {
    Stable,
    Beta,
}

fn fetch_manifest_release(
    client: &reqwest::blocking::Client,
    manifest_url: &str,
    channel: Channel,
) -> Result<Release, String> {
    let manifest = client
        .get(manifest_url)
        .send()
        .map_err(|error| format!("failed to reach manifest: {error}"))?
        .error_for_status()
        .map_err(|error| format!("manifest lookup failed: {error}"))?
        .json::<UpdateManifest>()
        .map_err(|error| format!("invalid manifest payload: {error}"))?;
    release_from_manifest_version(&manifest.version, channel)
}

fn release_from_manifest_version(version: &str, channel: Channel) -> Result<Release, String> {
    let version = version.trim().trim_start_matches('v');
    // The beta channel tracks whatever is newest: publish-github-release.mjs
    // deliberately refreshes the beta manifest on stable releases too, so beta
    // hosts are never stranded behind stable. Only the reverse is an error.
    if matches!(channel, Channel::Stable) && version.contains("-beta") {
        return Err(format!("stable manifest version is a beta: {version}"));
    }
    let tag_name = format!("v{version}");
    Ok(Release {
        tag_name: tag_name.clone(),
        prerelease: false,
        assets: agent_assets_for_version(version, &tag_name),
    })
}

fn agent_assets_for_version(version: &str, tag_name: &str) -> Vec<Asset> {
    ["macos", "linux", "windows"]
        .into_iter()
        .flat_map(|os| {
            ["aarch64", "x86_64"]
                .into_iter()
                .filter(move |arch| !(os == "windows" && *arch == "aarch64"))
                .flat_map(move |arch| agent_asset_names(version, os, arch))
        })
        .map(|name| Asset {
            browser_download_url: release_asset_url(tag_name, &name),
            name,
        })
        .collect()
}

fn agent_asset_names(version: &str, os: &str, arch: &str) -> Vec<String> {
    let extension = if os == "windows" { ".exe" } else { "" };
    vec![
        format!("codux-agent-{version}-{os}-{arch}{extension}"),
        format!("codux-{os}-{arch}{extension}"),
    ]
}

fn release_asset_url(tag_name: &str, asset_name: &str) -> String {
    format!("{REPO_DOWNLOAD_BASE}/{tag_name}/{asset_name}")
}

fn select_beta_release(releases: Vec<Release>) -> Result<Release, String> {
    releases
        .into_iter()
        .find(|release| release.prerelease || release_tag_is_beta(&release.tag_name))
        .ok_or_else(|| "no beta release found".to_string())
}

fn release_tag_is_beta(tag_name: &str) -> bool {
    tag_name.trim_start_matches('v').contains("-beta")
}

/// Choose the release asset for this OS + architecture.
fn pick_asset<'a>(assets: &'a [Asset], version: &str) -> Result<&'a Asset, String> {
    asset_candidates(assets, version)
        .into_iter()
        .next()
        .ok_or_else(|| {
            let expected = versioned_agent_asset_name(version);
            let legacy = legacy_agent_asset_name();
            let available = assets
                .iter()
                .map(|asset| asset.name.as_str())
                .collect::<Vec<_>>()
                .join(", ");
            format!("no release asset for {expected} or {legacy} (available: {available})")
        })
}

fn download_asset(
    client: &reqwest::blocking::Client,
    assets: &[Asset],
    version: &str,
    preferred_name: &str,
) -> Result<Vec<u8>, String> {
    let mut candidates = asset_candidates(assets, version);
    if candidates.is_empty() {
        return Err(format!("no release asset candidates for v{version}"));
    }
    if let Some(index) = candidates
        .iter()
        .position(|asset| asset.name == preferred_name)
    {
        let preferred = candidates.remove(index);
        candidates.insert(0, preferred);
    }

    let mut last_error = String::new();
    for asset in candidates {
        match client.get(&asset.browser_download_url).send() {
            Ok(response) => {
                if response.status() == reqwest::StatusCode::NOT_FOUND {
                    last_error = format!("{}: not found", asset.name);
                    continue;
                }
                match response.error_for_status() {
                    Ok(response) => match response.bytes() {
                        Ok(bytes) if bytes.is_empty() => {
                            last_error = format!("{}: downloaded an empty file", asset.name);
                        }
                        Ok(bytes) => return Ok(bytes.to_vec()),
                        Err(error) => last_error = format!("{}: {error}", asset.name),
                    },
                    Err(error) => last_error = format!("{}: {error}", asset.name),
                }
            }
            Err(error) => last_error = format!("{}: failed to reach GitHub: {error}", asset.name),
        }
    }
    Err(format!("download failed: {last_error}"))
}

fn asset_candidates<'a>(assets: &'a [Asset], version: &str) -> Vec<&'a Asset> {
    [versioned_agent_asset_name(version), legacy_agent_asset_name()]
        .into_iter()
        .filter_map(|name| assets.iter().find(|asset| asset.name == name))
        .collect()
}

fn versioned_agent_asset_name(version: &str) -> String {
    let os = std::env::consts::OS;
    let extension = if os == "windows" { ".exe" } else { "" };
    format!(
        "codux-agent-{version}-{os}-{}{extension}",
        std::env::consts::ARCH
    )
}

fn legacy_agent_asset_name() -> String {
    let os = std::env::consts::OS;
    let extension = if os == "windows" { ".exe" } else { "" };
    format!("codux-{os}-{}{extension}", std::env::consts::ARCH)
}

/// Atomically replace the running executable with `bytes`.
fn replace_self(bytes: &[u8]) -> Result<(), String> {
    let exe = std::env::current_exe().map_err(|error| error.to_string())?;
    let dir = exe.parent().ok_or("cannot resolve binary directory")?;
    let staged = dir.join(".codux.update.new");
    std::fs::write(&staged, bytes).map_err(|error| format!("failed to write update: {error}"))?;

    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let mut perms = std::fs::metadata(&staged)
            .map_err(|error| error.to_string())?
            .permissions();
        perms.set_mode(0o755);
        let _ = std::fs::set_permissions(&staged, perms);
        // Renaming over the running binary is allowed on unix.
        std::fs::rename(&staged, &exe)
            .map_err(|error| format!("failed to replace binary: {error}"))?;
    }

    #[cfg(windows)]
    {
        // A running .exe can't be overwritten, but it can be renamed aside.
        let old = dir.join(".codux.old.exe");
        let _ = std::fs::remove_file(&old);
        std::fs::rename(&exe, &old)
            .map_err(|error| format!("failed to move current binary: {error}"))?;
        std::fs::rename(&staged, &exe)
            .map_err(|error| format!("failed to install update: {error}"))?;
    }

    Ok(())
}

/// Numeric dotted-version comparison (`a` strictly newer than `b`).
fn is_newer(a: &str, b: &str) -> bool {
    match (Version::parse(a), Version::parse(b)) {
        (Ok(latest), Ok(current)) => latest > current,
        _ => a > b,
    }
}

#[cfg(test)]
mod tests {
    use super::{
        Asset, Channel, Release, asset_candidates, is_newer, pick_asset,
        release_from_manifest_version, release_tag_is_beta, select_beta_release,
        versioned_agent_asset_name, legacy_agent_asset_name,
    };

    #[test]
    fn newer_version_compares_numeric_parts() {
        assert!(is_newer("1.10.0", "1.9.9"));
        assert!(!is_newer("1.9.0", "1.9.0"));
        assert!(!is_newer("1.8.9", "1.9.0"));
        assert!(is_newer("2.0.0-rc.1", "2.0.0-beta.10"));
    }

    #[test]
    fn pick_asset_ignores_desktop_assets() {
        let expected = current_agent_asset_name("1.9.1");
        let assets = vec![
            asset("codux-1.9.1-macos-aarch64.dmg"),
            asset("codux-1.9.1-windows-x86_64-setup.exe"),
            asset(&expected),
        ];

        assert_eq!(pick_asset(&assets, "1.9.1").unwrap().name, expected);
    }

    #[test]
    fn pick_asset_falls_back_to_legacy_agent_alias() {
        let legacy = current_legacy_agent_asset_name();
        let assets = vec![asset(&legacy)];

        assert_eq!(pick_asset(&assets, "1.9.1").unwrap().name, legacy);
    }

    #[test]
    fn asset_candidates_prefer_versioned_asset_name() {
        let version = "2.0.12";
        let versioned = current_agent_asset_name(version);
        let legacy = current_legacy_agent_asset_name();
        let assets = vec![asset(&legacy), asset(&versioned)];

        let candidates = asset_candidates(&assets, version);

        assert_eq!(candidates.len(), 2);
        assert_eq!(candidates[0].name, versioned);
        assert_eq!(candidates[1].name, legacy);
    }

    #[test]
    fn manifest_release_synthesizes_agent_assets() {
        let release = release_from_manifest_version("2.0.0-beta.10", Channel::Beta).unwrap();
        let expected = current_agent_asset_name("2.0.0-beta.10");

        assert_eq!(release.tag_name, "v2.0.0-beta.10");
        assert!(release.assets.iter().any(|asset| asset.name == expected));
        assert!(release.assets.iter().any(|asset| {
            asset.browser_download_url
                == format!(
                    "https://github.com/liujin0506/codux/releases/download/v2.0.0-beta.10/{expected}"
                )
        }));
    }

    #[test]
    fn beta_manifest_release_accepts_stable_versions() {
        // A stable release refreshes the beta manifest as well, so a beta host
        // must be able to update onto it.
        let release = release_from_manifest_version("2.0.8", Channel::Beta).unwrap();
        let expected = current_agent_asset_name("2.0.8");

        assert_eq!(release.tag_name, "v2.0.8");
        assert!(release.assets.iter().any(|asset| asset.name == expected));
    }

    #[test]
    fn stable_manifest_release_accepts_rc_versions() {
        let release = release_from_manifest_version("2.0.0-rc.1", Channel::Stable).unwrap();
        let expected = current_agent_asset_name("2.0.0-rc.1");

        assert_eq!(release.tag_name, "v2.0.0-rc.1");
        assert!(release.assets.iter().any(|asset| asset.name == expected));
    }

    #[test]
    fn stable_manifest_release_rejects_beta_versions() {
        let error = match release_from_manifest_version("2.0.0-beta.11", Channel::Stable) {
            Ok(_) => panic!("expected beta manifest version to fail"),
            Err(error) => error,
        };

        assert_eq!(error, "stable manifest version is a beta: 2.0.0-beta.11");
    }

    #[test]
    fn select_beta_release_uses_first_beta_release() {
        let stable = release("v2.0.0", false);
        let beta = release("v2.1.0-beta.1", false);
        let older_prerelease_beta = release("v2.0.0-beta.5", true);

        let selected = select_beta_release(vec![stable, beta, older_prerelease_beta]).unwrap();

        assert_eq!(selected.tag_name, "v2.1.0-beta.1");
    }

    #[test]
    fn release_tag_beta_detection_ignores_stable_versions() {
        assert!(release_tag_is_beta("v2.0.0-beta.10"));
        assert!(!release_tag_is_beta("v2.0.0"));
    }

    #[test]
    fn select_beta_release_requires_beta_tag_or_prerelease() {
        let error = match select_beta_release(vec![release("v2.0.0", false)]) {
            Ok(_) => panic!("expected missing beta release to fail"),
            Err(error) => error,
        };

        assert_eq!(error, "no beta release found");
    }

    fn current_agent_asset_name(version: &str) -> String {
        versioned_agent_asset_name(version)
    }

    fn current_legacy_agent_asset_name() -> String {
        legacy_agent_asset_name()
    }

    fn asset(name: &str) -> Asset {
        Asset {
            name: name.to_string(),
            browser_download_url: format!("https://example.com/{name}"),
        }
    }

    fn release(tag_name: &str, prerelease: bool) -> Release {
        Release {
            tag_name: tag_name.to_string(),
            prerelease,
            assets: Vec::new(),
        }
    }
}
