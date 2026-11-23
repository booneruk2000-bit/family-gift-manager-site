# Family Gift Manager — Website & Privacy Policy

A lightweight, responsive, and elegant website for **Family Gift Manager** (Web & Android), built primarily to host the application's **Privacy Policy** covering **Google AdSense**, **Google AdMob**, and **UK/EU GDPR consent** requirements, along with a standalone installer daemon for **Debian 13 (Trixie) LXC** containers.

## Project Structure

```text
family-gift-manager-site/
├── site/
│   ├── index.html               # Responsive landing page
│   ├── privacy-policy.html      # Full Privacy Policy template (AdSense, AdMob, UK/EU GDPR)
│   ├── 404.html                 # Custom 404 page
│   ├── ads.txt                  # Google AdSense ads.txt template
│   ├── app-ads.txt              # Google AdMob app-ads.txt template
│   └── assets/
│       ├── css/styles.css       # Responsive stylesheet + print styles
│       ├── js/main.js           # Mobile nav, TOC scroll spy, print button
│       └── img/favicon.svg      # Vector favicon
├── config/
│   ├── Caddyfile.template                       # Clean URLs, security headers, gzip/zstd
│   └── family-gift-manager.service.template     # Dedicated systemd daemon unit
└── scripts/
    ├── install.sh               # Standalone Debian 13 LXC installer
    └── update.sh                # Pull latest `main` branch and reload daemon
```

## Quick Install on Debian 13 (Trixie) LXC

Run the standalone installer inside your Debian 13 LXC container as `root` (or with `sudo`). It installs all prerequisites (`git`, `curl`, `ca-certificates`, `caddy`), clones the latest `main` branch into `/opt/family-gift-manager`, and sets up the `family-gift-manager.service` systemd daemon:

```bash
curl -fsSL https://raw.githubusercontent.com/booneruk2000-bit/family-gift-manager-site/main/scripts/install.sh | sudo bash
```

### Custom Port (Behind Reverse Proxy / Cloudflare Tunnel)

```bash
curl -fsSL https://raw.githubusercontent.com/booneruk2000-bit/family-gift-manager-site/main/scripts/install.sh | sudo bash -s -- --port 8080
```

### Direct Domain with Automatic HTTPS (Let's Encrypt via Caddy)

```bash
curl -fsSL https://raw.githubusercontent.com/booneruk2000-bit/family-gift-manager-site/main/scripts/install.sh | sudo bash -s -- --domain familygiftmanager.example.com
```

### Managing the Daemon

```bash
# Check status
systemctl status family-gift-manager

# Follow logs
journalctl -u family-gift-manager -f

# Pull latest changes from main and reload
sudo /opt/family-gift-manager/scripts/update.sh
```

## Customizing the Privacy Policy Template

1. Open `site/privacy-policy.html` on the `dev` branch.
2. Search for `class="placeholder"` and replace every bracketed `[placeholder]` with your real details (effective date, controller/developer name, contact email, domain, Android package name, hosting provider, etc.).
3. Remove the `<div class="template-notice">...</div>` banner at the top of the policy once reviewed.
4. Update `site/ads.txt` (for AdSense) and `site/app-ads.txt` (for AdMob) with your real Google Publisher ID (`pub-xxxxxxxxxxxxxxxx`).
5. Merge `dev` into `main`, then run `sudo /opt/family-gift-manager/scripts/update.sh` on your Debian 13 LXC.

## Clean URLs Included

- `/` — Landing page
- `/privacy-policy` (and `/privacy`) — Privacy Policy (ideal for Google Play Console, AdMob, and AdSense)
- `/ads.txt` — Google AdSense verification file
- `/app-ads.txt` — Google AdMob verification file

## Branching Workflow

- `dev` — Day-to-day edits, policy updates, and styling changes.
- `main` — Production branch pulled automatically by `scripts/install.sh` and `scripts/update.sh`.
