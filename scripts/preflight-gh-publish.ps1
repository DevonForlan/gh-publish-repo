param(
  [Parameter(Mandatory=$true)]
  [string]$ProjectPath
)

$ErrorActionPreference = "Stop"

function Write-Result {
  param(
    [string]$Level,
    [string]$Message
  )
  Write-Output ("[{0}] {1}" -f $Level, $Message)
}

function Resolve-Gh {
  $cmd = Get-Command gh -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  $commonPaths = @(
    "C:\Program Files\GitHub CLI\gh.exe",
    "$env:LOCALAPPDATA\Programs\GitHub CLI\gh.exe"
  )

  foreach ($path in $commonPaths) {
    if (Test-Path -LiteralPath $path) {
      return $path
    }
  }

  return $null
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
  Write-Result "BLOCKED" "Project path does not exist: $ProjectPath"
  exit 2
}

$resolvedProject = (Resolve-Path -LiteralPath $ProjectPath).Path
Write-Result "OK" "Project path: $resolvedProject"

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
  Write-Result "BLOCKED" "git command is not available."
} else {
  Write-Result "OK" "git: $($gitCmd.Source)"
}

$ghPath = Resolve-Gh
if (-not $ghPath) {
  Write-Result "BLOCKED" "GitHub CLI is not available as gh or in common Windows install paths."
} else {
  Write-Result "OK" "GitHub CLI: $ghPath"
}

Push-Location -LiteralPath $resolvedProject
try {
  if (Test-Path -LiteralPath ".git" -PathType Container) {
    Write-Result "OK" "Git repository already exists."
    git status -sb
    git remote -v
  } else {
    Write-Result "WARN" "No .git directory found. Repository will need git init."
  }

  if (Test-Path -LiteralPath ".gitignore" -PathType Leaf) {
    Write-Result "OK" ".gitignore exists."
  } else {
    Write-Result "WARN" ".gitignore is missing."
  }

  $blockedNames = @(
    ".env",
    ".env.local",
    ".env.production",
    "id_rsa",
    "id_ed25519"
  )

  foreach ($name in $blockedNames) {
    $matches = Get-ChildItem -LiteralPath . -Force -Recurse -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -eq $name -and $_.FullName -notmatch "\\.git\\" }
    foreach ($match in $matches) {
      Write-Result "BLOCKED" "Sensitive-looking file found: $($match.FullName)"
    }
  }

  $warnRegex = "\.(zip|7z|rar|dump|backup|pem|key|p12|pfx)$|\.sql\.gz$"
  $warnMatches = Get-ChildItem -LiteralPath . -Force -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\.git\\" -and $_.Name -match $warnRegex }
  foreach ($match in $warnMatches) {
    Write-Result "WARN" "Review generated/archive/credential-like file: $($match.FullName)"
  }

  $secretRegex = "(ghp_|github_pat_|glpat-|xox[baprs]-|sk-[A-Za-z0-9]|AKIA[0-9A-Z]{16}|BEGIN (RSA|OPENSSH|PRIVATE) KEY|password\s*=|api[_-]?key\s*=|secret\s*=|token\s*=)"
  $scanFiles = Get-ChildItem -LiteralPath . -Force -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object {
      $_.FullName -notmatch "\\.git\\" -and
      $_.FullName -notmatch "\\node_modules\\" -and
      $_.FullName -notmatch "\\dist\\" -and
      $_.FullName -notmatch "\\build\\" -and
      $_.Length -lt 2MB
    }

  foreach ($file in $scanFiles) {
    try {
      $hit = Select-String -LiteralPath $file.FullName -Pattern $secretRegex -AllMatches -ErrorAction Stop |
        Where-Object { $_.Line -notmatch "secretRegex" } |
        Select-Object -First 1
      if ($hit) {
        Write-Result "BLOCKED" "Possible secret pattern in $($file.FullName):$($hit.LineNumber)"
      }
    } catch {
      Write-Result "WARN" "Could not scan file: $($file.FullName)"
    }
  }
} finally {
  Pop-Location
}

Write-Result "OK" "Preflight complete. Review BLOCKED and WARN lines before publishing."
