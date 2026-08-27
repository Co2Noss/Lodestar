"use strict";

const { SlashCommandBuilder, EmbedBuilder, MessageFlags } = require("discord.js");
const config = require("./config");
const state = require("./state");
const { isStaff, roleByName } = require("./staff");
const emojis = require("./emojis");

const LOGIN_RE = /^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$/;
const BOT_LOGIN_RE = /\[bot\]$/i;
const NOISE = new Set([
  "new", "the", "and", "from", "with", "commit", "commits", "pull", "request", "opened", "merged",
  "lodestar", "main", "master", "compare",
]);

function normalizeLogin(raw) {
  const s = String(raw || "").trim().replace(/^@/, "");
  if (!LOGIN_RE.test(s) || BOT_LOGIN_RE.test(s)) return null;
  if (NOISE.has(s.toLowerCase())) return null;
  return s;
}

function parseLoginsFromText(text) {
  const found = new Set();
  const body = String(text || "");
  const patterns = [
    /\b(?:opened|merged|closed|review requested)\s+by\s+@?([A-Za-z0-9-]{1,39})\b/gi,
    /\bby\s+@?([A-Za-z0-9-]{1,39})\b/gi,
    /\bauthor[:\s]+@?([A-Za-z0-9-]{1,39})\b/gi,
  ];
  for (const re of patterns) {
    let m;
    while ((m = re.exec(body))) {
      const login = normalizeLogin(m[1]);
      if (login) found.add(login.toLowerCase());
    }
  }
  return [...found];
}

function githubHeaders() {
  const headers = {
    "User-Agent": "Lodestar-Support-Bot",
    Accept: "application/vnd.github+json",
  };
  if (config.githubToken) headers.Authorization = `Bearer ${config.githubToken}`;
  return headers;
}

async function githubJson(path) {
  const res = await fetch(`https://api.github.com${path}`, { headers: githubHeaders() });
  if (!res.ok) {
    const err = new Error(`GitHub ${res.status} ${path}`);
    err.status = res.status;
    throw err;
  }
  return res.json();
}

async function githubUserExists(login) {
  try {
    const res = await fetch(`https://api.github.com/users/${encodeURIComponent(login)}`, { headers: githubHeaders() });
    return res.ok;
  } catch {
    return false;
  }
}

function isBotLogin(login, type) {
  if (!login) return true;
  if (BOT_LOGIN_RE.test(login)) return true;
  if (type && String(type).toLowerCase() === "bot") return true;
  return false;
}

async function fetchContributorLogins(repo) {
  const name = repo || config.githubRepo;
  const logins = new Set();
  const contributors = await githubJson(`/repos/${name}/contributors?per_page=100&anon=false`);
  if (Array.isArray(contributors)) {
    for (const c of contributors) {
      if (isBotLogin(c.login, c.type)) continue;
      logins.add(c.login.toLowerCase());
    }
  }
  const pulls = await githubJson(`/repos/${name}/pulls?state=all&per_page=100`);
  if (Array.isArray(pulls)) {
    for (const p of pulls) {
      const user = p.user;
      if (!user || isBotLogin(user.login, user.type)) continue;
      logins.add(user.login.toLowerCase());
    }
  }
  return logins;
}

function linksOf(guildId) {
  return state.guildState(guildId).g.githubLinks || {};
}

function seedLinks(guildId) {
  const seeded = config.githubLinks || {};
  return state.patch(guildId, (g) => {
    if (!g.githubLinks) g.githubLinks = {};
    for (const [discordId, login] of Object.entries(seeded)) {
      if (!g.githubLinks[discordId]) g.githubLinks[discordId] = login;
    }
  }).githubLinks;
}

function loginFor(guildId, discordId) {
  const links = { ...seedLinks(guildId), ...linksOf(guildId) };
  return links[discordId] || null;
}

function discordIdForLogin(guildId, login) {
  const want = String(login || "").toLowerCase();
  const links = { ...seedLinks(guildId), ...linksOf(guildId) };
  for (const [id, value] of Object.entries(links)) {
    if (String(value).toLowerCase() === want) return id;
  }
  return null;
}

