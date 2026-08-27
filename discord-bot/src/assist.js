"use strict";

const { ChannelType } = require("discord.js");
const { suggestFaq, faqEmbed } = require("./faqs");

const COOLDOWN_MS = 15 * 60 * 1000;
const lastHelp = new Map();

const SUPPORT_CHANNELS = new Set(["general", "questions", "get-help"]);

function maybeAssist(message) {
  if (!message.guild || message.author.bot) return null;
  const channel = message.channel;
  const name = channel.name || (channel.parent && channel.parent.name) || "";
  const parentName = channel.parent && channel.parent.name;
  const inSupport =
    SUPPORT_CHANNELS.has(name) ||
    (channel.type === ChannelType.PublicThread && parentName === "questions");
  if (!inSupport) return null;
  if (message.content.length < 12) return null;

  const now = Date.now();
  const prev = lastHelp.get(message.author.id) || 0;
  if (now - prev < COOLDOWN_MS) return null;

  const faq = suggestFaq(message.content);
  if (!faq) return null;
  lastHelp.set(message.author.id, now);
  return {
    content: `${message.author}, this might already be answered. If it is not, open a ticket in #get-help or post in the questions forum.`,
    embeds: [faqEmbed(faq)],
  };
}

module.exports = { maybeAssist, COOLDOWN_MS };
