# VPS Deploy Playbook

[![CI](https://github.com/WaifaiMT/vps-deploy-playbook/actions/workflows/ci.yml/badge.svg)](https://github.com/WaifaiMT/vps-deploy-playbook/actions/workflows/ci.yml)

Deploy Node.js, Next.js, and static sites (React, Vite, Astro) to your own Linux VPS with Nginx, PM2, free HTTPS, and GitHub Actions. Every push to `main` deploys automatically, a failed health check rolls back on its own, and an older release is one command away.

It's the setup I use for production apps, cleaned up into templates and scripts you can copy.

## What's in it

| Path | What it does |
|---|---|
| [`scripts/setup-server.sh`](scripts/setup-server.sh) | One-time setup of a fresh Ubuntu server: deploy user, SSH keys, firewall, Node.js, PM2, Nginx, Certbot, optional SSH hardening |
| [`scripts/deploy.sh`](scripts/deploy.sh) | Unpacks a release into its own folder, links shared secrets, switches `current` atomically, reloads PM2, health-checks, and rolls back on failure |
| [`scripts/rollback.sh`](scripts/rollback.sh) | Switches back to the previous release |
| [`nginx/`](nginx) | Site templates for a static SPA, a Node/Next.js app, and front-end + API on one domain, plus shared security headers |
| [`pm2/ecosystem.config.cjs`](pm2/ecosystem.config.cjs) | PM2 config template |
| [`workflows/`](workflows) | GitHub Actions templates to copy into your app: [static site](workflows/deploy-static.yml) and [Node/Next.js](workflows/deploy-node.yml) |
| [`docs/`](docs) | Step-by-step guides |

## How a deploy works

```
push to main ─▶ GitHub Actions: npm ci → test → build → tar
                      │ scp + ssh (pinned host key)
                      ▼
/var/www/my-app/
├── releases/
│   ├── 20261030093000/
│   └── 20261031120000/   ◀── new release unpacked here
├── shared/.env            linked into every release
└── current ─────────────▶ switched atomically, then pm2 reload + health check
                           (failed check → switch back, deploy fails)
```

## Quick start

1. **[Set up the server](docs/01-server-setup.md)**: run `setup-server.sh` once on a fresh Ubuntu VPS.
2. **[Add SSH keys to GitHub](docs/02-ssh-deploy-keys.md)**: four secrets and a variable or two.
3. **[First deploy](docs/03-first-deploy.md)**: add an Nginx site, copy a workflow into your app, and push.
4. **[Turn on HTTPS](docs/04-https.md)**: one Certbot command.
5. **[Troubleshooting](docs/05-troubleshooting.md)**: the usual 502s, 404s, and SSH errors.

## Design choices

- **CI uploads the build; the server never runs `git pull`.** The server needs no GitHub access, and builds happen on clean CI machines instead of the production box.
- **Atomic release switching.** `current` is a symlink swapped in one `rename`, so there's never a moment where the site serves half-copied files.
- **Automatic rollback.** With a health URL set, a release that doesn't respond is switched back before the workflow reports failure.
- **No third-party deploy actions.** The workflows use plain `ssh` and `scp` with a pinned host key, so no unpinned action ever handles your private key.
- **Least privilege.** CI logs in as a non-root `deploy` user that can only test and reload Nginx with `sudo`.

## Tested

CI runs on every push:

- [ShellCheck](https://www.shellcheck.net/) on every script
- An end-to-end test of `deploy.sh` and `rollback.sh` ([`test/deploy-test.sh`](test/deploy-test.sh)): deploys, health-check rollback, pruning, manual rollback, and a failed first deploy
- `nginx -t` against every template in the official Nginx image
- [actionlint](https://github.com/rhysd/actionlint) on the workflow templates

Run the deploy test locally on Linux or WSL with `bash test/deploy-test.sh`.

## License

MIT
