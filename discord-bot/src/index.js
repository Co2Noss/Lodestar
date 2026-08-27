"use strict";

const {
  Client,
  GatewayIntentBits,
  Partials,
  SlashCommandBuilder,
  EmbedBuilder,
  PermissionFlagsBits,
  ActivityType,
  MessageFlags,
} = require("discord.js");
const config = require("./config");
const { FAQS, findFaq, faqChoices, faqEmbed, linksEmbed } = require("./faqs");
const { applySetup } = require("./setup");
const tickets = require("./tickets");
const { maybeAssist } = require("./assist");

if (!config.token) {
  console.error("Missing DISCORD_TOKEN. Copy discord-bot/.env.example to discord-bot/.env and paste the bot token.");
  process.exit(1);
}

const commands = [
  new SlashCommandBuilder()
    .setName("setup")
    .setDescription("Create Lodestar support roles, channels, FAQ, and the ticket panel.")
    .setDefaultMemberPermissions(PermissionFlagsBits.Administrator)
    .setDMPermission(false),
  new SlashCommandBuilder()
    .setName("faq")
    .setDescription("Look up a Lodestar answer.")
    .addStringOption((opt) =>
      opt.setName("topic").setDescription("Topic or search words").setRequired(true).setAutocomplete(true)
    )
    .setDMPermission(false),
  new SlashCommandBuilder()
    .setName("ticket")
    .setDescription("Open a private support ticket.")
    .setDMPermission(false),
  new SlashCommandBuilder()
    .setName("close")
    .setDescription("Close the current support ticket.")
    .setDMPermission(false),
  new SlashCommandBuilder()
    .setName("help")
    .setDescription("How to get Lodestar support on this server.")
    .setDMPermission(false),
].map((c) => c.toJSON());

function makeClient(privileged) {
  const intents = [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages];
  if (privileged) {
    intents.push(GatewayIntentBits.GuildMembers, GatewayIntentBits.MessageContent);
  }
  return new Client({ intents, partials: [Partials.Channel] });
}

function helpEmbed() {
  return new EmbedBuilder()
    .setColor(config.color)
    .setTitle("Lodestar support")
    .setDescription(
      [
        "**Find what matters. Ignore the rest.**",
        "",
        "`/faq` — answers for install, goals, gold, rares, vault, debug, and more",
        "`/ticket` — private ticket with Support (or the button in #get-help)",
        "`/close` — close your ticket",
        "`/setup` — admins: rebuild the server layout",
        "",
        "Include class/spec, theme, and expected versus actual. `/ls debug` isolates addon errors.",
      ].join("\n")
    )
    .addFields(
      { name: "Download", value: `[CurseForge](${config.links.curseforge})` },
      { name: "Bugs", value: `[GitHub issues](${config.links.issues})` }
    );
}

async function assignOwnerSupport(guild) {
  const support = guild.roles.cache.find((r) => r.name === "Support");
  if (!support) return;
  try {
    const owner = await guild.fetchOwner();
    if (!owner.roles.cache.has(support.id)) {
      await owner.roles.add(support, "Server owner can see support tickets");
      console.log(`Gave @Support to ${owner.user.tag}`);
    }
  } catch (err) {
    console.error(`Could not give @Support to the owner: ${err.message}`);
  }
}

async function prepareGuild(guild) {
  try {
    await guild.commands.set(commands);
    console.log(`Registered commands in ${guild.name}`);
  } catch (err) {
    console.error(`Failed to register commands in ${guild.name}:`, err.message);
  }
  const needsSetup = !guild.channels.cache.some((c) => c.name === "get-help");
  if (needsSetup) {
    try {
      console.log(`First-time setup in ${guild.name}`);
      const { report } = await applySetup(guild);
      for (const line of report) console.log(`  ${line}`);
    } catch (err) {
      console.error(`Setup failed in ${guild.name}:`, err);
    }
  }
  await assignOwnerSupport(guild);
}

