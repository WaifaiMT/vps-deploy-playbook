// PM2 config for a Node.js or Next.js app deployed with scripts/deploy.sh.
// Commit this to your app's repo root; deploy.sh uses it on the first start.
// Secrets live in /var/www/<app>/shared/.env, which deploy.sh links into each release.
module.exports = {
  apps: [
    {
      name: "my-app",
      // `current` always points at the live release, so reloads pick up new code
      cwd: "/var/www/my-app/current",
      script: "npm",
      args: "start",
      instances: 1,
      exec_mode: "fork",
      max_memory_restart: "500M",
      env: {
        NODE_ENV: "production",
        PORT: 3000,
      },
      time: true,
    },
  ],
};
