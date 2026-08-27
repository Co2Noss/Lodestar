"use strict";

const { EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle, MessageFlags, GuildVerificationLevel } = require("discord.js");
const config = require("./config");
const state = require("./state");
const { isStaff, roleByName } = require("./staff");
const { channelSlug, findBySlug } = require("./names");
const emojis = require("./emojis");

const CHANNEL_NAME = "silence-enforced";

function verifyMinAgeMs() {
  return config.verifyMinAccountAgeMs;
}

function accountAgeMs(user) {
  return Date.now() - user.createdTimestamp;
}

function accountTooNew(user) {
  return accountAgeMs(user) < verifyMinAgeMs();
}

function honeypotKicks(guildId) {
  return state.guildState(guildId).g.honeypotKicks || 0;
}

function bumpKicks(guildId) {
  return state.patch(guildId, (g) => {
    g.honeypotKicks = (g.honeypotKicks || 0) + 1;
  }).honeypotKicks;
}

function honeypotPanel(kicks) {
  const embed = new EmbedBuilder()
    .setColor(0x2b2d31)
    .setTitle("DO NOT SEND MESSAGES IN THIS CHANNEL")
    .setDescription("This channel is used to catch spam bots. Any messages sent here will result in a **softban**.")
    .setFooter({ text: "Lodestar Guide · honeypot" });
  const row = new ActionRowBuilder().addComponents(
    new ButtonBuilder()
      .setCustomId("honeypot_kicks")
      .setLabel(`Kicks: ${kicks}`)
      .setEmoji("🍯")
      .setStyle(ButtonStyle.Secondary)
      .setDisabled(true)
  );
  return { embeds: [embed], components: [row] };
}

function welcomeButtons() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId("verify_agree").setLabel("I have read the rules").setStyle(ButtonStyle.Success)
  );
}

function joinPromptContent(member) {
  return `${member}, read the pinned message, then click **I have read the rules**. Do not type in #silence-enforced.`;
}

function generalWelcomeContent(member, guild) {
  const star = guild ? emojis.mention(guild, "lodestar") : "";
  const questions = guild ? findBySlug(guild, "questions") : null;
  const prefix = star ? `${star}  ` : "";
  const ask = questions ? ` or ask in ${questions}` : "";
  return `${prefix}Welcome ${member}. Chat here${ask}.`;
}

function isJoinPrompt(message, botId) {
  if (!message || !message.content) return false;
  if (botId && message.author && message.author.id !== botId) return false;
  return message.content.includes("I have read the rules") && message.content.includes("read the pinned message");
}

const announced = new Set();

function takeAnnounceSlot(userId) {
  if (announced.has(userId)) return false;
  announced.add(userId);
  setTimeout(() => announced.delete(userId), 60_000).unref?.();
  return true;
}

function rememberJoinPrompt(guildId, userId, messageId) {
  state.patch(guildId, (g) => {
    if (!g.joinPrompts) g.joinPrompts = {};
    g.joinPrompts[userId] = messageId;
  });
}

function forgetJoinPrompt(guildId, userId) {
  state.patch(guildId, (g) => {
    if (!g.joinPrompts) return;
    delete g.joinPrompts[userId];
  });
}

async function clearJoinPrompt(guild, userId) {
  const welcome = findBySlug(guild, "welcome", (c) => c.isTextBased());
  if (!welcome) return 0;
  const pinnedId = state.guildState(guild.id).g.messages && state.guildState(guild.id).g.messages.welcome;
  const stored = state.guildState(guild.id).g.joinPrompts && state.guildState(guild.id).g.joinPrompts[userId];
  const ids = new Set();
  if (stored) ids.add(stored);
  try {
    const msgs = await welcome.messages.fetch({ limit: 100 });
    for (const msg of msgs.values()) {
      if (pinnedId && msg.id === pinnedId) continue;
      if (!isJoinPrompt(msg, guild.client.user.id)) continue;
      if (msg.mentions && msg.mentions.users && msg.mentions.users.has(userId)) ids.add(msg.id);
    }
  } catch {
    // missing history permission
  }
  let n = 0;
  for (const id of ids) {
    try {
      await welcome.messages.delete(id);
      n += 1;
    } catch {
      // already gone
    }
  }
  forgetJoinPrompt(guild.id, userId);
  return n;
}

async function announceInGeneral(member) {
  const channel = findBySlug(member.guild, "general", (c) => c.isTextBased());
  if (!channel) return false;
  await channel.send({
    content: generalWelcomeContent(member, member.guild),
    allowedMentions: { users: [member.id] },
  });
  return true;
}

async function sendJoinPrompt(member) {
  const welcome = findBySlug(member.guild, "welcome", (c) => c.isTextBased());
  if (!welcome) return null;
  const msg = await welcome.send({ content: joinPromptContent(member) });
  rememberJoinPrompt(member.guild.id, member.id, msg.id);
  return msg;
}

async function onBecameMember(member) {
  await clearJoinPrompt(member.guild, member.id);
  if (!takeAnnounceSlot(member.id)) return false;
  try {
    await announceInGeneral(member);
  } catch (err) {
    announced.delete(member.id);
    console.error("general welcome failed:", err.message);
    return false;
  }
  return true;
}

