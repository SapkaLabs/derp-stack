## MVP implementation

- Start with one observable user outcome, the upstream components to reuse, and the shortest check that demonstrates it. Treat issue lists and acceptance matrices as background unless the user selects that scope.
- Continue the agreed implementation and its necessary checks for as long as they take. Use maintained upstream behavior and the least custom code needed to meet the outcome.
- Keep newly discovered improvements, edge cases and operational concerns as brief handoff notes. Implement them only if the user adds them to scope. If an agreed outcome is blocked and the smallest fix would expand scope, explain the observed blocker and proposed change, ask before proceeding with it, and continue independent in-scope work.
- Apply a narrowed goal immediately, including to outstanding reviews and delegated work. At handoff give the runnable commands, observed results and any unverified checks.
- Exercise a scheduled job on demand when that answers the implementation question. Record wall-clock timer observation as pending unless the user selected it as part of the goal.

## Agent skills

### Issue tracker

Track server issues in `SapkaLabs/derp-stack` on GitHub. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels. See `docs/agents/triage-labels.md`.

### Domain docs

This repo uses a single root glossary and one directory for architecture decisions. See `docs/agents/domain.md`.
