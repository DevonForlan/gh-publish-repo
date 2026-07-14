---
name: gh-publish-repo
description: Safely publish a local project folder to GitHub using Git and the GitHub CLI. Use when the user asks Codex to create a GitHub repository, initialize Git, inspect .gitignore, scan for sensitive files, commit, set origin, push main, or verify a GitHub upload. Also use for publishing Codex skills or reusable project folders to GitHub.
---

# GitHub Repo Publisher

## Overview

Use this skill to publish a local folder to GitHub with a safety-first workflow. Never display tokens, never force push, never delete repositories, and never replace an existing `origin` without explicit user approval.

## Required Inputs

Collect or infer:

- Local project folder path.
- Repository name.
- Visibility, defaulting to `public` only when the user explicitly asks for public or the repo is clearly meant for sharing.
- Commit message, defaulting to `Initial commit` for first publish.

If the folder path does not exist, stop and ask for the correct path. If GitHub authentication is unavailable, report exactly what is missing and do not attempt a partial publish.

## Preflight

Run the bundled preflight script before changing remote state:

```powershell
powershell -ExecutionPolicy Bypass -File "<skill-dir>/scripts/preflight-gh-publish.ps1" -ProjectPath "<project-path>"
```

Use the script output to decide whether publishing is safe. Treat `BLOCKED` findings as stop conditions unless the user explicitly resolves them. Treat `WARN` findings as items to review before continuing.

The preflight does not prove a project is secret-free. Also inspect likely sensitive files manually, especially `.env*`, config files, credential folders, generated archives, and seed data.

## Workflow

1. Resolve the absolute project path and `Set-Location` into it.
2. Run preflight.
3. Inspect `git status -sb`, `git remote -v`, and `.gitignore`.
4. Update `.gitignore` when needed. At minimum, exclude:
   - `.env`, `.env.*`, with `!.env.example` allowed
   - dependency folders such as `node_modules/`
   - build outputs such as `dist/`, `build/`
   - logs, caches, virtual environments, generated archives, dumps, secrets, certs
5. Initialize Git only when `.git` does not exist:
   - `git init`
   - `git branch -M main`
6. If Git already exists:
   - Confirm the current branch.
   - Do not overwrite or remove an existing `origin`.
   - If `origin` exists, verify it already points to the intended repository before pushing.
7. Stage intentionally with `git add`, then review `git status -sb`.
8. Commit if there are staged changes.
9. Verify GitHub CLI:
   - Prefer `gh` from PATH.
   - If missing on Windows, try `C:\Program Files\GitHub CLI\gh.exe`.
   - Run `gh auth status` without showing tokens.
10. Create the repository only after local safety checks pass:
   - `gh repo create <repo-name> --public --source . --remote origin --push`
   - If the repo should be private, use `--private`.
   - If `origin` already exists and is correct, use `gh repo create <repo-name> --public` separately only when needed, then `git push -u origin main`.
11. Verify:
   - `gh repo view <owner>/<repo> --json nameWithOwner,url,visibility,defaultBranchRef`
   - `git status -sb`
   - `git remote -v`
   - `git branch --show-current`

## Safety Rules

- Do not display tokens, secrets, credential helper output, or raw auth files.
- Do not run `git push --force` or `git push --force-with-lease`.
- Do not delete repositories.
- Do not rewrite an existing remote URL unless the user explicitly approves the exact old and new URLs.
- Do not commit files ignored by `.gitignore` using `git add -f` unless the user explicitly asks and the file is reviewed.
- Do not publish company-private or personal-sensitive material when preflight finds likely secrets or private data.

## Final Response

Report:

- Repository URL.
- Visibility.
- Default branch.
- Latest commit hash and message.
- Whether working tree is clean.
- Any skipped or unresolved checks.
