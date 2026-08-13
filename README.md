# claude-fleet

A personal Claude Code agent fleet. You write task files; cron spawns Claude sessions; results land in `results/`.

**Hard rule:** only you can trigger a Claude invocation.

---

## Prerequisites

- [Claude Code](https://claude.ai/code) installed and authenticated (`claude` in PATH)
- `tmux` and `python3`
- Linux, macOS, or WSL2

---

## Setup

```bash
git clone https://github.com/surdarmaputra/claude-fleet
cd claude-fleet

cp .env.example .env        # fill in any secrets you need
./install                   # creates fleet.config.local.yml, installs cron, and symlinks fleet to ~/.local/bin
fleet doctor
```

`./install` symlinks `fleet` into `~/.local/bin/` so you can run `fleet` from anywhere on the machine. If `install` prints a PATH warning, add this to your `~/.bashrc` or `~/.zshrc` and reload your shell:

```bash
export PATH="${HOME}/.local/bin:${PATH}"
```

`fleet doctor` will report WARN for `budget: unset` — that's expected until you have a week of usage data. Everything else should be OK.

### Config files

| File | Tracked | Purpose |
|---|---|---|
| `fleet.config.yml` | ✅ yes | Defaults for all settings. Never edit directly. |
| `fleet.config.local.yml` | ❌ gitignored | Your personal overrides. Only set what differs from the defaults. |
| `.env.example` | ✅ yes | Documents every secret the project uses. |
| `.env` | ❌ gitignored | Your actual secrets. |

`./install` creates `fleet.config.local.yml` automatically with your hostname and `repos_root`. Edit it to adjust:

```yaml
# fleet.config.local.yml — gitignored, never committed
host: my-laptop
repos_root: /home/user/code
max_agents: 2
```

Only the keys you include here override the defaults. Anything not listed falls through to `fleet.config.yml`.

---

## Three workflows ready to use

### 1. General / brainstorm task

No repo needed. Claude writes output to `results/<id>.md`.

```bash
cat > tasks/brainstorm-001.md << 'EOF'
---
id: brainstorm-001
status: todo
persona: general
priority: normal
workspace: scratch
---
Brainstorm 10 product ideas for a developer productivity tool that works
offline. For each idea include: the problem it solves, who pays for it,
and one technical risk.
EOF

bin/fleet now
```

Result appears in `results/brainstorm-001.md`.

---

### 2. Code review task

Claude reads the repo and produces a structured findings report.

```bash
# Clone the repo into repos_root first (default: ../fleet-repos)
git clone git@github.com:your-org/app ../fleet-repos/app

cat > tasks/review-pr-42.md << 'EOF'
---
id: review-pr-42
status: todo
persona: reviewer
priority: normal
workspace: repo-ro
repo: app
---
Review the diff on branch feature/add-payments against main.

  git diff main..feature/add-payments

Focus: data integrity, missing validation, N+1 queries.
EOF

bin/fleet now
```

Result in `results/review-pr-42.md` — one block per file with labelled findings.

---

### 3. Coding task

Claude works on an isolated git worktree (its own branch), commits its changes, and reports what it did.

```bash
git clone git@github.com:your-org/app ../fleet-repos/app

cat > tasks/code-001.md << 'EOF'
---
id: code-001
status: todo
persona: coder
priority: normal
workspace: worktree
repo: app
---
Add input validation to the user registration endpoint.

- Email must match RFC 5322 format
- Password must be at least 12 characters
- Return 422 with a structured error body on failure
- Add a test for each validation rule

The endpoint is in src/controllers/auth.rb around line 45.
EOF

bin/fleet now
```

Claude commits its changes on branch `agent/code-001`. Review with:

```bash
cd ../fleet-repos/app
git diff main..agent/code-001
```

---

## Agent skills

Claude Code skills are markdown files that load a reusable set of instructions into any agent session when invoked with `/skill-name`. All skills live flat in `.claude/skills/`. Every file there is **gitignored by default**; project-default skills that should be shared are explicitly un-ignored in `.gitignore` one by one.

### Installing a skill from the internet

Use `bin/skill-install` to download a skill directly into `.claude/skills/`:

```bash
# From a raw URL
bin/skill-install https://raw.githubusercontent.com/some-user/some-repo/main/skills/my-skill.md

# GitHub shorthand: <user>/<repo>/<path-inside-repo>
bin/skill-install some-user/some-repo/skills/my-skill.md
```

The downloaded `.md` file is immediately available in Claude Code sessions as `/my-skill`. It is never committed to git.

### Managing installed skills

```bash
bin/skill-install --list              # list all skills in .claude/skills/
bin/skill-install --remove my-skill   # remove a skill
```

### Shipping a project-default skill

Create the skill file in `.claude/skills/`, then un-ignore it in `.gitignore`:

```bash
cat > .claude/skills/my-project-skill.md << 'EOF'
---
name: my-project-skill
description: One-line description shown in the skill list
---

Full instructions that Claude will follow when /my-project-skill is invoked.
EOF

# Un-ignore it so it gets committed
echo '!.claude/skills/my-project-skill.md' >> .gitignore
git add .claude/skills/my-project-skill.md .gitignore
```

That `!` exception is the only extra step compared to a personal skill — everything else (detection, invocation) works the same way.

---

## Multiple Claude accounts (optional)

If you have separate personal and work subscriptions, create named CLI profiles:

```bash
claude config set --profile work account.email you@company.com
claude config set --profile personal account.email you@personal.com

# Shell aliases (add to ~/.bashrc or ~/.zshrc)
alias claude-work='claude --profile work'
```

Then override the binary per persona in `personas/<name>/config.json`:

```json
{ "bin": "claude-work" }
```

And set `work_repo_prefix` in `fleet.config.yml` so guard can enforce the mapping:

```yaml
work_repo_prefix: app,api
```

Guard kills any session where a work repo runs under the default binary.

---

## Task reference

**Frontmatter fields:**

| Field | Values | Notes |
|---|---|---|
| `id` | any slug | must be unique |
| `status` | `todo` `doing` `done` `blocked` | only mutate via `bin/task-set` |
| `persona` | `general` `reviewer` `coder` `prod-support` `planner` | |
| `priority` | `high` `normal` | high tasks claimed first |
| `workspace` | `scratch` `repo-ro` `repo` `worktree` | see below |
| `repo` | folder name under `repos_root` | required for repo workspaces |
| `host` | machine label | omit to run on any host |

**Workspace modes:**

| Mode | Persona | Behaviour |
|---|---|---|
| `scratch` | general, prod-support, planner | empty dir, no repo access |
| `repo-ro` | reviewer | runs inside the repo, write tools denied |
| `repo` | coder | runs inside the repo, write tools allowed, no branch isolation |
| `worktree` | coder | isolated git worktree on branch `agent/<id>`, write tools allowed |

**Task lifecycle:**

```
todo → doing → done
           ↓ session crash, up to 3 attempts
         todo → blocked
```

To add feedback and re-run: append a `## Feedback` section and set `status: todo`.

---

## CLI

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

Exit codes: `0` ok · `2` degraded (fleet still runs) · `3` stopped by guard.

---

## What works now vs later phases

| Capability | Status |
|---|---|
| General / brainstorm tasks | ✅ Ready |
| Code review tasks | ✅ Ready |
| Coding tasks (worktree) | ✅ Ready |
| Prod-support / incident tasks | ✅ Ready |
| Cron automation + guard | ✅ Ready |
| Token budget tracking (`fleet usage`) | 🔜 Phase 3 — needs usage.csv wiring |
| Lark notifications | 🔜 Phase 4 |
| Lark bot intake (auto-create tasks) | 🔜 Phase 4 |
| GitLab MR / Jira intake | 🔜 Phase 5 |
| KB sync | 🔜 Phase 5 |
| Coder multi-phase orchestration | 🔜 Phase 5 |

---

## Budget

Week 1: only `max_sessions_per_day: 25` is active. After one week:

```bash
bin/fleet usage --since 7d
```

Set the result in `fleet.config.yml`:

```yaml
budget:
  daily_budget_tokens: 3000000   # median_tokens_per_task × tasks_per_day × 1.3
```
