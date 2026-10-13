# Security

## What is safe in this repository

- **No bot token.** `DISCORD_TOKEN` is read only from `discord-bot/.env`, which is gitignored.
- **No GitHub token** unless you put one in `.env`.
- **Public links only** in `config.js` (CurseForge, GitHub, Ko-fi). Those URLs are already on the website and in SUPPORT.md.

## What was removed from the repo

Older commits may still show Discord application ID, guild ID, and staff user IDs in `config.js` or `.env.example`. Those are not secrets like a token, but they identify your server and account. They now live only in your private `.env`.

If you are worried those IDs were public:

1. **Rotate the bot token** in the [Discord Developer Portal](https://discord.com/developers/applications) → your app → Bot → **Reset Token**. Update `discord-bot/.env` and anywhere you host the bot (VPS, Railway, etc.).
2. Keep `.env` out of git. Never commit it, paste it in issues, or upload it to a gist.

## Can someone clone this repo and run *your* bot?

**Not without your bot token.** The token is the only credential that lets a process log in as your application.

Someone can clone the code and run **their own** bot with **their own** Discord application and token. That is normal for open-source bot code; it is not your bot.

This codebase also **refuses to operate outside the guild ID in `DISCORD_GUILD_ID`**. If the bot is invited to another server, it leaves immediately and ignores commands there. That stops a stolen token from being used to run your support layout on a random server (though you should still rotate the token if you think it leaked).

## Hosting checklist

- [ ] `discord-bot/.env` exists only on the machine that runs the bot
- [ ] Bot token rotated after any suspicion of leak
- [ ] `DISCORD_GUILD_ID` set to your support server only
- [ ] `GITHUB_TOKEN` in `.env` only if you use Contributor sync (optional, scoped token)
- [ ] `data/state.json` is gitignored (stores webhook URLs for GitHub feeds)

## Reporting

If you find a credential committed to this repository, open a private security note or email the maintainer. Do not post tokens in public issues.
