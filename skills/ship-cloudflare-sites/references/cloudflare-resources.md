# Cloudflare resource operations

Use repository-pinned Wrangler and adapter versions. Verify unstable command syntax with local `--help` and current official Cloudflare/OpenNext documentation before mutation. Treat Wrangler configuration in source control as the desired-state source of truth unless the repository explicitly uses another system; reconcile dashboard drift rather than silently preserving it.

## Wrangler configuration

Inspect `wrangler.jsonc`, `wrangler.toml`, or generated deployment config for:

- Worker `name`, `main`, `compatibility_date`, and `compatibility_flags`;
- `workers_dev`, preview URLs, environments, routes, and custom domains;
- `vars` for non-secret values and declared required secret names;
- `d1_databases` bindings, names, IDs, preview IDs, and migration directory;
- `r2_buckets` bindings and bucket names;
- static `assets` binding/directory;
- observability and logs.
- version metadata, build configuration, and environment inheritance.

Treat a future compatibility date, missing environment split, production resource reused for preview, and dashboard/config drift as release risks.

## Authentication and identity

Run `npx wrangler whoami` before provisioning or production operations. Confirm the Cloudflare account and zone explicitly. In CI, use least-privilege tokens and never print them. Do not infer account or zone from a domain alone.

Use the command runner that resolves the repository-pinned binary (`npx --no-install`, `yarn`, `pnpm exec`, or the repository equivalent). Do not let `npx` download an unpinned Wrangler during a release.

## D1 lifecycle

Create once, then capture the returned database ID:

```text
npx wrangler d1 create <database-name>
```

Use migration files for ongoing schema changes:

```text
npx wrangler d1 migrations create <database-name> <description>
npx wrangler d1 migrations list <database-name> --local
npx wrangler d1 migrations apply <database-name> --local
npx wrangler d1 migrations list <database-name> --remote
npx wrangler d1 migrations apply <database-name> --remote
```

Use the database name rather than a mutable binding name when practical. Keep local and remote commands visually distinct. Capture a D1 Time Travel bookmark or approved export before risky mutation and record it in the release evidence. Data recovery is separate from Worker version rollback.

## R2 lifecycle

Create once and bind it:

```text
npx wrangler r2 bucket create <bucket-name>
```

For CLI uploads, specify local/remote target explicitly and set metadata intentionally:

```text
npx wrangler r2 object put <bucket>/<key> --remote --file <path> --content-type <type> --cache-control <policy>
```

For runtime uploads, use the R2 binding and set `httpMetadata`. Prefer immutable keys containing a content hash or release identifier. A bucket is private by default; attaching a custom domain makes objects publicly available through Cloudflare. Confirm access controls before attaching it.

R2 custom-domain caching can serve stale overwritten/deleted objects and cached 404s. Prefer a new object key. If that is impossible, request a narrowly targeted cache purge and verify afterward.

When changing R2 CORS on a bucket already serving cached traffic, verify a refreshed response: cached objects may keep older CORS headers until cache refresh or purge.

## Worker domain versus R2 domain

- Attach `example.com` or `www.example.com` as Worker Custom Domains when the Worker is the origin for the full hostname.
- Attach `assets.example.com` through R2 bucket settings under Public access > Custom Domains.
- Custom Domains match exact hostnames; apex and `www` need separate configuration.
- Choose a canonical hostname and redirect the other using an approved rule or application behavior.
- Do not create a Worker Route when the Worker is itself the origin unless there is a deliberate Worker-chaining design.
- A hostname with a conflicting CNAME cannot be added as a Worker Custom Domain until the conflict is resolved.

Verify DNS resolution, certificate status, HTTP-to-HTTPS behavior, canonical redirect, and representative paths after changes.

## Secrets

Keep secret values out of Wrangler `vars`, source control, shell history, reports, and screenshots. Local secrets belong in ignored `.dev.vars` or `.env` files according to the project convention. For production:

```text
npx wrangler secret put <NAME>
```

Know that `wrangler secret put` immediately creates and deploys a new Worker version. For gradual deployment workflows, use version-aware secret commands supported by the pinned Wrangler version. Declare required secret names in Wrangler when the project version supports it so deploy/type generation can validate them.

Never pass secret values directly in a shell command. Prefer interactive input, an approved secrets file, or CI secret injection that avoids logs and shell history.

## Observability and diagnosis

Enable Workers observability in Wrangler for production unless policy says otherwise. Use dashboard Workers Logs or `wrangler tail` for bounded diagnosis. Redact request authorization, cookies, user data, and secrets. After a release, inspect new exceptions, 5xx responses, D1 errors, R2 errors, and CPU/subrequest-limit failures.

For gradual deployments, use version metadata/log attribution where supported so old- and new-version error rates can be compared. Define an observation window and promotion threshold before shifting traffic.

## New project bootstrap

For a Next.js site, prefer the current Cloudflare/OpenNext bootstrap path, then pin versions in the project. Minimum reusable pieces are:

- package scripts for build, preview, deploy, and binding type generation;
- `initOpenNextCloudflareForDev()` in Next configuration when required by the adapter;
- `open-next.config.ts`;
- Wrangler configuration with `nodejs_compat`, assets output, bindings, environments, and domains;
- ignored local secret files;
- ordered D1 migrations;
- separate staging/production resources;
- smoke-test and rollback notes.

For preview needs, choose deliberately among local preview, uploaded version previews, Wrangler environments, and a separate staging Worker. Wrangler environments create separate Workers; they are not merely variable overlays. Do not reuse production D1/R2 resources in preview unless the user explicitly accepts that coupling.

Do not copy IDs, domains, analytics IDs, secrets, or bucket/database names from another project.

