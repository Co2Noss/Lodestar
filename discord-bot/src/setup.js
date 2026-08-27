"use strict";

const {
  ChannelType,
  PermissionFlagsBits,
  EmbedBuilder,
  ActionRowBuilder,
  ButtonBuilder,
  ButtonStyle,
  StringSelectMenuBuilder,
} = require("discord.js");
const config = require("./config");
const { FAQS, faqEmbed, linksEmbed } = require("./faqs");
const state = require("./state");
const verification = require("./verification");
const emojis = require("./emojis");
const alpha = require("./alpha");
const github = require("./github");
const feeds = require("./feeds");
const { channelSlug } = require("./names");

const P = PermissionFlagsBits;

const STAFF_ALLOW = [
  P.ViewChannel,
  P.SendMessages,
  P.EmbedLinks,
  P.AttachFiles,
  P.ReadMessageHistory,
  P.AddReactions,
  P.ManageMessages,
  P.ManageThreads,
  P.CreatePublicThreads,
  P.CreatePrivateThreads,
  P.SendMessagesInThreads,
];

function everyoneRead(guild) {
  return [
    {
      id: guild.roles.everyone.id,
      allow: [P.ViewChannel, P.ReadMessageHistory, P.AddReactions],
      deny: [P.SendMessages, P.CreatePublicThreads, P.SendMessagesInThreads],
    },
  ];
}

function membersRead(guild, roles) {
  const overwrites = [
    { id: guild.roles.everyone.id, deny: [P.ViewChannel] },
  ];
  if (roles.member) {
    overwrites.push({
      id: roles.member.id,
      allow: [P.ViewChannel, P.ReadMessageHistory, P.AddReactions],
      deny: [P.SendMessages, P.CreatePublicThreads, P.SendMessagesInThreads],
    });
  }
  for (const key of ["developer", "moderator", "support"]) {
    if (roles[key]) overwrites.push({ id: roles[key].id, allow: STAFF_ALLOW });
  }
  return overwrites;
}

function membersChat(guild, roles) {
  const overwrites = [
    { id: guild.roles.everyone.id, deny: [P.ViewChannel] },
  ];
  if (roles.member) {
    overwrites.push({
      id: roles.member.id,
      allow: [
        P.ViewChannel,
        P.SendMessages,
        P.ReadMessageHistory,
        P.AddReactions,
        P.EmbedLinks,
        P.AttachFiles,
        P.CreatePublicThreads,
        P.SendMessagesInThreads,
      ],
    });
  }
  for (const key of ["developer", "moderator", "support"]) {
    if (roles[key]) overwrites.push({ id: roles[key].id, allow: STAFF_ALLOW });
  }
  return overwrites;
}

function gateOverwrites(guild, roles, unverified) {
  const overwrites = [{ id: guild.roles.everyone.id, deny: [P.ViewChannel] }];
  if (roles.unverified) {
    overwrites.push({
      id: roles.unverified.id,
      allow: unverified.allow,
      deny: unverified.deny,
    });
  }
  if (roles.member) {
    overwrites.push({ id: roles.member.id, deny: [P.ViewChannel] });
  }
  if (roles.bot) {
    overwrites.push({
      id: roles.bot.id,
      allow: [P.ViewChannel, P.SendMessages, P.ReadMessageHistory],
    });
  }
  return addStaffOverwrites(overwrites, roles);
}

function welcomeOverwrites(guild, roles) {
  return gateOverwrites(guild, roles, {
    allow: [P.ViewChannel, P.ReadMessageHistory, P.AddReactions],
    deny: [P.SendMessages, P.CreatePublicThreads, P.SendMessagesInThreads],
  });
}

function honeypotOverwrites(guild, roles) {
  return gateOverwrites(guild, roles, {
    allow: [P.ViewChannel, P.SendMessages, P.ReadMessageHistory],
    deny: [P.AddReactions, P.CreatePublicThreads, P.SendMessagesInThreads, P.AttachFiles, P.EmbedLinks],
  });
}

function hiddenStaff(guild, roles) {
  const overwrites = [{ id: guild.roles.everyone.id, deny: [P.ViewChannel] }];
  for (const key of ["developer", "moderator", "support"]) {
    if (roles[key]) overwrites.push({ id: roles[key].id, allow: STAFF_ALLOW });
  }
  return overwrites;
}

