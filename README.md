# opencode-custom

Image OpenCode personnalisée, construite sur `ghcr.io/anomalyco/opencode`.

Build automatique via GitHub Actions → `ghcr.io/julioskateur/opencode-custom:latest`
(également taguée avec le SHA du commit). Coolify la récupère au redéploiement.

## Contenu de l'image

| Outil | Usage |
| --- | --- |
| `gh` | CLI GitHub (binaire statique, dernière release) |
| `cloudflared` | tunnels Cloudflare (binaire statique) |
| `wrangler` | déploiements Cloudflare Pages |
| `chromium` | navigateur headless fourni par Alpine (musl-natif) |
| `playwright-core` | pilotage du navigateur depuis un script Node |
| `@playwright/mcp` | serveur MCP Playwright (outils navigateur pour l'agent) |

## Pourquoi le Chromium d'Alpine et pas `playwright install`

Alpine utilise **musl**, et les builds Chromium publiés par Playwright sont compilés
pour **glibc** : `playwright install chromium` ne fonctionne pas (Alpine n'est pas
supporté). On utilise donc le paquet `chromium` d'Alpine, musl-natif, et on le
désigne explicitement via `executablePath` → `/usr/bin/chromium`.

Installation résumée dans le `Dockerfile` :

```dockerfile
RUN apk add --no-cache ... chromium \
 && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --global playwright-core @playwright/mcp
COPY playwright-mcp.config.json /etc/playwright-mcp/config.json
```

`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` évite le téléchargement des binaires Playwright
inutilisables sur musl (et accélère le build).

## Activer le serveur MCP dans OpenCode

La configuration globale d'OpenCode (`/root/.config/opencode/opencode.json`) vit sur un
**volume persistant** : elle n'est pas dans l'image et n'est donc pas fournie par ce
dépôt. Il faut l'ajouter une fois — l'ajout survit aux redéploiements tant que le
volume est conservé.

```jsonc
{
  "mcp": {
    "servers": {
      "playwright": {
        "type": "local",
        "command": ["playwright-mcp", "--config", "/etc/playwright-mcp/config.json"],
        "timeout": { "startup": 60000, "catalog": 60000 }
      }
    }
  }
}
```

Ou en ligne de commande :

```sh
opencode mcp add playwright --global -- playwright-mcp --config /etc/playwright-mcp/config.json
```

Vérification : `opencode mcp list`, ou les logs
`~/.local/share/opencode/log/opencode.log` (`mcp connected ... tools=25`).
Le serveur MCP apparaît ensuite sous le préfixe d'outils `playwright_*`.

## Config Playwright (`playwright-mcp.config.json`)

- `executablePath` : `/usr/bin/chromium` (le Chromium d'Alpine) ;
- `headless` + `--no-sandbox` (le conteneur tourne en root) ;
- `isolated` : profil navigateur en mémoire, pas d'état résiduel ;
- `timeouts.action` porté à 15 s : le défaut de 5 s fait échouer les screenshots
  pleine page sur les pages longues.

## Utilisation

Les screenshots et snapshots générés sans chemin explicite atterrissent dans
`<workspace>/.playwright-mcp/`. Penser à ajouter ce dossier au `.gitignore` des
projets.

En script Node, il faut passer `executablePath` explicitement :

```js
import { chromium } from 'playwright-core';
const browser = await chromium.launch({
  executablePath: '/usr/bin/chromium',
  args: ['--no-sandbox'],
});
```

## Vérification rapide de l'image

```sh
gh --version && cloudflared --version && wrangler --version
chromium --version && playwright-mcp --version
```
