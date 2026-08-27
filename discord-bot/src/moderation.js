"use strict";

const {
  SlashCommandBuilder,
  UserContextMenuCommandBuilder,
  MessageContextMenuCommandBuilder,
  EmbedBuilder,
  PermissionFlagsBits,
  MessageFlags,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
  ActionRowBuilder,
} = require("discord.js");
const config = require("./config");
const state = require("./state");
const { isStaff } = require("./staff");

const INVITE_RE = /(?:https?:\/\/)?(?:www\.)?(?:discord\.gg|discord\.com\/invite|discordapp\.com\/invite)\/[a-z0-9-]+/i;
const MAX_TIMEOUT_MS = 28 * 24 * 60 * 60 * 1000;
const SPAM_WINDOW_MS = 7000;
const SPAM_COUNT = 6;
const REPEAT_COUNT = 4;

const recent = new Map();

function parseDuration(input, fallbackMs) {
  if (input == null || String(input).trim() === "") return fallbackMs;
  const raw = String(input).trim().toLowerCase();
  const m = /^(\d+)\s*(s|sec|secs|seconds|m|min|mins|minutes|h|hr|hrs|hours|d|day|days)?$/.exec(raw);
  if (!m) return null;
  const n = Number(m[1]);
  const unit = m[2] || "m";
  const ms =
    unit.startsWith("s") ? n * 1000 :
    unit.startsWith("m") ? n * 60 * 1000 :
    unit.startsWith("h") ? n * 60 * 60 * 1000 :
    n * 24 * 60 * 60 * 1000;
  if (ms < 1000 || ms > MAX_TIMEOUT_MS) return null;
  return ms;
}

function formatDuration(ms) {
  if (ms < 60 * 1000) return `${Math.round(ms / 1000)}s`;
  if (ms < 60 * 60 * 1000) return `${Math.round(ms / 60000)}m`;
  if (ms < 24 * 60 * 60 * 1000) return `${Math.round(ms / 3600000)}h`;
  return `${Math.round(ms / 86400000)}d`;
}

function offenseFromMessage(content, mentionUserCount, mentionedEveryone) {
  if (mentionedEveryone || mentionUserCount >= 5) return "mass mentions";
  if (INVITE_RE.test(content || "")) return "invite spam";
  return null;
}

function spamOffense(userId, content, now) {
  const text = String(content || "").trim();
  if (text.length < 2) return null;
  let bucket = recent.get(userId);
  if (!bucket) {
    bucket = { times: [], last: "", repeats: 0 };
    recent.set(userId, bucket);
  }
  bucket.times = bucket.times.filter((t) => now - t < SPAM_WINDOW_MS);
  bucket.times.push(now);
  if (text.toLowerCase() === bucket.last) bucket.repeats += 1;
  else {
    bucket.last = text.toLowerCase();
    bucket.repeats = 1;
  }
  if (bucket.times.length >= SPAM_COUNT) return "message spam";
  if (bucket.repeats >= REPEAT_COUNT) return "repeated messages";
  return null;
}

function resetSpam(userId) {
  recent.delete(userId);
}

function commands() {
  const user = (opt) => opt.setName("user").setDescription("Member").setRequired(true);
  const reason = (opt) => opt.setName("reason").setDescription("Why").setRequired(true);
  return [
    new SlashCommandBuilder()
      .setName("mod")
      .setDescription("Warn, timeout, kick, ban, or purge. Developer and Moderator.")
      .setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers)
      .setDMPermission(false)
      .addSubcommand((s) => s.setName("warn").setDescription("Warn a member").addUserOption(user).addStringOption(reason))
      .addSubcommand((s) =>
        s
          .setName("timeout")
          .setDescription("Timeout a member")
          .addUserOption(user)
          .addStringOption((opt) => opt.setName("duration").setDescription("e.g. 10m, 1h, 1d").setRequired(true))
          .addStringOption(reason)
      )
      .addSubcommand((s) => s.setName("untimeout").setDescription("Clear a timeout").addUserOption(user))
      .addSubcommand((s) => s.setName("kick").setDescription("Kick a member").addUserOption(user).addStringOption(reason))
      .addSubcommand((s) => s.setName("ban").setDescription("Ban a member").addUserOption(user).addStringOption(reason))
      .addSubcommand((s) =>
        s.setName("unban").setDescription("Unban a user ID").addStringOption((opt) =>
          opt.setName("user").setDescription("User ID").setRequired(true)
        )
      )
      .addSubcommand((s) =>
        s
          .setName("purge")
          .setDescription("Delete recent messages in this channel")
          .addIntegerOption((opt) => opt.setName("count").setDescription("1–100").setRequired(true).setMinValue(1).setMaxValue(100))
          .addUserOption((opt) => opt.setName("user").setDescription("Only this member").setRequired(false))
      )
      .addSubcommand((s) => s.setName("warnings").setDescription("Show warns for a member").addUserOption(user)),
    new UserContextMenuCommandBuilder().setName("Timeout 10m").setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers),
    new UserContextMenuCommandBuilder().setName("Warn").setDefaultMemberPermissions(PermissionFlagsBits.ModerateMembers),
    new MessageContextMenuCommandBuilder().setName("Delete and warn").setDefaultMemberPermissions(PermissionFlagsBits.ManageMessages),
  ].map((c) => c.toJSON());
}

