# Ship Cloudflare Sites

A reusable Codex skill for developing, auditing, provisioning, releasing, verifying, and recovering websites on Cloudflare Workers.

It covers Next.js/OpenNext, vinext/Cloudflare Vite, Wrangler, D1 migrations, R2 object storage, secrets, custom domains, caching, observability, direct deployments, gradual deployments, and rollback planning.

## Install with Codex

Ask Codex:

```text
Use $skill-installer to install the skill from:
https://github.com/amagnatema/ship-cloudflare-sites/tree/main/skills/ship-cloudflare-sites
```

To install a fixed release:

```text
Use $skill-installer to install the skill from:
https://github.com/amagnatema/ship-cloudflare-sites/tree/v1.2.0/skills/ship-cloudflare-sites
```

The equivalent installer arguments are:

```text
--repo amagnatema/ship-cloudflare-sites
--path skills/ship-cloudflare-sites
--ref v1.2.0
```

The skill becomes available to Codex on the next turn after installation.

## Use

Invoke it explicitly:

```text
Use $ship-cloudflare-sites to audit this project and prepare a safe Cloudflare release.
```

Or ask naturally for Cloudflare Workers deployment work; the skill metadata allows Codex to select it automatically when relevant.

## What is included

```text
skills/ship-cloudflare-sites/
├── SKILL.md
├── agents/openai.yaml
├── references/
│   ├── cloudflare-resources.md
│   └── release-workflow.md
└── scripts/
    ├── audit-cloudflare-project.sh
    └── inspect-migrations.py
```

Run the read-only project audit directly:

```bash
./skills/ship-cloudflare-sites/scripts/audit-cloudflare-project.sh /path/to/project
```

## Safety

Review the skill before installing or running it. Cloudflare production deployment, D1 changes, R2 changes, domain configuration, secrets, cache purges, and rollback can modify remote resources.

The audit script is read-only. The skill requires the agent to distinguish environments, preserve unrelated worktree changes, avoid printing secret values, and verify deployed behavior instead of treating upload success as release success.

## Versioning

Stable releases use semantic Git tags. Pin a tag for reproducible installation; use `main` only when you want the latest development version.

## License

MIT