function setLink(guildId, discordId, login) {
  return state.patch(guildId, (g) => {
    if (!g.githubLinks) g.githubLinks = {};
    for (const [id, value] of Object.entries(g.githubLinks)) {
      if (id !== discordId && String(value).toLowerCase() === login.toLowerCase()) {
        delete g.githubLinks[id];
      }
    }
    g.githubLinks[discordId] = login;
  });
}

function clearLink(guildId, discordId) {
  return state.patch(guildId, (g) => {
    if (!g.githubLinks) g.githubLinks = {};
    delete g.githubLinks[discordId];
  });
}

function commands() {
  return [
    new SlashCommandBuilder()
      .setName("github")
      .setDescription("Link your GitHub for Contributor credit, or staff: grant it.")
      .setDMPermission(false)
      .addSubcommand((s) =>
        s
          .setName("link")
          .setDescription("Link your GitHub username so commits and PRs grant Contributor")
          .addStringOption((opt) => opt.setName("username").setDescription("GitHub username").setRequired(true))
      )
      .addSubcommand((s) => s.setName("unlink").setDescription("Remove your linked GitHub username"))
      .addSubcommand((s) =>
        s
          .setName("credit")
          .setDescription("Staff: give Contributor to a member")
          .addUserOption((opt) => opt.setName("user").setDescription("Member").setRequired(true))
          .addStringOption((opt) => opt.setName("username").setDescription("Their GitHub username").setRequired(false))
      )
      .addSubcommand((s) => s.setName("sync").setDescription("Staff: re-check GitHub commits and pull requests")),
  ].map((c) => c.toJSON());
}

function panel(guild) {
  const star = emojis.mention(guild, "profession");
  const repo = config.links.github;
  const embed = new EmbedBuilder()
    .setColor(config.color)
    .setTitle(star ? `${star}  Contributors` : "Contributors")
    .setDescription(
      [
        "If you push a **commit** or open a **pull request** on Lodestar, you get the **Contributor** role.",
        "",
        "1. `/github link YourGitHubUsername`",
        "2. Land a commit or open a PR on [GitHub](" + repo + ")",
        "3. The bot grants **Contributor** (it also checks GitHub on startup and every so often)",
        "",
        "Staff can `/github credit @someone` if the GitHub name does not match.",
      ].join("\n")
    );
  return { embeds: [embed] };
}

function resolveMember(guild, login) {
  const mapped = discordIdForLogin(guild.id, login);
  if (mapped) return guild.members.cache.get(mapped) || null;
  const want = login.toLowerCase();
  const matches = [...guild.members.cache.values()].filter((m) => {
    if (m.user.bot) return false;
    return m.user.username.toLowerCase() === want || (m.displayName && m.displayName.toLowerCase() === want);
  });
  return matches.length === 1 ? matches[0] : null;
}

async function grantContributor(member, reason) {
  const role = roleByName(member.guild, "Contributor");
  if (!role) return false;
  if (member.roles.cache.has(role.id)) return false;
  await member.roles.add(role, reason);
  return true;
}

async function announceCredit(guild, member, login, how) {
  const channel = guild.channels.cache.find((c) => c.name === "github" && c.isTextBased());
  if (!channel) return;
  const label = login ? `GitHub \`${login}\`` : "their GitHub work";
  await channel.send({
    content: `${member} earned **Contributor** for ${label}${how ? ` (${how})` : ""}.`,
    allowedMentions: { users: [member.id] },
  }).catch(() => {});
}

async function creditLogin(guild, login, how, mappedOnly) {
  const member = mappedOnly
    ? (guild.members.cache.get(discordIdForLogin(guild.id, login) || "") || null)
    : resolveMember(guild, login);
  if (!member) return false;
  const added = await grantContributor(member, `Lodestar GitHub contributor ${login}`);
  if (added) await announceCredit(guild, member, login, how);
  return added;
}

async function syncGuild(guild, report) {
  seedLinks(guild.id);
  let logins;
  try {
    logins = await fetchContributorLogins();
  } catch (err) {
    if (report) report.push(`GitHub sync failed: ${err.message}`);
    return { credited: 0, logins: new Set() };
  }
  try {
    await guild.members.fetch();
  } catch {
    // member intent missing
  }
  let credited = 0;
  for (const login of logins) {
    if (await creditLogin(guild, login, "GitHub")) credited += 1;
  }
  if (report) report.push(`GitHub contributors: ${logins.size} login${logins.size === 1 ? "" : "s"}, granted Contributor to ${credited}`);
  return { credited, logins };
}

