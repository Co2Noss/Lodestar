"use strict";

function channelSlug(name) {
  return String(name || "")
    .replace(/^[^\p{L}\p{N}]+/u, "")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

function findBySlug(guild, slug, predicate) {
  if (!guild || !guild.channels) return null;
  const want = channelSlug(slug);
  return (
    guild.channels.cache.find((c) => {
      if (channelSlug(c.name) !== want) return false;
      return predicate ? predicate(c) : true;
    }) || null
  );
}

module.exports = { channelSlug, findBySlug };