async function sweepVerifiedPrompts(guild) {
  const welcome = findBySlug(guild, "welcome", (c) => c.isTextBased());
  if (!welcome || !guild.client || !guild.client.user) return 0;
  const role = roleByName(guild, "Member");
  const pinnedId = state.guildState(guild.id).g.messages && state.guildState(guild.id).g.messages.welcome;
  let n = 0;
  let msgs;
  try {
    msgs = await welcome.messages.fetch({ limit: 100 });
  } catch {
    return 0;
  }
  for (const msg of msgs.values()) {
    if (pinnedId && msg.id === pinnedId) continue;
    if (!isJoinPrompt(msg, guild.client.user.id)) continue;
    const mentioned = msg.mentions && msg.mentions.users && [...msg.mentions.users.keys()][0];
    if (!mentioned) continue;
    const member = await guild.members.fetch(mentioned).catch(() => null);
    if (!member || !role || !member.roles.cache.has(role.id)) continue;
    await msg.delete().catch(() => {});
    forgetJoinPrompt(guild.id, mentioned);
    n += 1;
    await onBecameMember(member).catch(() => {});
  }
  return n;
}

async function applySecurity(guild, report) {
  try {
    if (guild.verificationLevel < GuildVerificationLevel.High) {
      await guild.setVerificationLevel(GuildVerificationLevel.High, "Stop instant join-spam");
      report.push("set verification level to High (10 minutes in the server)");
    }
  } catch (err) {
    report.push(`could not set verification level: ${err.message}`);
  }
}

async function handleVerify(interaction) {
  const member = interaction.member;
  const role = roleByName(interaction.guild, "Member");
  if (!role) {
    await interaction.reply({ content: "Verification is not set up yet. Run `/setup`.", flags: MessageFlags.Ephemeral });
    return;
  }
  if (member.roles.cache.has(role.id)) {
    await clearJoinPrompt(interaction.guild, member.id);
    await interaction.reply({ content: "You're already in. The rest of the server is unlocked.", flags: MessageFlags.Ephemeral });
    return;
  }
  if (accountTooNew(interaction.user) && !isStaff(member)) {
    const hours = Math.ceil((verifyMinAgeMs() - accountAgeMs(interaction.user)) / 3600000);
    await interaction.reply({
      content: `Your Discord account is too new. Come back in about ${hours} hour${hours === 1 ? "" : "s"}. This stops bot farms.`,
      flags: MessageFlags.Ephemeral,
    });
    return;
  }
  await member.roles.add(role, "Passed rules verification");
  await onBecameMember(member);
  await interaction.reply({
    content: "You're in. #faq, #questions, and #get-help are unlocked. Do not type in #silence-enforced.",
    flags: MessageFlags.Ephemeral,
  });
}

async function refreshHoneypot(guild) {
  const channel = findBySlug(guild, CHANNEL_NAME, (c) => c.isTextBased());
  if (!channel || !channel.isTextBased()) return;
  const id = state.guildState(guild.id).g.messages.honeypot;
  if (!id) return;
  try {
    const msg = await channel.messages.fetch(id);
    await msg.edit(honeypotPanel(honeypotKicks(guild.id)));
  } catch {
    // panel missing; /setup will recreate it
  }
}

async function logHoneypot(guild, user, kicks) {
  const id = state.guildState(guild.id).g.channels["mod-log"];
  const log = (id && guild.channels.cache.get(id)) || findBySlug(guild, "mod-log", (c) => c.isTextBased());
  if (!log) return;
  const embed = new EmbedBuilder()
    .setColor(0xed4245)
    .setTitle("Honeypot softban")
    .addFields(
      { name: "User", value: `${user} (\`${user.id}\`)`, inline: true },
      { name: "Kicks", value: String(kicks), inline: true }
    )
    .setTimestamp(new Date());
  await log.send({ embeds: [embed] }).catch(() => {});
}

async function maybeHoneypot(message) {
  if (!message.guild || message.author.bot) return false;
  if (!message.channel || channelSlug(message.channel.name) !== CHANNEL_NAME) return false;
  if (isStaff(message.member)) {
    await message.delete().catch(() => {});
    return true;
  }
  const user = message.author;
  const member = message.member;
  await message.delete().catch(() => {});
  let kicks = honeypotKicks(message.guild.id);
  try {
    if (member && member.bannable) {
      await member.ban({ deleteMessageSeconds: 86400, reason: "Honeypot #silence-enforced" });
      await message.guild.members.unban(user.id, "Honeypot softban");
      kicks = bumpKicks(message.guild.id);
      await refreshHoneypot(message.guild);
      await logHoneypot(message.guild, user, kicks);
    }
  } catch (err) {
    console.error("honeypot softban failed:", err.message);
  }
  return true;
}

async function handleInteraction(interaction) {
  if (interaction.isButton() && interaction.customId === "verify_agree") {
    await handleVerify(interaction);
    return true;
  }
  if (interaction.isButton() && interaction.customId === "honeypot_kicks") {
    await interaction.deferUpdate();
    return true;
  }
  return false;
}

module.exports = {
  CHANNEL_NAME,
  honeypotPanel,
  welcomeButtons,
  applySecurity,
  maybeHoneypot,
  handleInteraction,
  accountTooNew,
  accountAgeMs,
  joinPromptContent,
  generalWelcomeContent,
  isJoinPrompt,
  sendJoinPrompt,
  onBecameMember,
  sweepVerifiedPrompts,
};
