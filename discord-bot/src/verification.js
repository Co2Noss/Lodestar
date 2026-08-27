"use strict";

const { EmbedBuilder, ActionRowBuilder, ButtonBuilder, ButtonStyle, MessageFlags, GuildVerificationLevel } = require("discord.js");
const config = require("./config");
const state = require("./state");
const { isStaff, roleByName } = require("./staff");
const { channelSlug, findBySlug } = require("./names");

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
};
