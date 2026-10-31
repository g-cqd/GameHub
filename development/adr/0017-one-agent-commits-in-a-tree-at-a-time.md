---
status: accepted
date: 2026-10-31
---

# 0017: One agent commits in a working tree at a time

## Context
On 2026-10-31 two agents worked in `~/Developer/GameHub` at once:
- the static-analysis session;
- an `ask` session that registered the Steam and Ubisoft libraries and switched the defaults to hub-2.

The first committed `launcher/hub` with `git commit <path>`, which took the whole file, including the other agent's
unreviewed `PROVIDER_RUNTIME` change (b2455c8). The other agent's report then described that change as uncommitted,
and the first session's lint fixes as "changes I did not make".

## Decision
- **One committer:** only one agent commits in a working tree at a time. A second agent works in a `git worktree` or
  a clone, or waits.
- **Check before committing:** read `git diff` for every file in the commit, and commit hunks (`git add -p`), not
  whole files, when the tree has changes you didn't make.
- **Say who changed what:** a handoff report lists each file it changed and each file it found changed by someone
  else.

## Consequences
A mixed commit is described in a later commit message or ADR (here ADR-0009) rather than rewritten on `main`, because
`main` is never force-pushed (ADR-0003).
