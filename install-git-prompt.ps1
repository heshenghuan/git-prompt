<#
.SYNOPSIS
  Install git-prompt.ps1 into a PowerShell profile, or remove it again.

.DESCRIPTION
  The snippet is appended between the markers
    # >>> git-prompt >>>
    # <<< git-prompt <<<
  so it can be removed cleanly. Running the script twice is safe.
  Before changing an existing profile, a backup copy named
  <profile>.bak-<timestamp> is written next to it.

.EXAMPLE
  .\install-git-prompt.ps1
  Installs into the current user's Windows PowerShell 5.1 profile:
  C:\Users\<you>\Documents\WindowsPowerShell\profile.ps1

.EXAMPLE
  .\install-git-prompt.ps1 -Uninstall
  Removes the git-prompt block from the profile.

.EXAMPLE
  .\install-git-prompt.ps1 -ProfileFile C:\Users\you\Documents\PowerShell\profile.ps1
  Installs into the PowerShell 7 profile instead.
#>
param(
  [string]$ProfileFile = $PROFILE.CurrentUserAllHosts,
  [string]$SnippetFile = (Join-Path $PSScriptRoot 'git-prompt.ps1'),
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$begin = '# >>> git-prompt >>>'
$end = '# <<< git-prompt <<<'

function Read-FileText([string]$path) {
  if (Test-Path -LiteralPath $path) { return (Get-Content -Raw -LiteralPath $path) }
  return ''
}

$text = Read-FileText $ProfileFile
$hasBlock = $text.Contains($begin)

if ($Uninstall) {
  if (-not $hasBlock) { "Not installed, nothing to remove: $ProfileFile"; return }
  $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end) + '\r?\n?'
  $new = [regex]::Replace($text, $pattern, '')
  $new = $new.TrimEnd() + "`r`n"
  [System.IO.File]::WriteAllText($ProfileFile, $new, (New-Object System.Text.UTF8Encoding($false)))
  "Removed the git-prompt block from: $ProfileFile"
  "Open a new terminal to apply."
  return
}

if ($hasBlock) { "Already installed in: $ProfileFile"; return }

if (-not (Test-Path -LiteralPath $SnippetFile)) { throw "Snippet not found: $SnippetFile" }

$dir = Split-Path -Parent $ProfileFile
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

if (Test-Path -LiteralPath $ProfileFile) {
  $backup = "$ProfileFile.bak-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
  Copy-Item -LiteralPath $ProfileFile -Destination $backup
  "Backup written: $backup"
}

$snippet = (Get-Content -Raw -LiteralPath $SnippetFile).TrimEnd()
$new = $text.TrimEnd() + "`r`n`r`n" + $begin + "`r`n" + $snippet + "`r`n" + $end + "`r`n"
[System.IO.File]::WriteAllText($ProfileFile, $new, (New-Object System.Text.UTF8Encoding($false)))

"Installed into: $ProfileFile"
"Open a new PowerShell window (or run: . `$PROFILE) to apply."
"Type git_prompt in a session to toggle the branch display on/off."