function warningsOf(guildId, userId) {
  const list = state.guildState(guildId).g.warnings || {};
  return list[userId] || [];
}

function addWarning(guildId, userId, entry) {
  return state.patch(guildId, (g) => {
    if (!g.warnings) g.warnings = {};
    if (!g.warnings[userId]) g.warnings[userId] = [];
    g.warnings[userId].push(entry);
  }).warnings[userId];
}

function modLog(guild) {
  const id = state.guildState(guild.id).g.channels["mod-log"];
  return (id && guild.channels.cache.get(id)) || guild.channels.cache.find((c) => c.name === "mod-log") || null;
}

async function logAction(guild, embed) {
  const log = modLog(guild);
  if (!log) return;
  try {
    await log.send({ embeds: [embed] });
  } catch {
    // missing send permission
  }
}

function actionEmbed(title, fields, color) {
  const embed = new EmbedBuilder().setColor(color || 0xed4245).setTitle(title).setTimestamp(new Date());
  for (const [name, value, inline] of fields) embed.addFields({ name, value: String(value).slice(0, 1024), inline: Boolean(inline) });
  return embed;
}

async function notify(user, text) {
  try {
    await user.send(text);
  } catch {
    // DMs closed
  }
}

function canModerate(actor, target) {
  if (!target) return "That member is not in the server.";
  if (target.id === actor.id) return "You cannot moderate yourself.";
  if (target.user && target.user.bot) return "Leave bots alone. Kick them from Server Settings if you mean it.";
  if (config.developerUserIds.includes(target.id)) return "That account is a Lodestar developer.";
  if (target.guild && target.id === target.guild.ownerId) return "The server owner cannot be moderated.";
  const me = actor.guild.members.me;
  if (me && target.roles && target.roles.highest.position >= me.roles.highest.position) {
    return "Drag the Lodestar Support role above theirs, then try again.";
  }
  return null;
}

function requireStaff(interaction) {
  if (isStaff(interaction.member)) return null;
  return "Developer or Moderator only.";
}

async function warnMember(guild, actor, target, reason, auto) {
  const list = addWarning(guild.id, target.id, {
    at: new Date().toISOString(),
    reason,
    by: actor.id,
    auto: Boolean(auto),
  });
  const embed = actionEmbed(auto ? "Auto-warn" : "Warn", [
    ["Member", `${target} (\`${target.id}\`)`, true],
    ["By", `${actor}`, true],
    ["Reason", reason],
    ["Warnings", String(list.length), true],
  ], 0xfee75c);
  await logAction(guild, embed);
  await notify(target.user || target, `You were warned in **${guild.name}**: ${reason}`);
  return list.length;
}

async function timeoutMember(guild, actor, target, ms, reason) {
  await target.timeout(ms, reason);
  const embed = actionEmbed("Timeout", [
    ["Member", `${target} (\`${target.id}\`)`, true],
    ["By", `${actor}`, true],
    ["Duration", formatDuration(ms), true],
    ["Reason", reason],
  ]);
  await logAction(guild, embed);
  await notify(target.user, `You were timed out in **${guild.name}** for ${formatDuration(ms)}: ${reason}`);
}

