"use strict";

const { EmbedBuilder } = require("discord.js");
const config = require("./config");

/** @typedef {{ id: string, title: string, keywords: string[], body: string }} Faq */

/** @type {Faq[]} */
const FAQS = [
  {
    id: "install",
    title: "Install Lodestar",
    keywords: ["install", "download", "curseforge", "addon", "folder", "addons"],
    body: [
      "Install from [CurseForge](https://www.curseforge.com/wow/addons/lodestar-guide) or the [GitHub release](https://github.com/Co2Noss/Lodestar/releases).",
      "The folder must be `Interface\\\\AddOns\\\\Lodestar` with `Lodestar.toc` inside it. Restart the client or `/reload`.",
      "Open with `/ls` or the minimap button.",
    ].join("\n"),
  },
  {
    id: "commands",
    title: "Chat commands",
    keywords: ["command", "slash", "/ls", "minimap"],
    body: [
      "`/ls` — open or close the window",
      "`/ls compact` — compact mode",
      "`/ls compact single` — one-row compact mode",
      "`/ls theme auto` — also `blizzard`, `elvui`, `ellesmere`, `gw2`, `realui`, `minimal`",
      "`/ls debug` — disable every other addon and reload",
      "`/ls debug off` — restore those addons (this character only)",
      "`/ls reset` — wipe saved settings and reload",
      "Left-click the minimap button for the full window. Right-click for compact mode.",
    ].join("\n"),
  },
  {
    id: "goals",
    title: "Nothing on Today's Plan",
    keywords: ["empty", "nothing", "today", "plan", "goal", "welcome", "first login"],
    body: [
      "Nothing is ranked until you turn a goal on. First login opens the welcome page for that reason.",
      "A goal that is off is hidden on purpose. Change it in Settings → Goals.",
      "Existing installs keep the goals you already chose, so the welcome page does not interrupt an upgrade.",
    ].join("\n"),
  },
  {
    id: "debug",
    title: "Is this Lodestar erroring?",
    keywords: ["error", "bug", "lua", "stack", "crash", "isolate", "debug"],
    body: [
      "`/ls debug` turns off every non-Blizzard addon except Lodestar, then reloads. Reproduce the problem.",
      "If it still happens, it is Lodestar (or the client). If it does not, another addon was involved.",
      "`/ls debug` again, or `/ls debug off`, restores the addons that were on. Isolation is per character and will not run in combat.",
    ].join("\n"),
  },
  {
    id: "gold",
    title: "Gold making is quiet",
    keywords: ["gold", "tsm", "auctionator", "recrystallize", "price", "auction"],
    body: [
      "Gold making needs **TradeSkillMaster**, **Auctionator**, or **RECrystallize**. Lodestar does not invent an auction house.",
      "Settings → Optional Addons picks the source. Auto uses the first of those addons that is loaded.",
      "If none is loaded, or the one you picked is not, Lodestar stays quiet about gold.",
    ].join("\n"),
  },
  {
    id: "rares",
    title: "Rares are missing",
    keywords: ["rare", "handynotes", "treasure", "pin", "midnight", "silvermoon"],
    body: [
      "Rares need **HandyNotes** plus a notes pack. HandyNotes by itself has no coordinates.",
      "Packs such as Midnight and Silvermoon supply the pins. Lodestar ranks rares, not treasures or other map marks.",
      "Known rewards stay hidden if the pack hid them. Without a pack, Lodestar stays quiet about rares.",
    ].join("\n"),
  },
  {
    id: "vault",
    title: "Great Vault is off the plan",
    keywords: ["vault", "great vault", "cap", "level", "90", "midnight", "unclaimed"],
    body: [
      "Great Vault and bountiful delves stay off the plan until you are at the expansion cap (90 in Midnight).",
      "Until then Lodestar ranks leveling, and professions if that goal is on.",
      "If last week's Great Vault is still unclaimed after Tuesday reset, Today ranks that first.",
    ].join("\n"),
  },
  {
    id: "optional",
    title: "Optional addons",
    keywords: ["optional", "elvui", "tomtom", "raider", "gw2", "realui", "dependency"],
    body: [
      "Lodestar works on its own. Other addons unlock extra behaviour if they are loaded:",
      "• **TSM / Auctionator / RECrystallize** — gold prices",
      "• **Raider.IO** — colours the Mythic+ tile. Without it, the tile still shows the client's mythic rating",
      "• **TomTom** — multiple waypoints and a closest-arrow",
      "• **HandyNotes** plus a notes pack — rares",
      "• **ElvUI / GW2 UI / RealUI** — live theme colours",
      "Settings → Optional Addons lists each one as Loaded or Not loaded.",
    ].join("\n"),
  },
  {
    id: "themes",
    title: "Themes and colours",
    keywords: ["theme", "elvui", "colour", "color", "appearance", "font", "blizzard"],
    body: [
      "Auto follows GW2 UI, RealUI, or ElvUI when those addons are loaded. `/ls theme` lists the palettes.",
      "ElvUI's default border is near-black; Lodestar uses a lighter grey unless that border is actually visible.",
      "Settings → Appearance overrides any theme colour. Your choices survive switching themes. Reset colors to the theme drops them all at once.",
    ].join("\n"),
  },
  {
    id: "dashboard",
    title: "Dashboard tiles",
    keywords: ["dashboard", "widget", "tile", "edit", "canvas", "layout"],
    body: [
      "Edit dashboard to add, remove, or drag tiles on a 12 × 18 canvas. Tiles cannot overlap.",
      "While you are editing, a tile shows its settings rather than live Honor, gold, or house favor. Click Done editing to see the data again.",
      "Rares stay out of the add list until HandyNotes plus a notes pack is loaded. Other addons can pin a tile with `Lodestar:RegisterWidget`.",
    ].join("\n"),
  },
  {
    id: "compact",
    title: "Compact mode",
    keywords: ["compact", "tracker", "small"],
    body: [
      "Compact mode is a small window of the activities you tracked. Toggle it in Settings, with `/ls compact`, or by right-clicking the minimap button.",
      "Click an entry for details. Double-click to open Progress. It hides while the full window is open and collapses to the title bar in combat.",
    ].join("\n"),
  },
  {
    id: "knowledge",
    title: "Profession knowledge",
    keywords: ["knowledge", "profession", "treatise", "patron", "catch-up", "catchup"],
    body: [
      "Skill, unspent knowledge, and remaining tree cost come from live APIs. Weekly treatises, trainer quests, gathering drops, and treasures are in `Knowledge.lua`.",
      "Catch-up from Patron Orders cannot be counted from the client, so Lodestar describes it instead of inventing a number.",
      "Dashboard and Warband unspent-knowledge totals filter to the current expansion, so leftover points from older expansions do not look like work still to do.",
    ].join("\n"),
  },
  {
    id: "waypoints",
    title: "Waypoints and TomTom",
    keywords: ["waypoint", "tomtom", "map", "pin", "arrow"],
    body: [
      "Treasure cards with a known location have a Waypoint button. Settings → Goals chooses Auto (TomTom when loaded), TomTom, or the client's single map pin.",
      "The client's pin is one super-tracked waypoint; choosing it ignores TomTom even if that addon is installed.",
      "HandyNotes rares get the same button. Bountiful delves pin from the map POIs when the client names them.",
    ].join("\n"),
  },
  {
    id: "housing",
    title: "Housing tile",
    keywords: ["housing", "house", "neighborhood", "teleport", "no house"],
    body: [
      "Housing is a goal. A missing house, unfinished neighborhood initiatives, and weekly housing quests already in the log rank while that goal is on.",
      "Lodestar does not invent plots or housing quest IDs. The tile shows house level and favor the client reports.",
      "If the tile says No house while the Housing Dashboard shows one, `/reload` after visiting the house so the client events fire.",
    ].join("\n"),
  },
  {
    id: "pets",
    title: "Battle Pets",
    keywords: ["pet", "pets", "journal", "battle pet"],
    body: [
      "Battle Pets is a goal. Locked journal slots, an empty team, and pet battle quests already in the log rank while that goal is on.",
      "Lodestar does not invent species IDs or a catching circuit. The tile shows unique pets and your team from `C_PetJournal`.",
    ].join("\n"),
  },
  {
    id: "reset",
    title: "Reset Lodestar",
    keywords: ["reset", "wipe", "savedvariables", "corrupt"],
    body: [
      "`/ls reset` wipes saved settings and reloads. Debug isolation (`/ls debug`) survives that wipe, so you can still restore other addons with `/ls debug off`.",
      "The welcome page will ask for goals again after a reset.",
    ].join("\n"),
  },
  {
    id: "bug",
    title: "Report a bug",
    keywords: ["report", "github", "issue", "ticket", "feedback"],
    body: [
      "Questions and install help belong here on Discord. Reproducible bugs go to [GitHub issues](https://github.com/Co2Noss/Lodestar/issues).",
      "Include class/spec, the theme you use (Blizzard, ElvUI, or other), Lodestar version, and what you expected versus what happened.",
      "If you are not sure Lodestar is the addon erroring, `/ls debug` isolates it.",
    ].join("\n"),
  },
];

