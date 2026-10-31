# 3. First deploy

## How deploys work

```
GitHub Actions                         Server (/var/www/my-app)
──────────────                         ────────────────────────
npm ci → test → build
tar the build ──── scp ───────────────▶ /tmp/my-app-<sha>.tar.gz
ssh deploy.sh ────────────────────────▶ releases/20261031120000/   (unpacked)
                                        shared/.env linked in
                                        npm ci --omit=dev          (node apps)
                                        current → new release      (atomic switch)
                                        pm2 reload                 (node apps)
                                        health check ── fail ──▶ switch back, exit 1
                                        prune to the last 5 releases
```

Each deploy is a new folder, and `current` is a symlink switched in a single atomic step, so visitors never see a half-deployed app. The previous releases stay on disk for instant rollbacks.

## Static site (React, Vite, Astro)

1. Copy `nginx/static-site.conf` to the server, replacing `example.com` and `my-app`:

   ```bash
   sudo cp static-site.conf /etc/nginx/sites-available/my-app
   sudo ln -s /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
   sudo cp snippets/security-headers.conf /etc/nginx/snippets/
   sudo nginx -t && sudo systemctl reload nginx
   ```

2. Copy `workflows/deploy-static.yml` to `.github/workflows/deploy.yml` in your app's repo. Change `dist` if your build folder is different.
3. Push to `main`. The workflow builds, uploads, and deploys.

## Node.js or Next.js app

1. Install the shared WebSocket map once per server, then the site:

   ```bash
   sudo cp conf.d/connection-upgrade.conf /etc/nginx/conf.d/
   sudo cp snippets/security-headers.conf /etc/nginx/snippets/
   sudo cp node-app.conf /etc/nginx/sites-available/my-app
   sudo ln -s /etc/nginx/sites-available/my-app /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```

2. Put your secrets where every release can find them:

   ```bash
   mkdir -p /var/www/my-app/shared
   nano /var/www/my-app/shared/.env
   ```

3. Copy `pm2/ecosystem.config.cjs` into your app's repo root and set `name`, `cwd`, and `PORT`.
4. Copy `workflows/deploy-node.yml` to `.github/workflows/deploy.yml` and adjust the packaged paths for your app.
5. Push to `main`.

## Front-end and API on one domain

Use `nginx/fullstack.conf`: static files at `/`, the API at `/api/`. Deploy the front-end with `deploy-static.yml` (for example `APP_NAME=my-web`) and the API with `deploy-node.yml` (`APP_NAME=my-api`), each from its own repo or folder.

## Roll back

```bash
ssh deploy@<server-ip>
~/bin/rollback.sh --app my-app                  # static site
~/bin/rollback.sh --app my-app --type node      # Node app (reloads PM2)
```

Next: [4. HTTPS](04-https.md)
