# GitHub Issues

Use `gh` to read and publish issues and specs in `SapkaLabs/derp-stack`.
`docs/tickets.md` indexes the implementation tickets and links related
Playwriter work to its own repository.

- Read a ticket with `gh issue view <number> --comments`.
- List open work with `gh issue list --state open`. Filter with `--label`.
- Publish with `gh issue create --title "<title>" --body-file <file>`.
- Use GitHub sub-issues for parent and child work and native issue
  dependencies for blockers. A ticket is unblocked when all blockers are closed.
- Apply or remove labels with `gh issue edit`. When closing an issue,
  record the reason with `gh issue comment` before running `gh issue close`.

PRs as a request surface: no.
