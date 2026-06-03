# Legal pages (Privacy & Terms)

Static pages for App Store compliance. The mobile app links to:

- `https://gainsai.net/privacy`
- `https://gainsai.net/terms`

## Deploy on Hetzner (Caddy)

On your VPS, copy this folder to the web root:

```bash
# From your laptop (or clone repo on server)
scp -r docs/legal/* root@YOUR_SERVER:/var/www/gainsai/
```

Expected layout on the server:

```text
/var/www/gainsai/
  styles.css
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
curl -sI https://gainsai.net/privacy
curl -sI https://gainsai.net/terms
```

Both should return `200`. Open the URLs on your phone before App Store submit.

## App Store Connect

- **Privacy Policy URL:** `https://gainsai.net/privacy`
- Complete the **App Privacy** questionnaire to match data described in `privacy/index.html`

## Editing

Update `privacy/index.html` or `terms/index.html`, redeploy to `/var/www/gainsai/`, and bump the “Last updated” date.

These documents are templates aligned with Gains features—not legal advice. Have a lawyer review before a large public launch if you want extra certainty.
