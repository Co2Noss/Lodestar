"use strict";

const { SlashCommandBuilder, EmbedBuilder, PermissionFlagsBits, MessageFlags } = require("discord.js");
const { isStaff, roleByName } = require("./staff");
const { findBySlug } = require("./names");
const emojis = require("./emojis");

function commands() {
  return [
    new SlashCommandBuilder()
      .setName("alpha")
      .setDescription("Grant or revoke Alpha Tester. Staff only.")
      .setDefaultMemberPermissions(PermissionFlagsBits.ManageRoles)
      .setDMPermission(false)
      .addSubcommand((s) =>
        s
          .setName("grant")
          .setDescription("Give Alpha Tester and unlock the alpha channels")
          .addUserOption((opt) => opt.setName("user").setDescription("Member").setRequired(true))
      )
      .addSubcommand((s) =>
        s
          .setName("revoke")
          .setDescription("Remove Alpha Tester")
          .addUserOption((opt) => opt.setName("user").setDescription("Member").setRequired(true))
      ),
  ].map((c) => c.toJSON());
}

function panel(guild) {
  const star = emojis.mention(guild, "flask");
  const embed = new EmbedBuilder()
    .setColor(0x59d8c9)
    .setTitle(star ? `${star}  Alpha` : "Alpha")
    .setDescription(
      [
        "Private space for people testing unreleased Lodestar builds.",
        "",
        "Staff grants **Alpha Tester** with `/alpha grant`. That is the only way in — these channels stay hidden from everyone else.",
        "",
        "**#🧪alpha-news** — what to install and what to try",
        "**#🗣️alpha-chat** — talk while you test",
        "**#📋alpha-feedback** — bugs, weird UI, and “this used to work”",
        "",
        "Include class/spec, theme, and expected versus actual. `/ls debug` if you are not sure which addon errored.",
      ].join("\n")
    );
  return { embeds: [embed] };
}

function modLog(guild) {
  return findBySlug(guild, "mod-log", (c) => c.isTextBased());
}

async function logGrant(guild, actor, target, added) {
  const log = modLog(guild);
  if (!log) return;
  const embed = new EmbedBuilder()
    .setColor(added ? 0x59d8c9 : 0x99aab5)
    .setTitle(added ? "Alpha Tester granted" : "Alpha Tester revoked")
    .addFields(
      { name: "Member", value: `${target} (\`${target.id}\`)`, inline: true },
      { name: "By", value: `${actor}`, inline: true }
    )
    .setTimestamp(new Date());
  await log.send({ embeds: [embed] }).catch(() => {});
}

async function handleInteraction(interaction) {
  if (!interaction.isChatInputCommand() || interaction.commandName !== "alpha") return false;
  if (!isStaff(interaction.member)) {
    await interaction.reply({ content: "Staff only.", flags: MessageFlags.Ephemeral });
    return true;
  }
  const targetUser = interaction.options.getUser("user", true);
  const member = await interaction.guild.members.fetch(targetUser.id).catch(() => null);
  if (!member) {
    await interaction.reply({ content: "That user is not in the server.", flags: MessageFlags.Ephemeral });
    return true;
  }
  const alpha = roleByName(interaction.guild, "Alpha Tester");
  if (!alpha) {
    await interaction.reply({ content: "Run `/setup` first so the Alpha Tester role exists.", flags: MessageFlags.Ephemeral });
    return true;
  }
  const add = interaction.options.getSubcommand() === "grant";
  if (add) {
    const memberRole = roleByName(interaction.guild, "Member");
    const extra = [];
    if (memberRole && !member.roles.cache.has(memberRole.id)) extra.push(memberRole);
    if (!member.roles.cache.has(alpha.id)) extra.push(alpha);
    if (!extra.length) {
      await interaction.reply({ content: `${member} already has Alpha Tester.`, flags: MessageFlags.Ephemeral });
      return true;
    }
    await member.roles.add(extra, `Alpha Tester granted by ${interaction.user.tag}`);
    await logGrant(interaction.guild, interaction.user, member, true);
    const news = findBySlug(interaction.guild, "alpha-news");
    await interaction.reply({
      content: `${member} is an **Alpha Tester**.${news ? ` They can see ${news}.` : ""}`,
      flags: MessageFlags.Ephemeral,
    });
    await member.send(`You were given **Alpha Tester** on **${interaction.guild.name}**. The Alpha category is unlocked.`).catch(() => {});
    return true;
  }
  if (!member.roles.cache.has(alpha.id)) {
    await interaction.reply({ content: `${member} is not an Alpha Tester.`, flags: MessageFlags.Ephemeral });
    return true;
  }
  await member.roles.remove(alpha, `Alpha Tester revoked by ${interaction.user.tag}`);
  await logGrant(interaction.guild, interaction.user, member, false);
  await interaction.reply({ content: `Removed Alpha Tester from ${member}.`, flags: MessageFlags.Ephemeral });
  return true;
}

module.exports = { commands, handleInteraction, panel };