function hiddenTickets(guild, roles) {
  return [
    { id: guild.roles.everyone.id, deny: [P.ViewChannel] },
    { id: roles.support.id, allow: STAFF_ALLOW },
    { id: roles.moderator.id, allow: STAFF_ALLOW },
  ];
}

function addStaffOverwrites(overwrites, roles) {
  for (const key of ["developer", "moderator", "support"]) {
    if (roles[key]) overwrites.push({ id: roles[key].id, allow: STAFF_ALLOW });
  }
  return overwrites;
}

function hiddenAlpha(guild, roles) {
  const overwrites = [{ id: guild.roles.everyone.id, deny: [P.ViewChannel] }];
  if (roles.alpha) {
    overwrites.push({
      id: roles.alpha.id,
      allow: [P.ViewChannel, P.ReadMessageHistory, P.AddReactions],
    });
  }
  return addStaffOverwrites(overwrites, roles);
}

function alphaRead(guild, roles) {
  const overwrites = [{ id: guild.roles.everyone.id, deny: [P.ViewChannel] }];
  if (roles.alpha) {
    overwrites.push({
      id: roles.alpha.id,
      allow: [P.ViewChannel, P.ReadMessageHistory, P.AddReactions],
      deny: [P.SendMessages, P.CreatePublicThreads, P.SendMessagesInThreads],
    });
  }
  return addStaffOverwrites(overwrites, roles);
}

function alphaChat(guild, roles) {
  const overwrites = [{ id: guild.roles.everyone.id, deny: [P.ViewChannel] }];
  if (roles.alpha) {
    overwrites.push({
      id: roles.alpha.id,
      allow: [
        P.ViewChannel,
        P.SendMessages,
        P.ReadMessageHistory,
        P.AddReactions,
        P.EmbedLinks,
        P.AttachFiles,
        P.CreatePublicThreads,
        P.SendMessagesInThreads,
      ],
    });
  }
  return addStaffOverwrites(overwrites, roles);
}

const ROLE_SPECS = [
  {
    key: "unverified",
    name: "Unverified",
    color: 0x99aab5,
    hoist: false,
    mentionable: false,
    permissions: [],
  },
  {
    key: "member",
    name: "Member",
    color: 0x57f287,
    hoist: false,
    mentionable: false,
    permissions: [],
  },
  {
    key: "bot",
    name: "Bot",
    color: 0x99aab5,
    hoist: true,
    mentionable: false,
    permissions: [],
  },
  {
    key: "contributor",
    name: "Contributor",
    color: config.color,
    hoist: true,
    mentionable: true,
    permissions: [],
  },
  {
    key: "alpha",
    name: "Alpha Tester",
    color: 0xeb459e,
    hoist: true,
    mentionable: true,
    permissions: [],
  },
  {
    key: "support",
    name: "Support",
    color: config.accent,
    hoist: true,
    mentionable: true,
    permissions: [P.ViewChannel, P.SendMessages, P.EmbedLinks, P.AttachFiles, P.ReadMessageHistory, P.ManageMessages, P.ManageThreads],
  },
  {
    key: "moderator",
    name: "Moderator",
    color: 0x5865f2,
    hoist: true,
    mentionable: false,
    permissions: [
      P.ViewChannel,
      P.SendMessages,
      P.EmbedLinks,
      P.AttachFiles,
      P.ReadMessageHistory,
      P.ManageMessages,
      P.ManageThreads,
      P.ModerateMembers,
      P.KickMembers,
      P.BanMembers,
    ],
  },
  {
    key: "developer",
    name: "Developer",
    color: config.color,
    hoist: true,
    mentionable: true,
    permissions: [
      P.ViewChannel,
      P.SendMessages,
      P.EmbedLinks,
      P.AttachFiles,
      P.ReadMessageHistory,
      P.ManageMessages,
      P.ManageThreads,
      P.ModerateMembers,
      P.KickMembers,
      P.BanMembers,
    ],
  },
];

