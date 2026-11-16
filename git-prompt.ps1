# ============================================================
# Prompt shows git branch and per-kind change counts, e.g.
#   PS D:\code\demo> (main)                     <- clean
#   PS D:\code\demo> (main)+3 *2                <- 3 staged, 2 modified
#   PS D:\code\demo> (main)?1                   <- 1 untracked file
#   PS D:\code\demo> (main)+1 *1 ?2             <- all kinds
# plain ASCII marks: '+' staged, '*' modified, '?' untracked
# Windows PowerShell 5.1 / PowerShell 7
# Based on: https://blog.csdn.net/aggresss/article/details/112131444
# ------------------------------------------------------------
# How it works:
#   * branch: read .git/HEAD directly (no git process spawn),
#     cached in $Global:GIT_NAME_HEAD so an unchanged HEAD is cheap
#   * counts: one `git status --porcelain` per prompt while inside
#     a repo; each output line is sorted into staged / modified /
#     untracked. No extra git calls.
#     (set GIT_PROMPT_DIRTY_TTL_MS > 0 to throttle the check)
# Type `git_prompt` in a session to toggle it on/off.
# ============================================================

# ---------- user tunables ----------
# All marks are plain ASCII on purpose: non-ASCII symbols (U+2714 "check",
# U+270E pencil, U+221A, ...) can be drawn from a colour-emoji font (ignores
# -ForegroundColor) or be treated as wide characters (overlaps the number).
# Any short ASCII string works, e.g. staged '+', modified '~' or 'M'.
$Global:GIT_PROMPT_DIRTY_MARK = ''               # optional leading mark, e.g. '!' , '*' or [char]0x26A1 (bolt)
$Global:GIT_PROMPT_STAGED_MARK = '+'             # staged (git add'ed)
$Global:GIT_PROMPT_MODIFIED_MARK = '*'           # modified, not staged
$Global:GIT_PROMPT_UNTRACKED_MARK = '?'          # untracked files
$Global:GIT_PROMPT_COUNT_SEP = ''                # gap between mark and number (' ' = spaced)
$Global:GIT_PROMPT_SHOW_UNTRACKED = $true        # $false = ignore untracked completely
$Global:GIT_PROMPT_DIRTY_TTL_MS = 0              # 0 = check every prompt; e.g. 800 to throttle
$Global:GIT_PROMPT_SHOW_DIRTY = $true
$Global:GIT_PROMPT_BRANCH_PREFIX = '('
$Global:GIT_PROMPT_BRANCH_SUFFIX = ')'
# -----------------------------------

function git_branch_internal {
  $dir = $PWD.Path
  $root = $null
  do {
    if (Test-Path "${dir}/.git/HEAD") { $root = $dir; break }
    ${dir} = Split-Path -Parent -Path "${dir}"
  } while (${dir})

  if (-not $root) {
    $Global:GIT_NAME_HEAD = ''
    $Global:GIT_NAME_TITLE = ''
    $Global:GIT_NAME_CONTENT = ''
    $Global:GIT_DIRTY = $false
    $Global:GIT_STAGED_COUNT = 0
    $Global:GIT_MODIFIED_COUNT = 0
    $Global:GIT_UNTRACKED_COUNT = 0
    $Global:GIT_DIRTY_ROOT = ''
    return
  }

  # --- which branch / tag / commit ---
  $head = Get-Content "${root}/.git/HEAD"
  if ($head -ne $Global:GIT_NAME_HEAD) {
    $Global:GIT_NAME_HEAD = $head
    if ($head -match '^ref: refs/heads/(?<branch>.*)') {
      $Global:GIT_NAME_TITLE = 'branch'
      $Global:GIT_NAME_CONTENT = $Matches.branch
    }
    else {
      $describe = $(git describe --tags --abbrev=7 2> $null)
      if ($describe) {
        $Global:GIT_NAME_TITLE = 'tag'
        $Global:GIT_NAME_CONTENT = $describe
      }
      else {
        $Global:GIT_NAME_TITLE = 'commit'
        $Global:GIT_NAME_CONTENT = $head.Substring(0, 7)
      }
    }
  }

  # --- any changes? sort them into staged / modified / untracked ---
  if ($Global:GIT_PROMPT_SHOW_DIRTY) {
    $now = [Environment]::TickCount
    $check = $true
    if ($Global:GIT_PROMPT_DIRTY_TTL_MS -gt 0 -and
        $Global:GIT_DIRTY_STAMP -and
        $Global:GIT_DIRTY_ROOT -eq $root -and
        (($now - $Global:GIT_DIRTY_STAMP) -lt $Global:GIT_PROMPT_DIRTY_TTL_MS)) {
      $check = $false
    }
    if ($check) {
      # one git process: porcelain XY columns tell the kind of change
      $status = & git --no-optional-locks status --porcelain 2> $null
      $staged = 0
      $modified = 0
      $untracked = 0
      foreach ($line in @($status)) {
        if ($null -eq $line -or $line.Length -lt 2) { continue }
        $x = $line.Substring(0, 1)
        $y = $line.Substring(1, 1)
        if ($x -eq '?' -and $y -eq '?') { $untracked++ }
        else {
          if ($x -ne ' ' -and $x -ne '?') { $staged++ }
          if ($y -ne ' ' -and $y -ne '?') { $modified++ }
        }
      }
      $Global:GIT_STAGED_COUNT = $staged
      $Global:GIT_MODIFIED_COUNT = $modified
      $Global:GIT_UNTRACKED_COUNT = $untracked
      $dirty = $staged + $modified
      if ($Global:GIT_PROMPT_SHOW_UNTRACKED) { $dirty += $untracked }
      $Global:GIT_DIRTY = $dirty -gt 0
      $Global:GIT_DIRTY_STAMP = $now
      $Global:GIT_DIRTY_ROOT = $root
    }
  }
}

