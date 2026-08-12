# claude-fleet

A personal Claude Code agent fleet. Cron spawns Claude sessions from a markdown task board; you review the output.

**Volume:** 10–15 tasks/day, 3 concurrent sessions.
**Cost:** $0 incremental on an existing Claude subscription.
**Hard rule:** only you can trigger a Claude invocation.

---

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated (`claude` in PATH)
- `tmux` and `python3` installed
- Linux, macOS, or WSL2

---

## Quickstart

**1. Clone and configure**

```bash
git clone https://github.com/surdarmaputra/claude-fleet
cd claude-fleet

cp fleet.config.yml.example fleet.config.yml
cp .env.example .env
```

Edit `fleet.config.yml` — at minimum set your machine label:

```yaml
host: my-laptop        # identifies this machine in multi-host setups
repos_root: ../fleet-repos   # where your git repos live
```

**2. Install**

```bash
./install
```

Checks prerequisites, makes `bin/` executable, and installs cron jobs (or launchd on macOS). Confirm with:

```bash
bin/fleet doctor
```

Expected output for a fresh install: all OK except `budget: daily_budget_tokens unset` — that's intentional for week 1.

**3. Add your repos**

Repos live outside the project. Create the repos root and clone whatever you need:

```bash
mkdir -p ../fleet-repos
git clone git@gitlab.com:your-org/app ../fleet-repos/app
```

**4. Create a task**

Copy the example and drop it in `tasks/`:

```bash
cp examples/task-mr-1204.md tasks/mr-1204.md
```

Edit the file — the frontmatter controls everything:

```markdown
---
id: mr-1204
status: todo
persona: reviewer
priority: normal
workspace: repo-ro
repo: app
host: my-laptop
---
Review MR 1204. Focus: migration safety, N+1 queries.
```

**5. Trigger immediately**

```bash
bin/fleet now
```

Or wait — cron picks up `todo` tasks every 5 minutes during work hours.

**6. Check status**

```bash
bin/fleet tasks          # all tasks grouped by status
bin/fleet agents         # running tmux sessions
bin/fleet logs           # last 5 heartbeat lines
```

Results land in `results/<task-id>.md`.

---

## Multiple subscriptions

Each persona declares which `claude` binary it runs under. This lets you split tasks across different Claude accounts — for example, keeping personal and work subscriptions separate.

**1. Create a named CLI profile for each account**

Claude Code supports multiple profiles via `claude config`. Create one per subscription:

```bash
claude config set --profile work account.email you@company.com
claude config set --profile personal account.email you@personal.com
```

Each profile stores its own authentication. Switch with `claude --profile <name>`, or wrap it in a shell alias:

```bash
# ~/.bashrc or ~/.zshrc
alias claude-work='claude --profile work'
alias claude-personal='claude --profile personal'
```

**2. Set the default binary in `fleet.config.yml`**

```yaml
claude_bin: claude-personal     # fallback when a persona doesn't set its own bin

work_repo_prefix: app,api       # guard enforces the right binary on these repos
```

**3. Override per persona**

Edit `personas/<name>/config.json` to pin a specific binary for that persona:

```json
{
  "bin": "claude-work",
  "workspace": "repo-ro",
  "model": "sonnet"
}
```

Guard enforces the mapping: if a task touches a `work_repo_prefix` repo but the persona's `bin` matches the global `claude_bin` fallback instead of a dedicated binary, the session is killed and the task is set to `blocked`.

---

## Personas

| Persona | Use for | Workspace | Model |
|---|---|---|---|
| `reviewer` | Code review | `repo-ro` (read-only) | sonnet |
| `coder` | Implementation | `worktree` (own branch) | opus |
| `prod-support` | Incident investigation | `scratch` | opus |
| `planner` | Feature breakdown | `scratch` | sonnet |

Persona prompts and permissions live in `personas/<name>/`.

---

## Task lifecycle

```
todo → doing → done
           ↓ (on failure, up to 3 attempts)
         todo → blocked
```

Guard runs every 5 minutes. Crashed sessions are automatically re-queued; after 3 failures the task is set to `blocked`.

To re-run a done task or add feedback, append a `## Feedback` section and set `status: todo`.

---

## Budget

Week 1: only the session count cap is active (`max_sessions_per_day: 25`).

After one week of data, set a token cap:

```bash
bin/fleet usage --since 7d   # see tokens per task
```

Then in `fleet.config.yml`:

```yaml
budget:
  daily_budget_tokens: 3000000   # median_per_task × tasks_per_day × 1.3
```

---

## CLI reference

```
fleet tasks   [--status todo|doing|done|blocked] [--persona <p>] [--host <h>]
fleet agents
fleet adapters
fleet cron
fleet logs    [<job>] [-n <lines>]
fleet usage   [--since <Nd>]
fleet budget
fleet doctor
fleet now
```

Exit codes: `0` ok · `2` degraded (a check failed, fleet still runs) · `3` fleet stopped by guard.