const CATEGORY_SPECS = [
  { key: "info", name: "ℹ️ Info", aliases: ["Info"] },
  { key: "support", name: "💬 Support", aliases: ["Support"] },
  { key: "tickets", name: "🎫 Tickets", aliases: ["Tickets"], hidden: true },
  { key: "community", name: "👥 Community", aliases: ["Community"] },
  { key: "development", name: "📢 Dev Feeds", aliases: ["Development", "Dev Feeds", "📢 Dev Feeds"] },
  { key: "alpha", name: "🧪 Alpha", aliases: ["Alpha"], overwrites: hiddenAlpha },
  { key: "staff", name: "🛠️ Staff", aliases: ["Staff"], hidden: true },
];

function channelSpecs(guild, roles) {
  const announceType = guild.features.includes("COMMUNITY")
    ? ChannelType.GuildAnnouncement
    : ChannelType.GuildText;
  return [
    { key: "welcome", name: "👋welcome", aliases: ["welcome"], parent: "info", type: ChannelType.GuildText, topic: "Start here. Click the button after you read the rules.", overwrites: welcomeOverwrites(guild, roles) },
    { key: "rules", name: "📜rules", aliases: ["rules"], parent: "info", type: ChannelType.GuildText, topic: "How this server works.", overwrites: everyoneRead(guild) },
    { key: "silence-enforced", name: "🍯silence-enforced", aliases: ["silence-enforced"], parent: "info", type: ChannelType.GuildText, topic: "Do not type here. Spam bots that do are softbanned.", overwrites: honeypotOverwrites(guild, roles) },
    { key: "announcements", name: "📣announcements", aliases: ["announcements"], parent: "info", type: announceType, topic: "Lodestar news from staff.", overwrites: membersRead(guild, roles) },
    { key: "releases", name: "📦releases", aliases: ["releases"], parent: "info", type: announceType, topic: "Addon releases and hotfixes.", overwrites: membersRead(guild, roles) },
    { key: "links", name: "🔗links", aliases: ["links"], parent: "info", type: ChannelType.GuildText, topic: "CurseForge, GitHub, wiki, PayPal.", overwrites: membersRead(guild, roles) },
    { key: "get-help", name: "🎫get-help", aliases: ["get-help"], parent: "support", type: ChannelType.GuildText, topic: "Open a private ticket with Support.", overwrites: membersRead(guild, roles) },
    { key: "faq", name: "❓faq", aliases: ["faq"], parent: "support", type: ChannelType.GuildText, topic: "Answers that do not need a ticket.", overwrites: membersRead(guild, roles) },
    {
      key: "questions",
      name: "💡questions",
      aliases: ["questions"],
      parent: "support",
      type: ChannelType.GuildForum,
      topic: "One question per post. Search first. Include class/spec and theme.",
      overwrites: membersChat(guild, roles),
      availableTags: [
        { name: "Install" },
        { name: "Dashboard" },
        { name: "Professions" },
        { name: "Great Vault" },
        { name: "Gold" },
        { name: "Theme" },
        { name: "Optional addons" },
        { name: "Other" },
      ],
    },
    { key: "general", name: "💬general", aliases: ["general"], parent: "community", type: ChannelType.GuildText, topic: "Talk about Lodestar and WoW.", overwrites: membersChat(guild, roles) },
    { key: "screenshots", name: "🖼️screenshots", aliases: ["screenshots"], parent: "community", type: ChannelType.GuildText, topic: "Dashboard layouts, compact mode, themes.", overwrites: membersChat(guild, roles) },
    { key: "off-topic", name: "🌙off-topic", aliases: ["off-topic"], parent: "community", type: ChannelType.GuildText, topic: "Not Lodestar. Still be decent.", overwrites: membersChat(guild, roles) },
    {
      key: "git-commits",
      name: "📝git-commits",
      aliases: ["git-commits", "commits"],
      parent: "development",
      type: ChannelType.GuildText,
      topic: "GitHub commits. The bot posts new commits here.",
      overwrites: membersRead(guild, roles),
      webhook: true,
    },
    {
      key: "github-releases",
      name: "🚀github-releases",
      aliases: ["github-releases"],
      parent: "development",
      type: ChannelType.GuildText,
      topic: "GitHub releases. The bot posts new tags here.",
      overwrites: membersRead(guild, roles),
      webhook: true,
    },
    {
      key: "github",
      name: "🐛github-issues",
      aliases: ["github-issues", "github-actions", "github", "issues"],
      parent: "development",
      type: ChannelType.GuildText,
      topic: "GitHub issues. The bot posts new and updated issues here, not pull requests.",
      overwrites: membersRead(guild, roles),
      webhook: true,
      webhookKey: "github-issues",
    },
    { key: "alpha-news", name: "🧪alpha-news", aliases: ["alpha-news"], parent: "alpha", type: ChannelType.GuildText, topic: "What to test. Staff posts here.", overwrites: alphaRead(guild, roles) },
    { key: "alpha-chat", name: "🗣️alpha-chat", aliases: ["alpha-chat"], parent: "alpha", type: ChannelType.GuildText, topic: "Talk while you test unreleased builds.", overwrites: alphaChat(guild, roles) },
    { key: "alpha-feedback", name: "📋alpha-feedback", aliases: ["alpha-feedback"], parent: "alpha", type: ChannelType.GuildText, topic: "Bugs and notes from alpha builds.", overwrites: alphaChat(guild, roles) },
    { key: "staff", name: "🔒staff", aliases: ["staff"], parent: "staff", type: ChannelType.GuildText, topic: "Staff only.", overwrites: hiddenStaff(guild, roles) },
    { key: "mod-log", name: "⚖️mod-log", aliases: ["mod-log"], parent: "staff", type: ChannelType.GuildText, topic: "Warns, timeouts, kicks, bans, automod.", overwrites: hiddenStaff(guild, roles) },
    { key: "ticket-logs", name: "📁ticket-logs", aliases: ["ticket-logs"], parent: "staff", type: ChannelType.GuildText, topic: "Closed ticket transcripts.", overwrites: hiddenStaff(guild, roles) },
  ];
}

