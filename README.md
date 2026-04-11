# discord-indexer-dotnet

Discord → MongoDB indexer with backfill + rate limit coordination.

## OpenClaw Skill

This repo includes an OpenClaw skill for searching indexed Discord messages.

### Install Skill (One-liner)

```bash
rm -rf ~/.openclaw/skills/discord-indexer && mkdir -p ~/.openclaw/skills && git clone --depth 1 https://github.com/patrick-slimelab/discord-indexer-dotnet /tmp/discord-indexer && mv /tmp/discord-indexer/skill/discord-indexer ~/.openclaw/skills/ && rm -rf /tmp/discord-indexer
```

### Alternative: Use extraDirs (no install needed)

Add to `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "load": {
      "extraDirs": ["~/discord-indexer-dotnet/skill"]
    }
  }
}
```

Then clone the repo:
```bash
git clone https://github.com/patrick-slimelab/discord-indexer-dotnet ~/discord-indexer-dotnet
```

## One-line install (Linux)

Installs the **latest GitHub Release** (`discord-indexer`, `discord-indexer-search`, and `discord-indexer-delta`) to `/usr/local/bin`.

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

## Helpers

- `discord-indexer-search <text> [--guild ...] [--channel ...] [--limit N]`
- `discord-indexer-delta --since <timestamp|epoch_ms> [--guild ...] [--channel ...] [--limit N] [--format tsv|jsonl]`

`discord-indexer-delta` is the server-wide delta retrieval helper: by default it returns indexed messages across all readable channels since the requested timestamp, optionally narrowed to one guild or one channel.

## Notes

- The installer does **not** print tokens.
- MongoDB connection is controlled by env vars (`MONGODB_URI`, `MONGODB_DB`).
- "All channels" means channels the bot was actually able to enumerate/read/index. Private or forbidden channels will not appear.
