"use strict";

require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });

module.exports = {
  token: process.env.DISCORD_TOKEN || "",
  clientId: process.env.DISCORD_CLIENT_ID || "1542504614744821764",
  guildId: process.env.DISCORD_GUILD_ID || "1541817004531646555",
  invite: "https://discord.gg/a7hrHavcwq",
  color: 0xf2b838,
  accent: 0x59d8c9,
  links: {
    curseforge: "https://www.curseforge.com/wow/addons/lodestar-guide",
    github: "https://github.com/Co2Noss/Lodestar",
    wiki: "https://github.com/Co2Noss/Lodestar/wiki",
    issues: "https://github.com/Co2Noss/Lodestar/issues",
    releases: "https://github.com/Co2Noss/Lodestar/releases",
    paypal: "http://paypal.me/Co2Noss",
  },
};