function findRole(guild, name) {
  return guild.roles.cache.find((r) => r.name === name) || null;
}

function findChannel(guild, nameOrSpec, aliases, type) {
  const names = typeof nameOrSpec === "object" && nameOrSpec
    ? [nameOrSpec.name, ...(nameOrSpec.aliases || [])]
    : [nameOrSpec, ...(aliases || [])];
  const pool = [...guild.channels.cache.values()].filter((c) => type == null || c.type === type);
  for (const name of names) {
    if (!name) continue;
    const hit = pool.find((c) => c.name === name);
    if (hit) return hit;
  }
  const slugs = new Set(names.map(channelSlug).filter(Boolean));
  return pool.find((c) => slugs.has(channelSlug(c.name))) || null;
}

async function ensureRole(guild, spec, report) {
  let role = findRole(guild, spec.name);
  if (!role) {
    role = await guild.roles.create({
      name: spec.name,
      colors: { primaryColor: spec.color },
      hoist: spec.hoist,
      mentionable: spec.mentionable,
      permissions: spec.permissions,
      reason: "Lodestar Support /setup",
    });
    report.push(`created role @${spec.name}`);
  } else {
    report.push(`reused role @${spec.name}`);
  }
  return role;
}

async function ensureCategory(guild, spec, roles, report) {
  let channel = findChannel(guild, spec, undefined, ChannelType.GuildCategory);
  if (channel && channel.type !== ChannelType.GuildCategory) {
    report.push(`skipped category ${spec.name}: a non-category channel already uses that name`);
    return channel;
  }
  const overwrites = spec.overwrites
    ? spec.overwrites(guild, roles)
    : spec.hidden
      ? hiddenStaff(guild, roles)
      : [];
  if (!channel) {
    const extras = {};
    const staffCat = findChannel(guild, "Staff", undefined, ChannelType.GuildCategory);
    if (spec.key === "alpha" && staffCat && staffCat.type === ChannelType.GuildCategory) {
      extras.position = staffCat.rawPosition;
    }
    channel = await guild.channels.create({
      name: spec.name,
      type: ChannelType.GuildCategory,
      permissionOverwrites: overwrites,
      reason: "Lodestar Support /setup",
      ...extras,
    });
    report.push(`created category ${spec.name}`);
    return channel;
  }
  if (channel.name !== spec.name) {
    await channel.setName(spec.name, "Lodestar Support /setup");
    report.push(`renamed category to ${spec.name}`);
  } else {
    report.push(`reused category ${spec.name}`);
  }
  if (overwrites.length) await channel.permissionOverwrites.set(overwrites);
  return channel;
}

