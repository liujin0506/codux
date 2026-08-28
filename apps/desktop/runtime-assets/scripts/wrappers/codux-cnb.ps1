$ErrorActionPreference = "Stop"
$argv = @($args)
$command = if ($argv.Count -gt 0) { [string]$argv[0] } else { "" }
$wrapperDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($wrapperDir.StartsWith('\\?\UNC\')) { $wrapperDir = '\\' + $wrapperDir.Substring(8) }
elseif ($wrapperDir.StartsWith('\\?\')) { $wrapperDir = $wrapperDir.Substring(4) }
$helper = Join-Path $wrapperDir "codux-wrapper-helper.exe"

function Usage {
  Write-Host "usage: codux-cnb status"
  Write-Host "       codux-cnb whoami"
  Write-Host "       codux-cnb issues [--state open|closed|all] [--page N]"
  Write-Host "       codux-cnb issue <number>"
  Write-Host "       codux-cnb issue-create --title <title> [--body <markdown>]"
  Write-Host "       codux-cnb prs|pr|pr-create|pr-comment|pr-merge|pr-review"
  Write-Host "       codux-cnb builds|build|build-start|build-stop"
  Write-Host "       codux-cnb api <METHOD> <path> [--json '{...}']"
  Write-Host ""
  Write-Host "CNB tokens stay inside Codux. Run 'codux-cnb status' first."
}

if ($command -eq "-h" -or $command -eq "--help" -or $command -eq "help") {
  Usage
  exit 0
}

if (-not (Test-Path $helper)) {
  [Console]::Error.WriteLine("codux-cnb: bundled helper is missing")
  exit 127
}

$tokensFile = $env:CODUX_CNB_TOKENS_FILE
if ([string]::IsNullOrWhiteSpace($tokensFile) -and -not [string]::IsNullOrWhiteSpace($env:DMUX_APP_SUPPORT_ROOT)) {
  $tokensFile = Join-Path $env:DMUX_APP_SUPPORT_ROOT "cnb_tokens.json"
}
if ([string]::IsNullOrWhiteSpace($tokensFile)) {
  $tokensFile = Join-Path $env:APPDATA "Codux\cnb_tokens.json"
}

$env:CODUX_CNB_TOKENS_FILE = $tokensFile
& $helper --codux-wrapper-helper cnb-invoke @argv
exit $LASTEXITCODE
