---
name: ship-cloudflare-sites
description: Develop, audit, provision, release, verify, and recover websites on Cloudflare Workers, including Next.js/OpenNext, Wrangler, D1, R2, secrets, domains, caching, and versioned deployments. Use for Cloudflare website setup, deployment readiness, production releases, infrastructure changes, rollback, or repeatable release iteration; do not use for Pages-only hosting or unrelated Cloudflare products.
---

# Ship Cloudflare Sites v1.2

Operate from repository evidence and the user's requested scope. A request to deploy authorizes the ordinary deployment workflow for the named environment; ask only when an additional destructive, irreversible, or materially broader change becomes necessary. Never infer a production target from an unspecified environment.

## Discover the project

1. Read repository instructions and inspect the current worktree before editing.
2. Run `scripts/audit-cloudflare-project.sh <project-root>` and inspect every reported blocker.
3. Resolve the framework, package manager, adapter (including vinext/Vite versus OpenNext), Worker entry, Wrangler configuration, environments, bindings, migrations, domains, CI path, and secret names from files—not memory. Treat audit script findings as signals, not proof; resolve unknowns and reported blockers.
4. Use the repository-pinned CLI. Verify mutable Cloudflare/OpenNext behavior in local `--help` and current official documentation before remote changes.
5. Read only the relevant references:
   - Read [references/release-workflow.md](references/release-workflow.md) for release, rollback, or version iteration.
   - Read [references/cloudflare-resources.md](references/cloudflare-resources.md) for provisioning or changing D1, R2, secrets, domains, caching, environments, or observability.

## Choose the operating mode

- **Audit/plan:** remain read-only. Return evidence, blockers, risks, and exact next actions.
- **Develop/configure:** edit and verify locally. Create remote resources only when the user requested provisioning or deployment requires them.
- **Provision:** confirm account, environment, resource names and intended ownership; confirm zone only when a custom domain is needed. Create only missing resources and persist returned IDs in the chosen config. If no domain is available, ask whether the user wants a workers.dev endpoint; do not infer acceptance.
- **Release:** build once, then deploy that verified artifact. Use direct deployment for low-risk releases when requested; use version upload plus controlled promotion for risky or explicitly gradual releases.
- **Recover:** select a known-good Worker version, then separately handle D1 and R2 state. Worker versions do not contain storage state.

## Apply invariant safeguards

- Distinguish local, preview/staging, and production resources. Make every remote command's target explicit.
- Keep secret values out of source, output, screenshots, and shell arguments. Report names and presence only.
- Protect admin paths on every reachable hostname. Verify Access JWT signature, issuer, audience, expiry and identity against trusted configuration; header presence alone is not authentication. If Access is unavailable, only publish with admin fail-closed when the user accepts that limitation; verify anonymous and forged requests are rejected.
- Review a dirty worktree before release. Do not discard, commit, or ship unrelated user changes.
- Model D1 changes as ordered migrations and prefer expand/backfill/contract across releases.
- Use immutable or versioned R2 keys for long-cache assets. Treat overwrite, delete, CORS change, and cache purge as one coordinated change.
- Treat Worker custom domains and R2 custom domains as separate resources. Verify apex, `www`, canonical redirects, certificates, and asset hostname independently.
- Do not call an upload a successful release. Verify the public hostname, critical routes, authorization and post-deploy logs. Check D1 or R2 behavior only when the project uses those resources.

## Produce a release record

Return:

- release ID, Git commit, environment, Worker and storage resource names;
- shipped source/configuration changes and excluded worktree changes;
- local gates and their results;
- D1 migrations plus recovery bookmark/export and compatibility order;
- R2/domain/cache/secret changes without secret values;
- Worker version/deployment ID and traffic percentage when available;
- smoke-test URLs and outcomes;
- rollback target, storage caveats, and remaining manual actions.

If a gate fails, stop before the unsafe boundary, preserve the evidence, and state what remains. Do not weaken a gate silently.

