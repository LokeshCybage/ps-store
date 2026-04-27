# commit-and-push

Execute the following steps in order. Do NOT skip steps. Stop and report to the user if any step fails.

## Step 1 — Analyze the Working Tree

1. Run `git status` to identify all staged, unstaged, and untracked files.
2. Run `git diff` (unstaged) and `git diff --cached` (staged) to understand what changed.
3. Run `git log -5 --oneline` to see recent commit style for message consistency.
4. Summarize the changes for the user in a brief overview before proceeding.

## Step 2 — Update .gitignore

1. Review untracked files for anything that should NOT be committed:
   - Secrets and credentials (`.env`, `*.pem`, `credentials.json`, `*.key`, tokens)
   - Build artifacts (`node_modules/`, `dist/`, `build/`, `__pycache__/`, `*.pyc`, `bin/`, `obj/`)
   - IDE and OS files (`.idea/`, `.vscode/`, `*.swp`, `Thumbs.db`, `.DS_Store`)
   - Logs (`*.log`, `logs/`)
   - Large binaries or data files that don't belong in source control
2. If any such files are found:
   - Read the existing `.gitignore` (or note that none exists).
   - Add the missing patterns, grouped by category with a short comment per group.
   - Write the updated `.gitignore` and confirm the additions with the user.
3. If `.gitignore` is already complete, state that no changes are needed and move on.

## Step 3 — Stage Files

1. Run `git add -A` to stage all relevant changes (including the `.gitignore` update if one was made).
2. Run `git status` again to confirm what will be committed.
3. If any files look suspicious (secrets, large binaries), warn the user and ask before continuing.

## Step 4 — Prepare Commit Message

Compose a commit message following these conventions:

- **Subject line**: imperative mood, max 72 characters, categorized with a prefix:
  `feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`, `style:`, `ci:`, `build:`, `perf:`
- **Body** (blank line after subject): explain *why* the change was made, not *what* (the diff shows what). Wrap at 72 characters. Include bullet points for multi-part changes.
- Match the style of recent commits when possible.

Present the full draft message to the user for approval before committing.

## Step 5 — Commit

1. After user approval (or if the user says to proceed without review), run the commit with the prepared message.
2. Verify the commit succeeded with `git log -1`.

## Step 6 — Push

1. Detect the current branch with `git branch --show-current`.
2. Check if an upstream is configured with `git status -sb`.
3. If no upstream exists, push with `git push -u origin <branch>`.
4. Otherwise, run `git push`.
5. Confirm push success and display the final status.

## Safety Rules

- NEVER force-push (`--force`, `--force-with-lease`) unless the user explicitly asks.
- NEVER commit files that look like secrets. Warn and wait for confirmation.
- NEVER amend a commit that has already been pushed.
- If any step fails, stop, report the error, and ask the user how to proceed.
