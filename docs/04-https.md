# 4. HTTPS with Let's Encrypt

Once the site answers on plain HTTP and DNS points at the server:

```bash
sudo certbot --nginx -d example.com -d www.example.com
```

Certbot gets a free certificate, adds the HTTPS server block to your Nginx site, and sets up HTTP-to-HTTPS redirects. Certificates renew automatically; check the timer and do a dry run:

```bash
systemctl list-timers | grep certbot
sudo certbot renew --dry-run
```

For an API on a subdomain, run it again with that name:

```bash
sudo certbot --nginx -d api.example.com
```

## After HTTPS works

Uncomment the `Strict-Transport-Security` line in `/etc/nginx/snippets/security-headers.conf` and reload Nginx. Browsers will then refuse plain HTTP for your domain, so only do it once every subdomain has a certificate.

Next: [5. Troubleshooting](05-troubleshooting.md)
