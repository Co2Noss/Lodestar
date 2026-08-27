"use strict";

const fs = require("fs");
const path = require("path");

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
  for (const name of PACK) {
    const existing = guild.emojis.cache.find((e) => e.name === name);
    if (existing) {
      report.push(`reused emoji :${name}:`);
      continue;
    }
    const file = path.join(DIR, `${name}.png`);
    if (!fs.existsSync(file)) {
      report.push(`missing emoji file ${name}.png`);
      continue;
    }
    try {
      await guild.emojis.create({ attachment: file, name, reason: "Lodestar Guide emoji pack" });
      report.push(`uploaded emoji :${name}:`);
    } catch (err) {
      report.push(`could not upload :${name}: ${err.message}`);
    }
  }
}

module.exports = { PACK, mention, pack, ensureEmojis };