function findFaq(query) {
  const q = String(query || "")
    .trim()
    .toLowerCase();
  if (!q) return null;
  const exact = FAQS.find((f) => f.id === q || f.title.toLowerCase() === q);
  if (exact) return exact;
  const scored = FAQS.map((f) => {
    let score = 0;
    if (f.id.includes(q) || q.includes(f.id)) score += 5;
    if (f.title.toLowerCase().includes(q)) score += 4;
    for (const word of f.keywords) {
      if (word === q) score += 6;
      else if (q.includes(word) || word.includes(q)) score += 2;
    }
    return { f, score };
  })
    .filter((x) => x.score > 0)
    .sort((a, b) => b.score - a.score);
  return scored[0] ? scored[0].f : null;
}

function suggestFaq(text) {
  const q = String(text || "").toLowerCase();
  if (q.length < 8) return null;
  let best = null;
  let bestScore = 0;
  for (const f of FAQS) {
    let score = 0;
    for (const word of f.keywords) {
      if (word.length < 4) continue;
      if (q.includes(word)) score += word.length > 6 ? 3 : 2;
    }
    if (score > bestScore) {
      best = f;
      bestScore = score;
    }
  }
  return bestScore >= 4 ? best : null;
}

function faqChoices() {
  return FAQS.map((f) => ({ name: f.title, value: f.id }));
}

function faqEmbed(faq) {
  return new EmbedBuilder()
    .setColor(config.color)
    .setTitle(faq.title)
    .setDescription(faq.body)
    .setFooter({ text: "Lodestar · /faq for more" });
}

function linksEmbed() {
  const { links, color } = config;
  return new EmbedBuilder()
    .setColor(color)
    .setTitle("Lodestar")
    .setDescription("Find what matters. Ignore the rest.")
    .addFields(
      { name: "CurseForge", value: links.curseforge },
      { name: "GitHub", value: links.github },
      { name: "Wiki", value: links.wiki },
      { name: "Issues", value: links.issues },
      { name: "Discord", value: config.invite },
      {
        name: "Support the project",
        value: `[Ko-fi](${links.kofi}) · [GitHub Sponsors](${links.sponsors}) · [PayPal](${links.paypal})`,
      }
    );
}

module.exports = {
  FAQS,
  findFaq,
  suggestFaq,
  faqChoices,
  faqEmbed,
  linksEmbed,
};
