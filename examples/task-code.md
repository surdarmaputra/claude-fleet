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
