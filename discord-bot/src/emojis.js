"use strict";

const fs = require("fs");
const path = require("path");
const state = require("./state");

const DIR = path.join(__dirname, "..", "emojis");

const PACK = [
  "lodestar",
  "gold",
  "vault",
  "profession",
  "quest",
  "pvp",
  "flask",
  "bag",
];

const PACK_VERSION = 3;

function mention(guild, name) {
  if (!guild || !guild.emojis) return "";
  const emoji = guild.emojis.cache.find((e) => e.name === name);
  return emoji ? `${emoji}` : "";
}

function pack(guild) {
  const out = {};
  for (const name of PACK) out[name] = mention(guild, name);
  return out;
}

async function ensureEmojis(guild, report) {
  if (!fs.existsSync(DIR)) {
    report.push("no emoji files found");
    return;
  }
  const current = state.guildState(guild.id).g.emojiPackVersion || 0;
  const replace = current !== PACK_VERSION;
  for (const name of PACK) {
    const existing = guild.emojis.cache.find((e) => e.name === name);
    const file = path.join(DIR, `${name}.png`);
    if (!fs.existsSync(file)) {
      report.push(`missing emoji file ${name}.png`);
      continue;
    }
    if (existing && !replace) {
      report.push(`reused emoji :${name}:`);
      continue;
    }
    try {
      if (existing) await existing.delete("Replace Lodestar emoji pack");
      await guild.emojis.create({ attachment: file, name, reason: "Lodestar Guide emoji pack" });
      report.push(`${existing ? "replaced" : "uploaded"} emoji :${name}:`);
    } catch (err) {
      report.push(`could not upload :${name}: ${err.message}`);
    }
  }
  if (replace) {
    state.patch(guild.id, (g) => {
      g.emojiPackVersion = PACK_VERSION;
    });
  }
  return { replaced: replace };
}

module.exports = { PACK, mention, pack, ensureEmojis };
