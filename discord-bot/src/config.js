"use strict";

const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

function required(name) {
  const value = process.env[name];
  if (!value || !String(value).trim()) return null;
  return String(value).trim();
}

function csv(name) {
  return (required(name) || "")
    .split(",")
    .map((part) => part.trim())
    .filter(Boolean);
}

// discordId:githubLogin pairs, e.g. 123456789012345678:Co2Noss
function parseGithubLinks(raw) {
  const out = {};
  for (const part of String(raw || "").split(",")) {
    const chunk = part.trim();
    if (!chunk) continue;
    const sep = chunk.indexOf(":");
    if (sep <= 0) continue;
    const discordId = chunk.slice(0, sep).trim();
    const login = chunk.slice(sep + 1).trim();
    if (discordId && login) out[discordId] = login;
  }
  return out;
}

const config = {
  token: required("DISCORD_TOKEN") || "",
  clientId: required("DISCORD_CLIENT_ID") || "",
  guildId: required("DISCORD_GUILD_ID") || "",
  developerUserIds: csv("DEVELOPER_USER_IDS"),
  verifyMinAccountAgeMs: (Number(process.env.VERIFY_MIN_ACCOUNT_AGE_HOURS) || 1) * 60 * 60 * 1000,
  invite: process.env.DISCORD_INVITE_URL || "https://discord.gg/a7hrHavcwq",
  color: 0xf2b838,
  accent: 0x59d8c9,
  links: {
    curseforge: "https://www.curseforge.com/wow/addons/lodestar-guide",
    github: "https://github.com/Co2Noss/Lodestar",
    wiki: "https://github.com/Co2Noss/Lodestar/wiki",
    issues: "https://github.com/Co2Noss/Lodestar/issues",
    releases: "https://github.com/Co2Noss/Lodestar/releases",
    paypal: "http://paypal.me/Co2Noss",
    kofi: "https://ko-fi.com/co2noss",
    sponsors: "https://github.com/sponsors/Co2Noss",
  },
  githubRepo: process.env.GITHUB_REPO || "Co2Noss/Lodestar",
  githubToken: process.env.GITHUB_TOKEN || "",
  githubLinks: parseGithubLinks(process.env.GITHUB_LINKS),
};

function missingConfig() {
  const need = [];
  if (!config.token) need.push("DISCORD_TOKEN");
  if (!config.clientId) need.push("DISCORD_CLIENT_ID");
  if (!config.guildId) need.push("DISCORD_GUILD_ID");
  if (config.developerUserIds.length === 0) need.push("DEVELOPER_USER_IDS");
  return need;
}

config.missing = missingConfig;
config.isAllowedGuild = (guild) => Boolean(guild && guild.id === config.guildId);
config.parseGithubLinks = parseGithubLinks;

module.exports = config;
