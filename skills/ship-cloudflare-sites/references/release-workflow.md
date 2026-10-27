# Versioned release workflow

Use this workflow for each release. Replace placeholders only after reading the repository and resolving exact resource names.

## Release path matrix

Classify every diff before choosing a deployment path:

| Change | Default path | Extra gate |
| --- | --- | --- |
| UI/content only | Normal project release | Critical page smoke tests |
| Worker runtime/config/binding | Upload and inspect when supported | Binding and compatibility verification |
| D1 additive migration | Compatible staged order | Time Travel bookmark or approved export |
| D1 destructive migration | Expand/backfill/contract across releases | Explicit destructive approval |
| R2 object/policy/CORS/cache | Versioned keys when possible | Header and freshness verification |
| Domain/DNS/certificate | Separate infrastructure change | DNS, TLS, and redirect verification |
| Adapter/Wrangler/runtime upgrade | Upload and inspect | Bundle size and runtime regression checks |

Gradual deployment is unsafe when old and new versions cannot coexist against the same D1 schema, R2 object format, API contract, session format, or downstream Worker. Resolve compatibility first.

## 1. Establish the release unit

- Choose a SemVer release identifier such as `v1.2.0`: major for incompatible behavior or data contracts, minor for backward-compatible features, patch for backward-compatible fixes.
- Record the Git commit SHA and package/lockfile state.
- Review `git status`; distinguish the user's unrelated changes from release changes. Never discard or include unrelated changes silently.
- Summarize application, configuration, D1, R2, secret, domain, and cache changes separately.
- Decide whether this is a direct production deployment or a staging/gradual deployment.
- If the release cannot be isolated from unrelated worktree changes safely, stop and explain the collision.
- For an approved dirty release, retain a secure source snapshot or diff including relevant untracked files and an artifact hash manifest; record the base commit and exclusions. Avoid copying secrets or ignored state into snapshots. Do not invent a commit, tag, or release ID as a prerequisite for deployment.

## First deployment

- Check account, intended environment, existing Worker, bindings and prior deployment before creating resources; never recreate a resource just because local config is incomplete. If credentials are missing or expired, initiate the supported login and explain the user action required. Check actual permissions rather than assuming OAuth covers every product.
- Confirm the desired hostname. If a custom domain/zone is missing, offer workers.dev where supported; change the target only with the user's choice. Confirm account and resource ownership before provisioning.
- A new Worker may have no prior version to split traffic with or roll back to. Test a separate staging Worker and bindings first, and verify the supported preview or controlled test route when available. If no safe preview exists, explain the limitation before first production traffic. Record how to disable the entry point or deploy a forward fix; do not use an unverified or insecure staging version as production rollback.

## 2. Run local gates

Choose commands from the detected lockfile and package metadata:

- npm: `npm run <script>` and `npx --no-install <binary>`
- Yarn: `yarn <script>` and `yarn <binary>`
- pnpm: `pnpm <script>` and `pnpm exec <binary>`
- Bun: `bun run <script>` and the repository-supported local binary runner

Use repository scripts, not invented substitutes. A typical Next.js/OpenNext sequence is:

```text
<package-manager> run lint
<package-manager> run typecheck
<package-manager> test
<package-manager> run build
<package-manager> run cf:build
<package-manager> run cf:preview
```

Skip only unavailable or inapplicable gates and state why. Test critical pages, API routes, authorization, locale/canonical behavior, and large/static assets; test D1 and R2 reads/writes only when present. Do not let a preview command bind indefinitely; start it in a managed session and stop it after checks.

Build once for a release and deploy/upload that verified output. For OpenNext, check whether `.dev.vars` or Next `.env*` files affect a local build; prefer approved CI/Workers Builds inputs for reproducible production builds.

Inspect scripts before choosing their order: a test or preview may rebuild or overwrite output. Run such gates before the final environment build; afterward test the generated artifact without rebuilding, record hashes, verify its target, and upload that same artifact. Build separately per environment when environment selection changes build output. Check lockfile consistency and the supported Node version. For security advisories inspect the affected dependency and actual bundled/runtime usage; dependency sections alone do not prove exposure or absence of exposure. Apply compatible fixes, test upgrades, and report unresolved relevant risk; never blindly run a breaking forced upgrade.

### Cloudflare Vite plugin and vinext

Identify the actual adapter and use its repository scripts; do not substitute OpenNext commands for a Vite/vinext project. The Cloudflare Vite plugin selects its environment at build time (for example with `CLOUDFLARE_ENV`); a later deploy flag cannot repair a build for the wrong environment. Inspect `.wrangler/deploy/config.json` and the generated config it points to. Before upload or trigger changes, verify generated Worker name, account, bindings/IDs, assets directory, variables, preview and hostname settings against the intended environment. The generated config may be required because the source config lacks the generated assets directory. Use local pinned CLI `--help` and current official docs for exact supported commands. Never deploy an unchecked default/local build.