async function maybeCreditFromMessage(message) {
  if (!message.guild || message.author && message.author.id === message.client.user.id) return false;
  const name = message.channel && message.channel.name;
  if (name !== "git-commits" && name !== "github") return false;
  const chunks = [message.content];
  for (const embed of message.embeds || []) {
    chunks.push(embed.title, embed.description, embed.author && embed.author.name);
    for (const field of embed.fields || []) chunks.push(field.name, field.value);
  }
  const logins = parseLoginsFromText(chunks.filter(Boolean).join("\n"));
  let any = false;
  for (const login of logins) {
    if (await creditLogin(message.guild, login, "webhook", true)) any = true;
  }
  return any;
}

async function handleInteraction(interaction) {
  if (!interaction.isChatInputCommand() || interaction.commandName !== "github") return false;
  const sub = interaction.options.getSubcommand();

  if (sub === "link") {
    const login = normalizeLogin(interaction.options.getString("username", true));
    if (!login) {
      await interaction.reply({ content: "That is not a GitHub username.", flags: MessageFlags.Ephemeral });
      return true;
    }
    const exists = await githubUserExists(login);
    if (!exists) {
      await interaction.reply({ content: `No GitHub user named \`${login}\`.`, flags: MessageFlags.Ephemeral });
      return true;
    }
    setLink(interaction.guild.id, interaction.user.id, login);
    let extra = "Linked. The **Contributor** role is granted when a commit or pull request from that account shows up.";
    try {
      const logins = await fetchContributorLogins();
      if (logins.has(login.toLowerCase())) {
        const member = await interaction.guild.members.fetch(interaction.user.id);
        const added = await grantContributor(member, `Linked GitHub ${login} with existing contributions`);
        extra = added
          ? `Linked **${login}**. You already have commits or PRs on Lodestar, so you got **Contributor**.`
          : `Linked **${login}**. You already have **Contributor**.`;
      }
    } catch {
      // keep the pending message
    }
    await interaction.reply({ content: extra, flags: MessageFlags.Ephemeral });
    return true;
  }

  if (sub === "unlink") {
    clearLink(interaction.guild.id, interaction.user.id);
    await interaction.reply({ content: "Unlinked your GitHub username.", flags: MessageFlags.Ephemeral });
    return true;
  }

  if (!isStaff(interaction.member)) {
    await interaction.reply({ content: "Staff only.", flags: MessageFlags.Ephemeral });
    return true;
  }

  if (sub === "sync") {
    await interaction.deferReply({ flags: MessageFlags.Ephemeral });
    const report = [];
    const { credited, logins } = await syncGuild(interaction.guild, report);
    await interaction.editReply({
      content: report.join("\n") || `Checked ${logins.size} GitHub logins, granted Contributor to ${credited}.`,
    });
    return true;
  }

  if (sub === "credit") {
    const user = interaction.options.getUser("user", true);
    const member = await interaction.guild.members.fetch(user.id).catch(() => null);
    if (!member) {
      await interaction.reply({ content: "That user is not in the server.", flags: MessageFlags.Ephemeral });
      return true;
    }
    const raw = interaction.options.getString("username");
    if (raw) {
      const login = normalizeLogin(raw);
      if (!login) {
        await interaction.reply({ content: "That is not a GitHub username.", flags: MessageFlags.Ephemeral });
        return true;
      }
      setLink(interaction.guild.id, member.id, login);
    }
    const added = await grantContributor(member, `Contributor credited by ${interaction.user.tag}`);
    if (added) await announceCredit(interaction.guild, member, raw || loginFor(interaction.guild.id, member.id), "staff");
    await interaction.reply({
      content: added ? `Gave **Contributor** to ${member}.` : `${member} already has Contributor.`,
      flags: MessageFlags.Ephemeral,
    });
    return true;
  }

  return true;
}

module.exports = {
  commands,
  handleInteraction,
  panel,
  syncGuild,
  maybeCreditFromMessage,
  normalizeLogin,
  parseLoginsFromText,
  fetchContributorLogins,
  setLink,
  loginFor,
};
