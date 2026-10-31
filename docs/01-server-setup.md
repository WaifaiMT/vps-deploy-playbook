# 1. Set up the server

Works on a fresh Ubuntu 22.04 or 24.04 VPS from any provider (Hostinger, DigitalOcean, Hetzner, AWS Lightsail).

## Before you start

- Point your domain's DNS **A record** (and `www`) at the server's IP.
- Make an SSH key for **CI** on your own machine. Use a separate key, not your personal one, so you can revoke it on its own:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/myapp_ci -C "github-actions@myapp" -N ""
```

This creates `myapp_ci` (private, goes into GitHub secrets) and `myapp_ci.pub` (public, goes on the server).

## Run the setup script

Log in as root once, copy the playbook over, and run it:

```bash
ssh root@<server-ip>
git clone https://github.com/WaifaiMT/vps-deploy-playbook.git
cd vps-deploy-playbook
sudo bash scripts/setup-server.sh \
  --deploy-user deploy \
  --node-version 22 \
  --ssh-key "$(cat /path/to/myapp_ci.pub)" \
  --ssh-key "ssh-ed25519 AAAA... you@laptop"
```

It installs Node.js, PM2, Nginx, and Certbot; creates the `deploy` user with your keys; opens only SSH, HTTP, and HTTPS in the firewall; lets `deploy` reload Nginx without a password; and puts `deploy.sh` and `rollback.sh` in `/home/deploy/bin`.

## Lock down SSH

Check that key login works **in a new terminal** before you go further:

```bash
ssh deploy@<server-ip>
```

Then turn off root login and passwords:

```bash
sudo bash scripts/setup-server.sh --deploy-user deploy --harden-ssh
```

Keep your current root session open until you've confirmed you can still log in as `deploy`.

Next: [2. SSH keys for GitHub Actions](02-ssh-deploy-keys.md)
