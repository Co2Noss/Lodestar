"use strict";

const fs = require("fs");
const path = require("path");

const FILE = path.join(__dirname, "..", "data", "state.json");

function load() {
  try {
    return JSON.parse(fs.readFileSync(FILE, "utf8"));
  } catch {
    return { guilds: {} };
  }
}

function save(state) {
  fs.mkdirSync(path.dirname(FILE), { recursive: true });
  fs.writeFileSync(FILE, JSON.stringify(state, null, 2));
}

function guildState(guildId) {
  const state = load();
  if (!state.guilds[guildId]) {
    state.guilds[guildId] = { ticketSeq: 0, channels: {}, roles: {}, messages: {} };
  }
  return { state, g: state.guilds[guildId] };
}

function patch(guildId, fn) {
  const { state, g } = guildState(guildId);
  fn(g);
  save(state);
  return g;
}

module.exports = { load, save, guildState, patch };
