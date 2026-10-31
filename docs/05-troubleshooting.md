# 5. Troubleshooting

| Symptom | Likely cause | Check or fix |
|---|---|---|
| `502 Bad Gateway` | The app isn't running, or is on a different port than Nginx expects | `pm2 status`, `pm2 logs my-app --lines 100`, and compare `PORT` with the `upstream` port |
| `404` on page refresh in a React app | Nginx isn't falling back to `index.html` | Make sure the site uses `try_files $uri $uri/ /index.html;` |
| CI: `Permission denied (publickey)` | Wrong private key in `VPS_SSH_KEY`, or the public key isn't on the server | `cat ~/.ssh/authorized_keys` as `deploy`; permissions must be `700` on `~/.ssh` and `600` on the file |
| CI: `Host key verification failed` | `VPS_KNOWN_HOSTS` is missing or the server was rebuilt | Run `ssh-keyscan -t ed25519 <server-ip>` again and update the secret |
| Deploy rolled back on a health check | The new release didn't come up | `pm2 logs`, then test the health URL by hand with `curl -i` |
| App runs locally but not on the server | Missing environment variables | Check `/var/www/my-app/shared/.env`, then `pm2 reload my-app --update-env` |
| Changes don't show after a deploy | Browser cache, or Nginx `root` not pointing at `current` | Hard refresh; `readlink /var/www/my-app/current` |
| `nginx -t` fails after adding a site | Duplicate `map` or `upstream` names, or a missing snippet | Install `conf.d/connection-upgrade.conf` once, give each upstream a unique name, and copy `snippets/` |
| Disk filling up | Old releases or PM2 logs | Lower `--keep`; `pm2 install pm2-logrotate` |

## Useful commands

```bash
sudo tail -f /var/log/nginx/error.log     # Nginx errors
pm2 status                                # running apps
pm2 logs my-app                           # app output
ls -1 /var/www/my-app/releases            # deployed releases
readlink /var/www/my-app/current          # the live release
sudo ufw status                           # firewall rules
```
