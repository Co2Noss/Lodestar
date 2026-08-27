"use strict";

const {
  ChannelType,
  PermissionFlagsBits,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  ModalBuilder,
  TextInputBuilder,
  TextInputStyle,
} = require("discord.js");
const config = require("./config");
const state = require("./state");

const { isStaff, staffRoles } = require("./staff");

function supportRole(guild) {
  const id = state.guildState(guild.id).g.roles.support;
  return (id && guild.roles.cache.get(id)) || guild.roles.cache.find((r) => r.name === "Support") || null;
}

function ticketsCategory(guild) {
  const id = state.guildState(guild.id).g.categories.tickets;
  return (id && guild.channels.cache.get(id)) || guild.channels.cache.find((c) => c.name === "Tickets" && c.type === ChannelType.GuildCategory) || null;
}

function logsChannel(guild) {
  const id = state.guildState(guild.id).g.channels["ticket-logs"];
  return (id && guild.channels.cache.get(id)) || guild.channels.cache.find((c) => c.name === "ticket-logs") || null;
}

function openTicketFor(guild, userId) {
  const parent = ticketsCategory(guild);
  if (!parent) return null;
  return parent.children.cache.find((ch) => {
    const topic = ch.topic || "";
    return topic.includes(`user:${userId}`) && topic.includes("status:open");
  }) || null;
}

function ticketModal() {
  const modal = new ModalBuilder().setCustomId("ticket_modal").setTitle("Open a Lodestar ticket");
  const fields = [
    ["summary", "Short summary", "Great Vault missing from Today", TextInputStyle.Short, 5, 100],
    ["details", "What happened", "What you expected versus what happened. Paste errors if you have them.", TextInputStyle.Paragraph, 10, 1000],
    ["spec", "Class / spec", "e.g. Brewmaster Monk", TextInputStyle.Short, 2, 80],
    ["theme", "Theme", "Blizzard, ElvUI, GW2, RealUI, Ellesmere, Minimal", TextInputStyle.Short, 2, 40],
    ["version", "Lodestar version", "e.g. 1.5.31 — from the CurseForge client or /ls", TextInputStyle.Short, 1, 20],
  ];
  for (const [id, label, placeholder, style, min, max] of fields) {
    modal.addComponents(
      new ActionRowBuilder().addComponents(
        new TextInputBuilder()
          .setCustomId(id)
          .setLabel(label)
          .setPlaceholder(placeholder)
          .setStyle(style)
          .setRequired(true)
          .setMinLength(min)
          .setMaxLength(max)
      )
    );
  }
  return modal;
}

function ticketButtons() {
  return new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId("ticket_close").setLabel("Close ticket").setStyle(ButtonStyle.Danger)
  );
}

async function createTicket(interaction) {
  const guild = interaction.guild;
  const user = interaction.user;
  const existing = openTicketFor(guild, user.id);
  if (existing) {
    return interaction.reply({ content: `You already have an open ticket: ${existing}`, ephemeral: true });
  }

  const parent = ticketsCategory(guild);
  const staff = staffRoles(guild);
  if (!parent || !staff.length) {
    return interaction.reply({
      content: "Support is not set up yet. An admin needs to run `/setup` first.",
      ephemeral: true,
    });
  }

  const summary = interaction.fields.getTextInputValue("summary");
  const details = interaction.fields.getTextInputValue("details");
  const spec = interaction.fields.getTextInputValue("spec");
  const theme = interaction.fields.getTextInputValue("theme");
  const version = interaction.fields.getTextInputValue("version");

  const seq = state.patch(guild.id, (g) => {
    g.ticketSeq = (g.ticketSeq || 0) + 1;
  }).ticketSeq;
  const name = `ticket-${String(seq).padStart(3, "0")}`;

  const channel = await guild.channels.create({
    name,
    type: ChannelType.GuildText,
    parent: parent.id,
    topic: `user:${user.id} | status:open | ${summary}`.slice(0, 1024),
    permissionOverwrites: [
      { id: guild.roles.everyone.id, deny: [P.ViewChannel] },
      {
        id: user.id,
        allow: [P.ViewChannel, P.SendMessages, P.ReadMessageHistory, P.AttachFiles, P.EmbedLinks, P.AddReactions],
      },
      ...staff.map((role) => ({
        id: role.id,
        allow: [P.ViewChannel, P.SendMessages, P.ReadMessageHistory, P.AttachFiles, P.EmbedLinks, P.ManageMessages, P.ManageThreads],
      })),
    ],
    reason: `Ticket for ${user.tag}`,
  });

  const embed = new EmbedBuilder()
    .setColor(config.color)
    .setTitle(summary)
    .setDescription(details)
    .addFields(
      { name: "Player", value: `${user}`, inline: true },
      { name: "Class / spec", value: spec, inline: true },
      { name: "Theme", value: theme, inline: true },
      { name: "Version", value: version, inline: true }
    )
    .setFooter({ text: "Staff: close when this is done. Include /ls debug if an error is involved." });

  const support = supportRole(guild);
  await channel.send({
    content: `${user}${support ? ` ${support}` : ""}`,
    embeds: [embed],
    components: [ticketButtons()],
  });

  await interaction.reply({ content: `Ticket opened: ${channel}`, ephemeral: true });
  return channel;
}

function canClose(interaction, channel) {
  const topic = channel.topic || "";
  const opener = (topic.match(/user:(\d+)/) || [])[1];
  if (opener && opener === interaction.user.id) return true;
  if (interaction.memberPermissions?.has(P.ManageChannels)) return true;
  return isStaff(interaction.member);
}

async function transcript(channel) {
  const messages = await channel.messages.fetch({ limit: 100 });
  const lines = [...messages.values()]
    .sort((a, b) => a.createdTimestamp - b.createdTimestamp)
    .map((m) => {
      const time = new Date(m.createdTimestamp).toISOString();
      const text = m.cleanContent || (m.embeds[0] && (m.embeds[0].title || m.embeds[0].description)) || "";
      return `[${time}] ${m.author.tag}: ${text}`;
    });
  return Buffer.from(lines.join("\n") || "(empty)", "utf8");
}

async function closeTicket(interaction) {
  const channel = interaction.channel;
  if (!channel || !ticketsCategory(interaction.guild) || channel.parentId !== ticketsCategory(interaction.guild).id) {
    return interaction.reply({ content: "Use this inside a ticket channel.", ephemeral: true });
  }
  if (!canClose(interaction, channel)) {
    return interaction.reply({ content: "Only the opener or staff can close this.", ephemeral: true });
  }

  await interaction.deferReply();
  const opener = ((channel.topic || "").match(/user:(\d+)/) || [])[1];
  const file = await transcript(channel);
  const logs = logsChannel(interaction.guild);
  if (logs) {
    await logs.send({
      content: `Closed ${channel.name} by ${interaction.user}${opener ? ` (opened by <@${opener}>)` : ""}`,
      files: [{ attachment: file, name: `${channel.name}.txt` }],
    });
  }
  await channel.edit({ topic: (channel.topic || "").replace("status:open", "status:closed") }).catch(() => {});
  await interaction.editReply("Closing this ticket in 5 seconds.");
  setTimeout(() => {
    channel.delete("Ticket closed").catch(() => {});
  }, 5000);
}

module.exports = {
  ticketModal,
  createTicket,
  closeTicket,
  openTicketFor,
};
