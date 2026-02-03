# discord-indexer-dotnet

Discord → MongoDB indexer with backfill + rate limit coordination.

## One-line install (Linux)

Installs the **latest GitHub Release** (`discord-indexer` + `discord-indexer-search`) to `/usr/local/bin`.

```bash
curl -fsSL https://raw.githubusercontent.com/patrick-slimelab/discord-indexer-dotnet/master/install.sh | sudo bash
```

### OpenClaw auto-token

If the installer detects an OpenClaw state dir at one of:

- `~/.openclaw`
- `~/.moltbot`
- `~/.clawdbot`

…it will parse the JSON config and, if present, use:

- `channels.discord.token`

…and write `/etc/discord-indexer/indexer.env` (mode `0600`).

## Releases

Releases include:
- `discord-indexer-linux-x64.tar.gz`
- `discord-indexer-linux-x64.sha256`

## Notes

- The installer does **not** print tokens.
- MongoDB connection is controlled by env vars (`MONGODB_URI`, `MONGODB_DB`).