function bind(client) {
  let booted = false;
  const onReady = async () => {
    if (booted) return;
    booted = true;
    console.log(`Logged in as ${client.user.tag}`);
    client.user.setActivity("Lodestar support · /faq", { type: ActivityType.Listening });
    for (const guild of client.guilds.cache.values()) {
      await prepareGuild(guild);
    }
  };
  client.once("clientReady", onReady);

  client.on("guildCreate", (guild) => prepareGuild(guild));

  client.on("guildMemberAdd", async (member) => {
    const welcome = member.guild.channels.cache.find((c) => c.name === "welcome" && c.isTextBased());
    if (!welcome) return;
    try {
      await welcome.send({
        content: `${member}, welcome to Lodestar Guide. Read the pinned message here, then #faq or /faq.`,
      });
    } catch {
      // missing send permission
    }
  });

  client.on("messageCreate", async (message) => {
    const reply = maybeAssist(message);
    if (!reply) return;
    try {
      await message.reply(reply);
    } catch {
      // ignore
    }
  });

  client.on("interactionCreate", async (interaction) => {
    try {
      await handleInteraction(interaction);
    } catch (err) {
      console.error(err);
      const text = "Something went wrong. Try again, or ping Support.";
      if (interaction.deferred || interaction.replied) {
        await interaction.followUp({ content: text, flags: MessageFlags.Ephemeral }).catch(() => {});
      } else {
        await interaction.reply({ content: text, flags: MessageFlags.Ephemeral }).catch(() => {});
      }
    }
  });
}

async function handleInteraction(interaction) {
  if (interaction.isAutocomplete()) {
    const typed = interaction.options.getFocused().toLowerCase();
    const choices = faqChoices()
      .filter((c) => c.name.toLowerCase().includes(typed) || c.value.includes(typed))
      .slice(0, 25);
    await interaction.respond(choices.length ? choices : faqChoices().slice(0, 25));
    return;
  }

  if (interaction.isStringSelectMenu() && interaction.customId === "faq_pick") {
    const faq = findFaq(interaction.values[0]);
    if (!faq) {
      await interaction.reply({ content: "Unknown topic.", flags: MessageFlags.Ephemeral });
      return;
    }
    await interaction.reply({ embeds: [faqEmbed(faq)], flags: MessageFlags.Ephemeral });
    return;
  }

  if (interaction.isButton() && interaction.customId === "ticket_open") {
    await interaction.showModal(tickets.ticketModal());
    return;
  }

  if (interaction.isButton() && interaction.customId === "ticket_close") {
    await tickets.closeTicket(interaction);
    return;
  }

  if (interaction.isModalSubmit() && interaction.customId === "ticket_modal") {
    await tickets.createTicket(interaction);
    return;
  }

  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === "help") {
    await interaction.reply({ embeds: [helpEmbed(), linksEmbed()], flags: MessageFlags.Ephemeral });
    return;
  }

  if (interaction.commandName === "faq") {
    const topic = interaction.options.getString("topic", true);
    const faq = findFaq(topic);
    if (!faq) {
      const list = FAQS.map((f) => `• **${f.id}** — ${f.title}`).join("\n");
      await interaction.reply({
        content: `No FAQ matched \`${topic}\`. Topics:\n${list}`,
        flags: MessageFlags.Ephemeral,
      });
      return;
    }
    await interaction.reply({ embeds: [faqEmbed(faq)] });
    return;
  }

  if (interaction.commandName === "ticket") {
    await interaction.showModal(tickets.ticketModal());
    return;
  }

  if (interaction.commandName === "close") {
    await tickets.closeTicket(interaction);
    return;
  }

  if (interaction.commandName === "setup") {
    if (!interaction.memberPermissions?.has(PermissionFlagsBits.Administrator)) {
      await interaction.reply({ content: "Administrator only.", flags: MessageFlags.Ephemeral });
      return;
    }
    await interaction.deferReply({ flags: MessageFlags.Ephemeral });
    const { report, channels } = await applySetup(interaction.guild);
    const summary = report.slice(0, 25).map((line) => `• ${line}`).join("\n");
    const extra = report.length > 25 ? `\n• …and ${report.length - 25} more` : "";
    await interaction.editReply({
      content: [
        "Lodestar Guide is set up.",
        "",
        summary + extra,
        "",
        channels["get-help"] ? `Ticket panel: ${channels["get-help"]}` : "",
        "Drag the **Lodestar Support** role above Support and Moderator in Server Settings → Roles so the bot can manage those roles.",
      ]
        .filter(Boolean)
        .join("\n"),
    });
  }
}

async function start(privileged) {
  const client = makeClient(privileged);
  bind(client);
  client.on("error", (err) => console.error("Client error:", err));
  try {
    await client.login(config.token);
  } catch (err) {
    const intentFail = err.code === "UsedDisallowedIntents" || err.message && err.message.includes("intents");
    if (privileged && intentFail) {
      console.warn("Privileged intents are off. Reconnecting without them. /faq and tickets still work.");
      client.destroy();
      return start(false);
    }
    console.error(err);
    process.exit(1);
  }
}

start(true);
