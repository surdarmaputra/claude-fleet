---
name: commit
description: Stage and commit changes using the Conventional Commits format
---

Stage all modified and untracked files (excluding gitignored paths), then create a git commit whose message follows the Conventional Commits 1.0 specification.

## Message format

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

## Type (pick one)

| Type | When to use |
|------|-------------|
| `feat` | A new feature visible to users or callers |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `chore` | Build process, tooling, dependency updates |
| `ci` | CI/CD configuration |
| `revert` | Reverts a previous commit |

## Rules

- Subject line: 72 chars max, lowercase, no trailing period, imperative mood ("add" not "adds" / "added")
- If there is a breaking change, append `!` after the type/scope and add `BREAKING CHANGE: <explanation>` in the footer
- Scope is optional; use it only when it meaningfully narrows the type (e.g. `feat(tasks):`)
- Body is optional; use it to explain *why*, not *what* — the diff already shows what changed
- Separate subject, body, and footers with blank lines

## Steps

1. Run `git status` to see what has changed
2. Run `git diff` (staged + unstaged) to read the actual changes
3. Choose the correct type and write a subject line that completes the sentence "If applied, this commit will…"
4. Stage relevant files: prefer `git add <specific files>` over `git add -A`; never stage `.env`, secrets, or large binaries
5. Commit with the composed message
6. Confirm success with `git status`

## Examples

```
feat(tasks): add --host filter to fleet tasks command
fix: resolve symlink before computing SCRIPT_DIR
docs: document global fleet CLI invocation in README
refactor(spawn): extract session-name logic into helper
chore: bump tmux minimum version to 3.2 in prerequisites
feat!: require fleet.config.local.yml for all installs

BREAKING CHANGE: install no longer falls back to fleet.config.yml defaults
for host and repos_root; run ./install to generate the local config file
```