async function ensureChannel(guild, spec, categories, roles, report) {
  const parent = categories[spec.parent];
  let channel = findChannel(guild, spec);
  const extras = {};
  if (spec.availableTags) extras.availableTags = spec.availableTags;
  if (spec.topic) extras.topic = spec.topic;

  if (!channel) {
    channel = await guild.channels.create({
      name: spec.name,
      type: spec.type,
      parent: parent ? parent.id : undefined,
      permissionOverwrites: spec.overwrites,
      reason: "Lodestar Support /setup",
      ...extras,
    });
    report.push(`created #${spec.name}`);
    return channel;
  }

  const patch = {};
  if (channel.name !== spec.name) patch.name = spec.name;
  if (parent && channel.parentId !== parent.id) patch.parent = parent.id;
  if (spec.topic && channel.topic !== spec.topic && channel.isTextBased()) patch.topic = spec.topic;
  if (Object.keys(patch).length) {
    await channel.edit(patch);
    report.push(patch.name ? `renamed #${spec.name}` : `moved #${spec.name}`);
  } else {
    report.push(`reused #${spec.name}`);
  }
  if (spec.overwrites && channel.permissionOverwrites) {
    try {
      await channel.permissionOverwrites.set(spec.overwrites);
    } catch (err) {
      report.push(`could not set permissions on #${spec.name}: ${err.message}`);
    }
  }
  return channel;
}

function withEmoji(guild, name, text) {
  const em = emojis.mention(guild, name);
  return em ? `${em}  ${text}` : text;
}

function welcomeEmbed(guild) {
  return new EmbedBuilder()
    .setColor(config.color)
    .setTitle(withEmoji(guild, "lodestar", "Lodestar Guide"))
    .setDescription(
      [
        "**Find what matters. Ignore the rest.**",
        "",
        "Lodestar is a decision engine for World of Warcraft. This server is for install help, questions, and bugs.",
        "",
        `1. Read <#RULES>`,
        "2. Click **I have read the rules** below. That unlocks the rest of the server.",
        "3. Check <#FAQ> or `/faq`",
        "4. Public questions go in <#QUESTIONS>",
        "5. Private tickets start in <#GETHELP>",
        "",
        "Do not type in #silence-enforced. That channel is bait for spam bots.",
      ].join("\n")
    )
    .addFields(
      { name: "Download", value: `[CurseForge](${config.links.curseforge}) · [GitHub](${config.links.github})` },
      { name: "Docs", value: `[Wiki](${config.links.wiki}) · [Issues](${config.links.issues})` }
    );
}

function rulesEmbed(guild) {
  return new EmbedBuilder()
    .setColor(config.color)
    .setTitle(withEmoji(guild, "quest", "Rules"))
    .setDescription(
      [
        "1. Be decent. This is a support server, not a raid.",
        "2. Search #faq, `/faq`, and the [wiki](https://github.com/Co2Noss/Lodestar/wiki) before asking.",
        "3. Bugs need class/spec, theme (Blizzard, ElvUI, or other), Lodestar version, and expected versus actual. `/ls debug` first if you are not sure which addon errored.",
        "4. No piracy, account trading, or NSFW. No invite ads.",
        "5. Staff may close idle tickets. Re-open one if you still need help.",
        "6. The bot removes spam, invite ads, and mass mentions. Co2Noss is developer, moderator, and support — `/mod` is there when a person needs a warn, timeout, kick, or ban.",
        "7. Click **I have read the rules** in #welcome to unlock the server. Do not type in #silence-enforced — that is a honeypot. Messages there are a softban.",
      ].join("\n")
    );
}

function ticketPanel(guild) {
  const embed = new EmbedBuilder()
    .setColor(config.color)
    .setTitle(withEmoji(guild, "bag", "Get help"))
    .setDescription(
      [
        "Open a **private ticket** with Support. Include class/spec, the theme you use, and what you expected versus what happened.",
        "",
        "If you are not sure Lodestar is the addon erroring, `/ls debug` isolates it.",
        "",
        "Questions the whole server can answer belong in the questions forum.",
      ].join("\n")
    );
  const row = new ActionRowBuilder().addComponents(
    new ButtonBuilder().setCustomId("ticket_open").setLabel("Open a ticket").setStyle(ButtonStyle.Primary),
    new ButtonBuilder().setLabel("GitHub issues").setStyle(ButtonStyle.Link).setURL(config.links.issues),
    new ButtonBuilder().setLabel("Wiki").setStyle(ButtonStyle.Link).setURL(config.links.wiki)
  );
  return { embeds: [embed], components: [row] };
}

