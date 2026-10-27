#!/usr/bin/env bash
set -euo pipefail

project_root="${1:-.}"
script_version="1.2"

if [[ ! -d "$project_root" ]]; then
  echo "error: project root is not a directory: $project_root" >&2
  exit 2
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
cd "$project_root"
project_root="$(pwd)"

section() {
  printf '\n## %s\n' "$1"
}

print_file_if_present() {
  local path="$1"
  if [[ -f "$path" ]]; then
    printf '%s\n' "$path"
  fi
}

section "Project"
printf 'root: %s\n' "$(pwd)"
printf 'audit_script_version: %s\n' "$script_version"
dirty_worktree=0
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'git_commit: %s\n' "$(git rev-parse --short HEAD)"
  printf 'git_branch: %s\n' "$(git branch --show-current)"
  printf 'git_status:\n'
  git status --short || true
  if [[ -n "$(git status --porcelain)" ]]; then
    dirty_worktree=1
  fi
else
  printf 'git: not detected\n'
fi

section "Package manager and framework"
print_file_if_present package.json
print_file_if_present yarn.lock
print_file_if_present package-lock.json
print_file_if_present pnpm-lock.yaml
print_file_if_present bun.lock
print_file_if_present bun.lockb

if [[ -f package.json ]] && command -v node >/dev/null 2>&1; then
  node -e '
    const p = require("./package.json");
    console.log(`package_name: ${p.name ?? "<unset>"}`);
    console.log(`package_version: ${p.version ?? "<unset>"}`);
    const all = {...p.dependencies, ...p.devDependencies};
    for (const name of ["next", "@opennextjs/cloudflare", "wrangler", "react", "astro", "vinext", "vite", "@cloudflare/vite-plugin"]) {
      if (all[name]) console.log(`dependency: ${name}@${all[name]}`);
    }
    for (const [name, value] of Object.entries(p.scripts ?? {})) {
      if (/(dev|build|preview|deploy|cloudflare|wrangler|type|lint|test|migration|d1|r2|release)/i.test(name + " " + value)) {
        console.log(`script: ${name} (contents not printed)`);
      }
    }
  '
fi

section "Cloudflare configuration files"
wrangler_config_count=0
for path in \
  wrangler.jsonc wrangler.json wrangler.toml \
  open-next.config.ts open-next.config.js \
  next.config.ts next.config.js next.config.mjs \
  .wrangler/deploy/config.json; do
  if [[ -f "$path" && "$path" == wrangler.* ]]; then
    wrangler_config_count=$((wrangler_config_count + 1))
  fi
  print_file_if_present "$path"
done

if command -v rg >/dev/null 2>&1; then
  rg --files --hidden \
    -g '!node_modules/**' -g '!.git/**' -g '!.next/**' -g '!.open-next/**' \
    | rg '/(wrangler\.(jsonc|json|toml)|open-next\.config\.(ts|js|mjs))$' \
    | sed -n '1,120p' || true
fi

section "Bindings, routes, and deployment signals"
if command -v rg >/dev/null 2>&1; then
  rg -l --hidden \
    -g '!node_modules/**' -g '!.git/**' -g '!.next/**' -g '!.open-next/**' \
    -g '!dist/**' -g '!build/**' -g '!coverage/**' -g '!cloudflare-env.d.ts' \
    -g '!**/.env*' -g '!**/.dev.vars*' -g '!**/*secret*' -g '!**/*credential*' \
    '(d1_databases|r2_buckets|custom_domain|routes|workers_dev|preview_urls|compatibility_date|compatibility_flags|observability|ASSET_PUBLIC_BASE_URL|getCloudflareContext|wrangler|opennextjs-cloudflare)' \
    . 2>/dev/null | head -n 240 || true
else
  printf 'rg unavailable; inspect Wrangler and package files manually\n'
fi

section "Schema and migrations"
migration_state="unknown"
if command -v python3 >/dev/null 2>&1; then
  migration_state="$(python3 "$script_dir/inspect-migrations.py" "$project_root")"
