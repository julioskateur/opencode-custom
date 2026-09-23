FROM ghcr.io/anomalyco/opencode:2.0.7

# gh CLI et cloudflared en binaires statiques (fonctionne quelle que soit la distro de base)
# Wrangler est installe via npm pour piloter les services developpeurs Cloudflare.
#
# Playwright : les builds officiels de Chromium ne sont pas compatibles musl
# (Alpine n'est pas supporte par `playwright install`). On pilote donc le
# Chromium d'Alpine, musl-natif, via executablePath -> /usr/bin/chromium.
# Voir playwright-mcp.config.json et la section "Playwright" du README.
RUN apk add --no-cache curl tar ca-certificates nodejs npm chromium \
 && GH_VERSION=$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest | grep -m1 '"tag_name"' | cut -d'"' -f4 | tr -d v) \
 && curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_amd64.tar.gz" -o /tmp/gh.tar.gz \
 && tar -xzf /tmp/gh.tar.gz -C /tmp \
 && mv /tmp/gh_*/bin/gh /usr/local/bin/gh \
 && rm -rf /tmp/gh* \
 && curl -fsSL -o /usr/local/bin/cloudflared https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
 && chmod +x /usr/local/bin/cloudflared \
 && npm install --global wrangler@latest \
 && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --global playwright-core @playwright/mcp \
 && gh --version \
 && cloudflared --version \
 && wrangler --version \
 && chromium --version \
 && playwright-mcp --version

# Config du serveur MCP Playwright : Chromium d'Alpine + timeouts adaptes
# aux pages longues (le defaut de 5 s fait echouer les screenshots pleine page).
COPY playwright-mcp.config.json /etc/playwright-mcp/config.json