function prompt_custom {
  git_branch_internal
  Write-Host $(prompt_bak) -NoNewline
  if ($Global:GIT_NAME_CONTENT) {
    Write-Host $Global:GIT_PROMPT_BRANCH_PREFIX -ForegroundColor Cyan -NoNewline
    if ($Global:GIT_NAME_TITLE -eq 'branch') {
      Write-Host $Global:GIT_NAME_CONTENT -ForegroundColor Yellow -NoNewline
    }
    else {
      Write-Host "${GIT_NAME_TITLE}:" -ForegroundColor DarkGray -NoNewline
      Write-Host $Global:GIT_NAME_CONTENT -ForegroundColor Yellow -NoNewline
    }
    Write-Host $Global:GIT_PROMPT_BRANCH_SUFFIX -ForegroundColor Cyan -NoNewline

    if ($Global:GIT_PROMPT_SHOW_DIRTY) {
      $sep = $false
      if ($Global:GIT_PROMPT_DIRTY_MARK -and $Global:GIT_DIRTY) {
        Write-Host $Global:GIT_PROMPT_DIRTY_MARK -ForegroundColor Red -NoNewline
        $sep = $true
      }
      if ($Global:GIT_STAGED_COUNT -gt 0) {
        if ($sep) { Write-Host ' ' -NoNewline }
        Write-Host ($Global:GIT_PROMPT_STAGED_MARK + $Global:GIT_PROMPT_COUNT_SEP + $Global:GIT_STAGED_COUNT) -ForegroundColor Green -NoNewline
        $sep = $true
      }
      if ($Global:GIT_MODIFIED_COUNT -gt 0) {
        if ($sep) { Write-Host ' ' -NoNewline }
        Write-Host ($Global:GIT_PROMPT_MODIFIED_MARK + $Global:GIT_PROMPT_COUNT_SEP + $Global:GIT_MODIFIED_COUNT) -ForegroundColor Yellow -NoNewline
        $sep = $true
      }
      if ($Global:GIT_PROMPT_SHOW_UNTRACKED -and $Global:GIT_UNTRACKED_COUNT -gt 0) {
        if ($sep) { Write-Host ' ' -NoNewline }
        Write-Host ($Global:GIT_PROMPT_UNTRACKED_MARK + $Global:GIT_PROMPT_COUNT_SEP + $Global:GIT_UNTRACKED_COUNT) -ForegroundColor DarkGray -NoNewline
      }
    }
  }
  # prompt must return a non-empty string, otherwise PowerShell
  # falls back to its built-in prompt
  return ' '
}

function git_prompt {
  if (Get-Command prompt_bak -ErrorAction SilentlyContinue) {
    Copy-Item Function::Global:prompt_bak Function::Global:prompt
    Remove-Item Function::prompt_bak
    $Global:GIT_NAME_HEAD = ''
    $Global:GIT_DIRTY_STAMP = 0
    $Global:GIT_STAGED_COUNT = 0
    $Global:GIT_MODIFIED_COUNT = 0
    $Global:GIT_UNTRACKED_COUNT = 0
  }
  else {
    Copy-Item Function::Global:prompt Function::Global:prompt_bak
    Copy-Item Function::Global:prompt_custom Function::Global:prompt
  }
}

git_prompt