async function handleModSlash(interaction) {
  const blocked = requireStaff(interaction);
  if (blocked) {
    await interaction.reply({ content: blocked, flags: MessageFlags.Ephemeral });
    return;
  }
  const sub = interaction.options.getSubcommand();
  if (sub === "warnings") {
    const user = interaction.options.getUser("user", true);
    const list = warningsOf(interaction.guild.id, user.id);
    if (!list.length) {
      await interaction.reply({ content: `${user} has no warnings.`, flags: MessageFlags.Ephemeral });
      return;
    }
    const body = list
      .slice(-10)
      .map((w, i) => `${i + 1}. ${w.at.slice(0, 10)} — ${w.reason} (${w.auto ? "auto" : `<@${w.by}>`})`)
      .join("\n");
    await interaction.reply({
      embeds: [actionEmbed(`Warnings for ${user.tag}`, [["Count", String(list.length), true], ["Latest", body]], config.color)],
      flags: MessageFlags.Ephemeral,
    });
    return;
  }

  if (sub === "unban") {
    const id = interaction.options.getString("user", true).trim();
    await interaction.guild.bans.remove(id, `Unban by ${interaction.user.tag}`);
    await logAction(interaction.guild, actionEmbed("Unban", [["User", `\`${id}\``, true], ["By", `${interaction.user}`, true]], 0x57f287));
    await interaction.reply({ content: `Unbanned \`${id}\`.`, flags: MessageFlags.Ephemeral });
    return;
  }

  if (sub === "purge") {
    const count = interaction.options.getInteger("count", true);
    const only = interaction.options.getUser("user");
    if (!interaction.channel || !interaction.channel.bulkDelete) {
      await interaction.reply({ content: "Cannot purge here.", flags: MessageFlags.Ephemeral });
      return;
    }
    await interaction.deferReply({ flags: MessageFlags.Ephemeral });
    let deleted = 0;
    if (!only) {
      const result = await interaction.channel.bulkDelete(count, true);
      deleted = result.size;
    } else {
      const fetched = await interaction.channel.messages.fetch({ limit: 100 });
      const mine = fetched.filter((m) => m.author.id === only.id).first(count);
      if (mine.length) {
        const result = await interaction.channel.bulkDelete(mine, true);
        deleted = result.size;
      }
    }
    await logAction(
      interaction.guild,
      actionEmbed("Purge", [
        ["Channel", `${interaction.channel}`, true],
        ["By", `${interaction.user}`, true],
        ["Deleted", String(deleted), true],
        ["Filter", only ? `${only}` : "anyone", true],
      ], 0xfee75c)
    );
    await interaction.editReply(`Deleted ${deleted} message${deleted === 1 ? "" : "s"}.`);
    return;
  }

  const user = interaction.options.getUser("user", true);
  const member = await interaction.guild.members.fetch(user.id).catch(() => null);
  const reason = interaction.options.getString("reason") || "No reason given";

  if (sub === "untimeout") {
    if (!member) {
      await interaction.reply({ content: "They are not in the server.", flags: MessageFlags.Ephemeral });
      return;
    }
    await member.timeout(null, `Cleared by ${interaction.user.tag}`);
    await logAction(interaction.guild, actionEmbed("Timeout cleared", [["Member", `${member}`, true], ["By", `${interaction.user}`, true]], 0x57f287));
    await interaction.reply({ content: `Cleared timeout for ${member}.`, flags: MessageFlags.Ephemeral });
    return;
  }

  const problem = canModerate(interaction.member, member);
  if (problem) {
    await interaction.reply({ content: problem, flags: MessageFlags.Ephemeral });
    return;
  }

  if (sub === "warn") {
    const n = await warnMember(interaction.guild, interaction.user, member, reason, false);
    await interaction.reply({ content: `Warned ${member} (${n} warning${n === 1 ? "" : "s"}).`, flags: MessageFlags.Ephemeral });
    return;
  }
  if (sub === "timeout") {
    const ms = parseDuration(interaction.options.getString("duration", true), null);
    if (!ms) {
      await interaction.reply({ content: "Duration looks like `10m`, `1h`, or `1d` (max 28 days).", flags: MessageFlags.Ephemeral });
      return;
    }
    await timeoutMember(interaction.guild, interaction.user, member, ms, reason);
    await interaction.reply({ content: `Timed out ${member} for ${formatDuration(ms)}.`, flags: MessageFlags.Ephemeral });
    return;
  }
  if (sub === "kick") {
    await member.kick(reason);
    await logAction(interaction.guild, actionEmbed("Kick", [["Member", `${user} (\`${user.id}\`)`, true], ["By", `${interaction.user}`, true], ["Reason", reason]]));
    await interaction.reply({ content: `Kicked ${user.tag}.`, flags: MessageFlags.Ephemeral });
    return;
  }
  if (sub === "ban") {
    await interaction.guild.members.ban(user, { reason });
    await logAction(interaction.guild, actionEmbed("Ban", [["Member", `${user} (\`${user.id}\`)`, true], ["By", `${interaction.user}`, true], ["Reason", reason]]));
    await interaction.reply({ content: `Banned ${user.tag}.`, flags: MessageFlags.Ephemeral });
  }
}

function warnModal(userId) {
  return new ModalBuilder()
    .setCustomId(`mod_warn_modal:${userId}`)
    .setTitle("Warn member")
    .addComponents(
      new ActionRowBuilder().addComponents(
        new TextInputBuilder().setCustomId("reason").setLabel("Reason").setStyle(TextInputStyle.Paragraph).setRequired(true).setMinLength(3).setMaxLength(400)
      )
    );
}

