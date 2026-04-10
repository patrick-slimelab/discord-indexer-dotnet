---
name: discord-indexer
description: Search and inspect a local Discord message index backed by MongoDB using the repository's discord-indexer-search and discord-indexer-delta helpers. Use when a user asks to find prior Discord messages, retrieve server-wide deltas since a timestamp, test whether indexing works, look up mentions of a person, phrase, or topic, inspect results by channel or time, or troubleshoot whether a Discord archive/index contains expected content.
---

# Discord Indexer

Use the local helper scripts from the repository root:

```bash
./discord-indexer-search <query>
./discord-indexer-delta --since 2026-04-09T00:00:00Z
```

Agent note: when you need delta retrieval, prefer the checked-in executable wrapper (`./discord-indexer-delta`) or the installed `discord-indexer-delta` binary, and do not assume an unverified Python path like `discord_indexer_delta.py`. This is guidance for the agent’s own command choice, not a restriction on what a human user may choose to run.

## Workflow

1. Run searches from the repo root so the helper script is available.
2. Start with a narrow literal query when possible: a name, exact phrase, channel idea, or identifier.
3. If the first query is noisy, refine with more distinctive terms instead of repeating the same broad search.
4. For server-wide or channel-wide delta retrieval, prefer `./discord-indexer-delta --since ...` instead of trying to fake it with keyword search.
5. If a delta call fails, verify the helper path first (`./discord-indexer-delta --help` from repo root, or `discord-indexer-delta --help` if installed) before assuming the index or service is broken.
6. Return a short summary plus a few representative hits with timestamp, guild/channel ids, author, and message excerpt.
7. If a search still fails after the helper-path check, check whether the indexer service and MongoDB are running before assuming the data is missing.

## Output handling

The helpers print tab-separated rows in this shape (with `discord-indexer-delta` also adding channel name):

- ISO timestamp
- guild id
- channel id
- author
- message text

Preserve ids when reporting uncertain/private channels. Do not guess channel names you cannot resolve.

## Troubleshooting

If search output is empty or errors:

- check `systemctl status discord-indexer.service`
- check whether MongoDB is reachable at the configured `MONGODB_URI`
- inspect recent indexer logs in `/var/log/discord-indexer/`
- confirm the target channel is actually accessible to the bot; private channels may produce partial metadata and 403s

## References

- For helper behavior and Mongo execution details, read `references/helper.md`.
