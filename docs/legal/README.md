# Legal pages (Privacy, Terms & Support)

Static pages for App Store compliance. The mobile app links to:

- `https://gainsai.net/privacy`
- `https://gainsai.net/terms`
- `https://gainsai.net/support`

## Deploy on Hetzner (Caddy)

On your VPS, copy this folder to the web root:

```bash
# From your laptop (in the gainsai repo folder)
scp -r docs/legal/* root@YOUR_HETZNER_IP:/var/www/gainsai/
```

Or on the server if the repo is already there:

```bash
sudo mkdir -p /var/www/gainsai
sudo cp -r /path/to/gainsai/docs/legal/* /var/www/gainsai/
```

Expected layout on the server:

```text
/var/www/gainsai/
  index.html
  styles.css
  support/index.html
  privacy/index.html
  terms/index.html
```

### Caddyfile (apex domain)

Add a site block for the marketing/legal host (keep `api.gainsai.net` separate):

```caddy
gainsai.net, www.gainsai.net {
    root * /var/www/gainsai
    file_server
    try_files {path} {path}/index.html
    encode gzip
}
```

Reload Caddy:

```bash
sudo systemctl reload caddy
```

### DNS (Namecheap)

| Host | Type | Value |
|------|------|--------|
| `@` | A | Your Hetzner IP |
| `www` | A or CNAME | Same |

`api.gainsai.net` stays pointed at the same IP with its existing API block.

### Verify

```bash
curl -sI https://gainsai.net/
curl -sI https://gainsai.net/support
curl -sI https://gainsai.net/privacy
curl -sI https://gainsai.net/terms
```

All should return `200`. Open the URLs on your phone before App Store submit.

## App Store Connect

- **Privacy Policy URL:** `https://gainsai.net/privacy`
- **Support URL:** `https://gainsai.net/support`
- Complete the **App Privacy** questionnaire to match data described in `privacy/index.html`

## Editing

Update `privacy/index.html` or `terms/index.html`, redeploy to `/var/www/gainsai/`, and bump the “Last updated” date.

These documents are templates aligned with Gains features—not legal advice. Have a lawyer review before a large public launch if you want extra certainty.