async function handleContext(interaction) {
  const blocked = requireStaff(interaction);
  if (blocked) {
    await interaction.reply({ content: blocked, flags: MessageFlags.Ephemeral });
    return;
  }
  if (interaction.commandName === "Warn") {
    await interaction.showModal(warnModal(interaction.targetUser.id));
    return;
  }
  if (interaction.commandName === "Timeout 10m") {
    const member = await interaction.guild.members.fetch(interaction.targetUser.id).catch(() => null);
    const problem = canModerate(interaction.member, member);
    if (problem) {
      await interaction.reply({ content: problem, flags: MessageFlags.Ephemeral });
      return;
    }
    await timeoutMember(interaction.guild, interaction.user, member, 10 * 60 * 1000, "Timeout 10m (context menu)");
    await interaction.reply({ content: `Timed out ${member} for 10m.`, flags: MessageFlags.Ephemeral });
    return;
  }
  if (interaction.commandName === "Delete and warn") {
    const msg = interaction.targetMessage;
    const member = await interaction.guild.members.fetch(msg.author.id).catch(() => null);
    const problem = canModerate(interaction.member, member);
    if (problem) {
      await interaction.reply({ content: problem, flags: MessageFlags.Ephemeral });
      return;
    }
    await msg.delete().catch(() => {});
    const n = await warnMember(interaction.guild, interaction.user, member, `Message removed: ${(msg.content || "(embed)").slice(0, 180)}`, false);
    await interaction.reply({ content: `Deleted the message and warned ${member} (${n}).`, flags: MessageFlags.Ephemeral });
  }
}

async function handleWarnModal(interaction) {
  const blocked = requireStaff(interaction);
  if (blocked) {
    await interaction.reply({ content: blocked, flags: MessageFlags.Ephemeral });
    return;
  }
  const userId = interaction.customId.split(":")[1];
  const member = await interaction.guild.members.fetch(userId).catch(() => null);
  const problem = canModerate(interaction.member, member);
  if (problem) {
    await interaction.reply({ content: problem, flags: MessageFlags.Ephemeral });
    return;
  }
  const reason = interaction.fields.getTextInputValue("reason");
  const n = await warnMember(interaction.guild, interaction.user, member, reason, false);
  await interaction.reply({ content: `Warned ${member} (${n} warning${n === 1 ? "" : "s"}).`, flags: MessageFlags.Ephemeral });
}

function automodStrikeMs(count) {
  if (count >= 3) return 60 * 60 * 1000;
  if (count >= 2) return 10 * 60 * 1000;
  return 0;
}

async function maybeAutomod(message) {
  if (!message.guild || message.author.bot) return false;
  if (isStaff(message.member)) return false;
  const parentName = message.channel.parent && message.channel.parent.name;
  if (parentName === "Staff" || parentName === "Tickets") return false;

  const inviteOrMentions = offenseFromMessage(
    message.content,
    message.mentions.users.size,
    message.mentions.everyone
  );
  const spam = spamOffense(message.author.id, message.content, Date.now());
  const offense = inviteOrMentions || spam;
  if (!offense) return false;

  resetSpam(message.author.id);
  await message.delete().catch(() => {});
  const member = message.member;
  if (!member) return true;
  const n = await warnMember(message.guild, message.client.user, member, `${offense} in ${message.channel}`, true);
  const ms = automodStrikeMs(n);
  if (ms) {
    try {
      await timeoutMember(message.guild, message.client.user, member, ms, `${offense} (strike ${n})`);
    } catch (err) {
      console.error("automod timeout failed:", err.message);
    }
  }
  try {
    await message.channel.send({
      content: `${member}, that breaks the rules (${offense}). Strike ${n}.${ms ? ` Timed out ${formatDuration(ms)}.` : ""}`,
    });
  } catch {
    // ignore
  }
  return true;
}

async function handleInteraction(interaction) {
  if (interaction.isChatInputCommand() && interaction.commandName === "mod") {
    await handleModSlash(interaction);
    return true;
  }
  if (interaction.isUserContextMenuCommand() || interaction.isMessageContextMenuCommand()) {
    if (["Timeout 10m", "Warn", "Delete and warn"].includes(interaction.commandName)) {
      await handleContext(interaction);
      return true;
    }
  }
  if (interaction.isModalSubmit() && interaction.customId.startsWith("mod_warn_modal:")) {
    await handleWarnModal(interaction);
    return true;
  }
  return false;
}

module.exports = {
  commands,
  handleInteraction,
  maybeAutomod,
  parseDuration,
  offenseFromMessage,
  spamOffense,
  resetSpam,
  formatDuration,
};
