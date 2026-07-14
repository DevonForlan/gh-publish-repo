# GitHub Repo Publisher

A Codex skill for safely publishing a local project folder to GitHub with Git and the GitHub CLI.

## What It Does

- Checks the target project path before publishing.
- Runs a preflight scan for missing tools, existing Git state, sensitive-looking files, generated archives, and common secret patterns.
- Helps initialize Git when needed.
- Adds or verifies a safe `.gitignore`.
- Creates a public GitHub repository with the currently authenticated GitHub account.
- Sets `origin`, pushes `main`, and verifies the published repository.

## Safety Rules

This skill is designed to avoid risky GitHub publishing behavior:

- Never display tokens or raw credential files.
- Never force push.
- Never delete repositories.
- Never replace an existing `origin` without explicit approval.
- Stop when preflight reports `BLOCKED` findings.

## Usage

Ask Codex to use the skill with a local project path and repository name:

```text
Use $gh-publish-repo to publish this project to GitHub:
C:\path\to\project

Repository name:
my-project
```

For public repositories, explicitly request public visibility. For private repositories, request private visibility.

## Requirements

- Git
- GitHub CLI
- An authenticated GitHub CLI session

On Windows, the skill checks both `gh` from `PATH` and common GitHub CLI install paths such as:

```text
C:\Program Files\GitHub CLI\gh.exe
```

## Included Files

- `SKILL.md` - Codex skill instructions.
- `scripts/preflight-gh-publish.ps1` - Preflight safety script.
- `agents/openai.yaml` - Skill display metadata.