function faqPanel(guild) {
  const embed = new EmbedBuilder()
    .setColor(config.color)
    .setTitle(withEmoji(guild, "lodestar", "FAQ"))
    .setDescription("Pick a topic, or type `/faq` anywhere. These answers come from how Lodestar actually works — it does not invent data the client does not have.");
  const options = FAQS.slice(0, 25).map((f) => ({
    label: f.title.slice(0, 100),
    value: f.id,
  }));
  const row = new ActionRowBuilder().addComponents(
    new StringSelectMenuBuilder().setCustomId("faq_pick").setPlaceholder("Choose a topic").addOptions(options)
  );
  return { embeds: [embed], components: [row] };
}

async function replaceBotMessage(channel, key, payload, guildId) {
  if (!channel || !channel.isTextBased()) return;
  const saved = state.guildState(guildId).g.messages[key];
  if (saved) {
    try {
      const existing = await channel.messages.fetch(saved);
      await existing.edit(payload);
      return existing;
    } catch {
      // posted message is gone; send a new one
    }
  }
  const sent = await channel.send(payload);
  try {
    await sent.pin();
  } catch {
    // pin cap or missing permission
  }
  state.patch(guildId, (g) => {
    g.messages[key] = sent.id;
  });
  return sent;
}

function mention(channel) {
  return channel ? `<#${channel.id}>` : "(missing)";
}

async function assignPeople(guild, roles, report) {
  try {
    await guild.members.fetch();
  } catch {
    // member intent missing; still try cache
  }
  const staffWanted = [roles.developer, roles.moderator, roles.support].filter(Boolean);
  for (const id of config.developerUserIds) {
    const member = await guild.members.fetch(id).catch(() => null);
    if (!member) {
      report.push(`could not find developer user ${id}`);
      continue;
    }
    const missing = staffWanted.filter((r) => !member.roles.cache.has(r.id));
    if (!missing.length) continue;
    try {
      await member.roles.add(missing, "Co2Noss is developer, moderator, and support");
      report.push(`gave ${missing.map((r) => `@${r.name}`).join(", ")} to ${member.user.tag}`);
    } catch (err) {
      report.push(`could not assign staff roles to ${member.user.tag}: ${err.message}`);
    }
  }
  if (roles.bot) {
    for (const member of guild.members.cache.values()) {
      if (!member.user.bot || member.roles.cache.has(roles.bot.id)) continue;
      try {
        await member.roles.add(roles.bot, "Bot role");
        report.push(`gave @Bot to ${member.user.tag}`);
      } catch (err) {
        report.push(`could not give @Bot to ${member.user.tag}: ${err.message}`);
      }
    }
  }
  if (!roles.unverified) return;
  for (const member of guild.members.cache.values()) {
    if (member.user.bot) continue;
    const hasMember = roles.member && member.roles.cache.has(roles.member.id);
    const hasStaff = ["developer", "moderator", "support"].some(
      (key) => roles[key] && member.roles.cache.has(roles[key].id)
    );
    const hasUnverified = member.roles.cache.has(roles.unverified.id);
    if (hasMember || hasStaff) {
      if (!hasUnverified) continue;
      try {
        await member.roles.remove(roles.unverified, "Verified or staff: hide welcome and honeypot");
        report.push(`removed @Unverified from ${member.user.tag}`);
      } catch (err) {
        report.push(`could not remove @Unverified from ${member.user.tag}: ${err.message}`);
      }
      continue;
    }
    if (hasUnverified) continue;
    try {
      await member.roles.add(roles.unverified, "Unverified until they accept the rules");
      report.push(`gave @Unverified to ${member.user.tag}`);
    } catch (err) {
      report.push(`could not give @Unverified to ${member.user.tag}: ${err.message}`);
    }
  }
}