else
  printf 'migration inspection unavailable (python3 required)\n'
fi
printf 'migration_inspection: %s\n' "$migration_state"

section "CI and release files"
ci_file_count=0
if command -v rg >/dev/null 2>&1; then
  rg --files --hidden -g '!node_modules/**' -g '!.git/**' \
    | rg '(^|/)(\.github/workflows|\.gitlab-ci|release|deploy|Dockerfile|AGENTS\.md)' \
    | head -n 160 || true
  ci_file_count="$(rg --files --hidden -g '!node_modules/**' -g '!.git/**' \
    | (rg '(^|/)(\.github/workflows/|\.gitlab-ci\.yml$)' || true) | wc -l | tr -d ' ')"
else
  find . -maxdepth 4 -type f \( -path '*/.github/workflows/*' -o -name 'AGENTS.md' -o -iname '*deploy*' -o -iname '*release*' \) -print
fi

section "Local environment key names (values redacted)"
found_env=0
for env_file in .dev.vars .env .env.local .env.development .env.production; do
  if [[ -f "$env_file" ]]; then
    found_env=1
    printf '%s:\n' "$env_file"
    awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/{print "  " $1 "=<redacted>"}' "$env_file"
  fi
done
if [[ "$found_env" -eq 0 ]]; then
  printf 'none detected\n'
fi

section "Readiness findings"
blocker_count=0
warning_count=0

if [[ "$wrangler_config_count" -eq 0 ]]; then
  printf 'BLOCKER: no root Wrangler configuration detected\n'
  blocker_count=$((blocker_count + 1))
fi

if [[ "$dirty_worktree" -eq 1 ]]; then
  printf 'WARNING: worktree is dirty; isolate and review the intended release diff\n'
  warning_count=$((warning_count + 1))
fi

if [[ "$migration_state" == "d1-no-migrations" ]]; then
  printf 'WARNING: D1 configured but no SQL migration files found in configured directories\n'
  warning_count=$((warning_count + 1))
elif [[ "$migration_state" == "unknown" ]]; then
  printf 'WARNING: migration state unknown; inspect Wrangler config and migration directories manually\n'
  warning_count=$((warning_count + 1))
fi

if [[ "$ci_file_count" -eq 0 ]]; then
  printf 'WARNING: no checked-in CI workflow detected\n'
  warning_count=$((warning_count + 1))
fi

if [[ -f package.json ]] && command -v node >/dev/null 2>&1; then
  if ! node -e 'const p=require("./package.json"); process.exit(p.scripts?.test ? 0 : 1)'; then
    printf 'WARNING: package.json has no test script\n'
    warning_count=$((warning_count + 1))
  fi
fi

if [[ -f wrangler.jsonc || -f wrangler.json || -f wrangler.toml ]]; then
  config_path="wrangler.jsonc"
  [[ -f wrangler.json ]] && config_path="wrangler.json"
  [[ -f wrangler.toml ]] && config_path="wrangler.toml"
  if ! rg -q '"env"[[:space:]]*:|\[env\.|staging' "$config_path" 2>/dev/null; then
    printf 'WARNING: no explicit staging/preview environment detected in %s\n' "$config_path"
    warning_count=$((warning_count + 1))
  fi
fi

printf 'summary: blockers=%s warnings=%s\n' "$blocker_count" "$warning_count"
if [[ "$blocker_count" -eq 0 ]]; then
  printf 'result: audit-complete; resolve warnings and run task-specific gates before release\n'
else
  printf 'result: not release-ready\n'
fi

section "Manual review reminders"
printf '%s\n' \
  '- Confirm Cloudflare account and zone before remote operations.' \
  '- Resolve local, preview/staging, and production resources separately.' \
  '- Read migration SQL and identify destructive statements.' \
  '- Confirm Worker domains, canonical redirect, and R2 custom domain.' \
  '- Record required secret names only; never print their values.' \
  '- Treat deploy, --remote, DNS, secrets, purge, and rollback as external mutations.'

