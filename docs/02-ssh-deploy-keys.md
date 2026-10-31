# 2. SSH keys for GitHub Actions

GitHub Actions logs in to your server as the `deploy` user with a dedicated key. Nothing on the server needs access to GitHub, because CI uploads the build instead of the server running `git pull`.

## Add the repository secrets

In your app's repo: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Value |
|---|---|
| `VPS_HOST` | Server IP or hostname |
| `VPS_USER` | `deploy` |
| `VPS_SSH_KEY` | The whole private key file, `cat ~/.ssh/myapp_ci`, including the `BEGIN` and `END` lines |
| `VPS_KNOWN_HOSTS` | Output of `ssh-keyscan -t ed25519 <server-ip>` |

`VPS_KNOWN_HOSTS` pins the server's identity. Without it, CI would have to trust whatever answers at that IP, which is how deploy keys get stolen.

## Add the repository variables

Same page, **Variables** tab:

| Variable | Example | Notes |
|---|---|---|
| `APP_NAME` | `my-app` | Folder under `/var/www` |
| `HEALTH_URL` | `https://example.com/api/health` | Optional; a failed check rolls the deploy back |
| `PM2_NAME` | `my-app` | Node apps only; defaults to `APP_NAME` |

## Good practice

- **One key per app or server.** Revoke it by deleting its line from `/home/deploy/.ssh/authorized_keys`.
- **Never use password logins in CI.** The workflows here only support keys.
- **Use a GitHub environment** (`production`) to require approval before deploys, or to keep staging and production secrets apart.

Next: [3. First deploy](03-first-deploy.md)
