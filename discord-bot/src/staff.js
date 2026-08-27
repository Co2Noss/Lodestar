"use strict";

const { PermissionFlagsBits } = require("discord.js");
const config = require("./config");

const STAFF_ROLE_NAMES = ["Developer", "Moderator", "Support"];

function roleByName(guild, name) {
  return (guild && guild.roles && guild.roles.cache.find((r) => r.name === name)) || null;
}

function isStaff(member) {
  if (!member) return false;
  if (config.developerUserIds.includes(member.id)) return true;
  if (member.permissions && member.permissions.has(PermissionFlagsBits.Administrator)) return true;
  return STAFF_ROLE_NAMES.some((name) => {
    const role = roleByName(member.guild, name);
    return role && member.roles.cache.has(role.id);
  });
}

function staffRoles(guild) {
  return STAFF_ROLE_NAMES.map((name) => roleByName(guild, name)).filter(Boolean);
}

module.exports = { STAFF_ROLE_NAMES, roleByName, isStaff, staffRoles };