async function applySetup(guild) {
  const report = [];
  const roles = {};
  for (const spec of ROLE_SPECS) {
    try {
      roles[spec.key] = await ensureRole(guild, spec, report);
    } catch (err) {
      report.push(`failed role @${spec.name}: ${err.message}`);
    }
  }
  if (!roles.support || !roles.moderator || !roles.developer || !roles.bot || !roles.member || !roles.unverified) {
    throw new Error("Could not create Member, Unverified, Developer, Moderator, Support, and Bot roles. Drag the Lodestar Support bot role to the top of the role list and run /setup again.");
  }

  const categories = {};
  for (const spec of CATEGORY_SPECS) {
    try {
      categories[spec.key] = await ensureCategory(guild, spec, roles, report);
    } catch (err) {
      report.push(`failed category ${spec.name}: ${err.message}`);
    }
  }

  const channels = {};
  for (const spec of channelSpecs(guild, roles)) {
    try {
      channels[spec.key] = await ensureChannel(guild, spec, categories, roles, report);
    } catch (err) {
      const fallback = spec.type === ChannelType.GuildAnnouncement || spec.type === ChannelType.GuildForum;
      if (fallback) {
        try {
          const retry = { ...spec, type: ChannelType.GuildText };
          delete retry.availableTags;
          channels[spec.key] = await ensureChannel(guild, retry, categories, roles, report);
          report.push(`created #${spec.name} as a text channel (forum/announcement fallback)`);
        } catch (err2) {
          report.push(`failed #${spec.name}: ${err2.message}`);
        }
      } else {
        report.push(`failed #${spec.name}: ${err.message}`);
      }
    }
  }

  for (const spec of channelSpecs(guild, roles)) {
    if (spec.webhook && channels[spec.key]) {
      await feeds.ensureChannelWebhook(channels[spec.key], spec.webhookKey || spec.key, report);
    }
  }

  await emojis.ensureEmojis(guild, report);
  try {
    await guild.emojis.fetch();
  } catch {
    // cache from create/delete is usually enough
  }

  const welcome = welcomeEmbed(guild);
  if (channels.rules && channels.faq && channels.questions && channels["get-help"]) {
    welcome.setDescription(
      welcome.data.description
        .replace("<#RULES>", mention(channels.rules))
        .replace("<#FAQ>", mention(channels.faq))
        .replace("<#QUESTIONS>", mention(channels.questions))
        .replace("<#GETHELP>", mention(channels["get-help"]))
    );
  }

  const kicks = (state.guildState(guild.id).g.honeypotKicks || 0);
  const posts = [
    [channels.welcome, "welcome", { embeds: [welcome], components: [verification.welcomeButtons()] }],
    [channels.rules, "rules", { embeds: [rulesEmbed(guild)] }],
    [channels["silence-enforced"], "honeypot", verification.honeypotPanel(kicks)],
    [channels.links, "links", { embeds: [linksEmbed()] }],
    [channels.faq, "faq", faqPanel(guild)],
    [channels["get-help"], "ticket", ticketPanel(guild)],
    [channels["alpha-news"], "alpha", alpha.panel(guild)],
    [channels.github, "github-credit", github.panel(guild)],
  ];
  for (const [channel, key, payload] of posts) {
    try {
      await replaceBotMessage(channel, key, payload, guild.id);
    } catch (err) {
      report.push(`could not post ${key}: ${err.message}`);
    }
  }

  state.patch(guild.id, (g) => {
    g.roles = {
      member: roles.member.id,
      unverified: roles.unverified.id,
      developer: roles.developer.id,
      moderator: roles.moderator.id,
      support: roles.support.id,
      bot: roles.bot.id,
      contributor: roles.contributor && roles.contributor.id,
      alpha: roles.alpha && roles.alpha.id,
    };
    g.channels = Object.fromEntries(Object.entries(channels).filter(([, ch]) => ch).map(([k, ch]) => [k, ch.id]));
    g.categories = Object.fromEntries(Object.entries(categories).filter(([, ch]) => ch).map(([k, ch]) => [k, ch.id]));
  });

  await assignPeople(guild, roles, report);
  await verification.applySecurity(guild, report);

  return { report, roles, channels, categories };
}

module.exports = {
  ROLE_SPECS,
  CATEGORY_SPECS,
  channelSpecs,
  applySetup,
  assignPeople,
  welcomeOverwrites,
  honeypotOverwrites,
  ticketPanel,
  faqPanel,
  faqEmbed,
};
