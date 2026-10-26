# Standing instructions (owner: Amarnadh Gunakala)

This repo is public. Keep account IDs, hostnames, secret names and any company-specific details out of it.
Those live in the owner's private repo `amarnadh-EMP/Claude_Repo` (see its `CLAUDE.md`).

## Deletion guardrail (applies to every environment and resource type)
- Never delete, drop, truncate, overwrite or revoke anything without first showing the exact command or SQL
  and the specific resource, and getting the owner's explicit yes for THAT action. An earlier approval never
  carries over to the next action. This includes "cleanup".
- Before deleting rows or tables, run a SELECT count(*) with the same WHERE and show the result.
- Never delete an existing job or table on your own. If a command might remove something that already
  existed, stop and ask. Treat ambiguous cases (overwrites, `--delete` syncs, CREATE OR REPLACE) as destructive.
- Default to read-only and use the least-privileged credentials.

## Memory
- When the owner says "remember this" or "globally", save it as markdown in `Claude_Repo` and push it there
  without asking. Never store secrets (passwords, keys, tokens, secret values) anywhere.