## 3. Prepare D1

Prefer checked-in migrations. Substitute the intended source config and environment explicitly in every command, including the local commands (for example `--config <config> --env <environment>`):

```text
npx wrangler d1 migrations list <database-name> --local
npx wrangler d1 migrations apply <database-name> --local
npx wrangler d1 migrations list <database-name> --remote
```

For a new migration:

```text
npx wrangler d1 migrations create <database-name> <short-description>
```

Before a production migration, capture a D1 Time Travel bookmark or approved export appropriate to the risk and confirm it exists. State whether the migration runs before code, after code, or between staged releases. Apply as part of the authorized production workflow:

```text
npx wrangler d1 migrations apply <database-name> --remote
```

Read the migration SQL before applying it. Treat drops, renames, destructive updates, and large backfills as high risk. Prefer an expand-and-contract sequence across releases.

Verify the selected rollback Worker can still run against the post-migration schema. Do not invent a down migration.

## 4. Prepare R2 and domains

- Confirm the bound bucket exists and matches the intended environment.
- Confirm public assets use the intended R2 custom domain.
- Prefer new immutable keys over overwriting cached keys.
- Verify CORS, access policy, `Content-Type`, `Cache-Control`, and freshness for representative objects.
- Confirm the Worker custom domains and canonical redirect. Do not attach the R2 asset hostname to the Worker.
- Note dashboard-only steps that remain pending.

## 5. Confirm secrets and bindings

- Compare required secret names against the deployed Worker without printing values.
- Add or rotate secrets only with authorization. `wrangler secret put` creates and immediately deploys a Worker version; account for this side effect.
- Regenerate Cloudflare binding types after binding changes.
- Confirm Worker, D1, and R2 bindings point to the same intended environment.
- Rerun typecheck after binding or declared-secret changes.

## 6. Deploy

For a repository-provided OpenNext direct deployment, use this only when immediate 100% traffic is intended and the script deploys the already verified artifact without rebuilding:

```text
<package-manager> run cf:deploy
```

For a version upload/gradual rollout, use the adapter's upload command where available. Upload creates a version without serving it to normal production traffic; deployment controls which versions receive traffic. Confirm exact behavior from pinned `--help` and current official docs:

```text
npx opennextjs-cloudflare build
npx opennextjs-cloudflare upload
npx wrangler versions deploy <version-id>@<percentage>
```

Use a deployment message containing the release identifier and commit. Record the returned version/deployment ID. Do not deploy without explicit authorization.

Test the uploaded version through the supported version-preview or override mechanism before promotion, when safely available. Define the observation window and error threshold before raising traffic. Stop promotion or roll back when the threshold is breached. Treat triggers and workers.dev settings as separate from version traffic and verify the final public entry point; use the verified generated configuration where required.

## 7. Verify production

Verify from the actual public hostname, including workers.dev when selected:

- homepage and critical locale/page routes return the expected status and content;
- canonical apex/`www` redirect is correct;
- critical API health and authorization behavior are correct;
- when D1 is used, a representative application-table read succeeds and any approved, reversible write can be observed;
- when R2 is used, a representative object returns expected content type and cache headers, and CORS/freshness match policy;
- static assets and source maps do not expose secrets;
- Workers logs show no new uncaught errors;
- performance-sensitive or large WASM/assets load successfully.

Do not run destructive smoke tests. Use synthetic or reversible test records when writes are required. Check unsigned and forged admin identities are rejected. Diagnose 403s using status, headers and bounded sanitized logs; distinguish network/proxy or bot filtering from application behavior, and report any unresolved accessibility discrepancy. Do not log tokens, cookies, authorization headers or personal data. Report the observed duration; never claim the agreed observation window passed if it was interrupted or shortened.

## 8. Roll back safely

List recent deployments and select a known-good version:

```text
npx wrangler deployments list
npx wrangler rollback <version-id> --message "Rollback <release-id>: <reason>"
```

A Worker rollback creates a new active deployment but does not restore D1 data, reverse migrations, restore/remove R2 objects, undo domain changes, rotate secrets back, or purge cached objects. Before rollback, verify the old code can run against the current bindings and schema. If not, deploy a forward fix or compatibility release instead. Restore D1 from a captured bookmark/export only after assessing data-loss impact and obtaining authorization. Re-run production smoke tests and record the incident outcome.

## 9. Close the release

Report release ID, commit, environment, resource names, migration names, recovery point, version/deployment ID, traffic percentage, verification results, rollback target, excluded worktree changes, and remaining manual work. Do not tag, commit, push, or create a release unless requested or already included in the user's workflow.

