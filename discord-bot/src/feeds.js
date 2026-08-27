"use strict";

const fs = require("fs");
const path = require("path");
const { EmbedBuilder, WebhookClient } = require("discord.js");
const config = require("./config");
const state = require("./state");
const { githubJson } = require("./github");
const { findBySlug } = require("./names");

const POLL_MS = 60 * 1000;
const COLOR = 0x1f6feb;
const WEBHOOK_NAME = "Lodestar GitHub";
const WEBHOOK_ICON = path.join(__dirname, "..", "emojis", "lodestar.png");

const FEEDS = [
  { key: "git-commits", slug: "git-commits", label: "commits" },
  { key: "github-releases", slug: "github-releases", label: "releases" },
  { key: "github-issues", slug: "github-issues", label: "issues" },
];

const HOOK_KEYS = {
  "git-commits": ["git-commits"],
  "github-releases": ["github-releases"],
  "github-issues": ["github-issues", "github"],
  github: ["github", "github-issues"],
};

function repoName() {
  return config.githubRepo || "Co2Noss/Lodestar";
}

function repoUrl() {
  return `https://github.com/${repoName()}`;
}

function formatCommit(commit) {
  const sha = String(commit.sha || "").slice(0, 7);
  const msg = String((commit.commit && commit.commit.message) || "").split("\n")[0].slice(0, 90);
  const author =
    (commit.author && commit.author.login) ||
    (commit.commit && commit.commit.author && commit.commit.author.name) ||
    "unknown";
  const url = commit.html_url || `${repoUrl()}/commit/${commit.sha}`;
  return {
    embeds: [
      new EmbedBuilder()
        .setColor(COLOR)
        .setAuthor({ name: `${repoName()} · commit`, url: repoUrl() })
        .setDescription(`[\`${sha}\`](${url}) ${msg}`)
        .setFooter({ text: author })
        .setTimestamp(new Date((commit.commit && commit.commit.author && commit.commit.author.date) || Date.now())),
    ],
  };
}

function formatRelease(release) {
  const name = release.name || release.tag_name || "release";
  const url = release.html_url || repoUrl();
  const body = String(release.body || "").trim().slice(0, 400);
  const embed = new EmbedBuilder()
    .setColor(0x3fb950)
    .setAuthor({ name: `${repoName()} · release`, url: repoUrl() })
    .setTitle(name)
    .setURL(url)
    .setFooter({ text: (release.author && release.author.login) || "GitHub" })
    .setTimestamp(new Date(release.published_at || release.created_at || Date.now()));
  if (body) embed.setDescription(body);
  return { embeds: [embed] };
}

function isPullRequest(item) {
  return Boolean(item && item.pull_request);
}

function formatIssue(item) {
  const url = item.html_url || repoUrl();
  const verb = item.state === "closed" ? "closed" : "opened";
  return {
    embeds: [
      new EmbedBuilder()
        .setColor(0x3fb950)
        .setAuthor({ name: `${repoName()} · issue ${verb}`, url: repoUrl() })
        .setTitle(`#${item.number} ${item.title}`.slice(0, 250))
        .setURL(url)
        .setFooter({ text: (item.user && item.user.login) || "GitHub" })
        .setTimestamp(new Date(item.updated_at || item.created_at || Date.now())),
    ],
  };
}

function resolveHookRecord(feedWebhooks, key) {
  const aliases = HOOK_KEYS[key] || [key];
  for (const k of aliases) {
    const rec = feedWebhooks && feedWebhooks[k];
    if (rec && rec.id && rec.token) return rec;
  }
  return null;
}

function hookRecord(guildId, key) {
  const { g } = state.guildState(guildId);
  return resolveHookRecord(g.feedWebhooks, key);
}

function saveHook(guildId, key, hook) {
  if (!hook || !hook.id || !hook.token) return;
  state.patch(guildId, (g) => {
    if (!g.feedWebhooks) g.feedWebhooks = {};
    const rec = { id: hook.id, token: hook.token };
    g.feedWebhooks[key] = rec;
    if (key === "github-issues") g.feedWebhooks.github = rec;
    if (key === "github") g.feedWebhooks["github-issues"] = rec;
  });
}

function migrateHookKeys(guildId) {
  state.patch(guildId, (g) => {
    if (!g.feedWebhooks) g.feedWebhooks = {};
    if (g.feedWebhooks.github && !g.feedWebhooks["github-issues"]) {
      g.feedWebhooks["github-issues"] = g.feedWebhooks.github;
    }
  });
}

async function ensureChannelWebhook(channel, key, report) {
  if (!channel || !channel.fetchWebhooks) return null;
  let avatar;
  try {
    avatar = fs.readFileSync(WEBHOOK_ICON);
  } catch (err) {
    if (report) report.push(`could not read webhook icon: ${err.message}`);
    return null;
  }
  try {
    const hooks = await channel.fetchWebhooks();
    const existing =
      hooks.find((h) => h.owner && channel.client.user && h.owner.id === channel.client.user.id) ||
      hooks.find((h) => /lodestar github/i.test(h.name || "")) ||
      hooks.find((h) => /github|lodestar/i.test(h.name || ""));
    const hook = existing
      ? await existing.edit({ name: WEBHOOK_NAME, avatar })
      : await channel.createWebhook({
          name: WEBHOOK_NAME,
          avatar,
          reason: "GitHub feed with Lodestar icon",
        });
    saveHook(channel.guild.id, key, hook);
    if (report) report.push(`${existing ? "set" : "created"} webhook in #${channel.name}`);
    return hook;
  } catch (err) {
    if (report) report.push(`could not set webhook in #${channel.name}: ${err.message}`);
    else console.error(`could not set webhook in #${channel.name}:`, err.message);
    return null;
  }
}

async function ensureGuildWebhooks(guild, report) {
  migrateHookKeys(guild.id);
  for (const feed of FEEDS) {
    const channel = findBySlug(guild, feed.slug, (c) => c.isTextBased());
    if (!channel) {
      if (report) report.push(`missing feed channel #${feed.slug}`);
      continue;
    }
    const existing = hookRecord(guild.id, feed.key);
    if (existing) continue;
    await ensureChannelWebhook(channel, feed.key, report);
  }
}

async function post(guild, key, payload) {
  const rec = hookRecord(guild.id, key);
  if (rec && rec.id && rec.token) {
    const hook = new WebhookClient({ id: rec.id, token: rec.token });
    try {
      await hook.send({ ...payload, allowedMentions: { parse: [] } });
      return true;
    } catch (err) {
      console.error(`feed webhook ${key} failed:`, err.message);
    } finally {
      hook.destroy();
    }
  }
  const feed = FEEDS.find((f) => f.key === key);
  const channel = findBySlug(guild, (feed && feed.slug) || key, (c) => c.isTextBased());
  if (!channel) return false;
  await channel.send({ ...payload, allowedMentions: { parse: [] } }).catch(() => {});
  return true;
}

function feedState(guildId) {
  return state.patch(guildId, (g) => {
    if (!g.feeds) g.feeds = {};
  }).feeds;
}

async function pollCommits(guild) {
  const commits = await githubJson(`/repos/${repoName()}/commits?per_page=10`);
  if (!Array.isArray(commits) || !commits.length) return 0;
  const feeds = feedState(guild.id);
  if (!feeds.lastCommitSha) {
    state.patch(guild.id, (g) => {
      g.feeds.lastCommitSha = commits[0].sha;
    });
    return 0;
  }
  const fresh = [];
  for (const c of commits) {
    if (c.sha === feeds.lastCommitSha) break;
    fresh.push(c);
  }
  fresh.reverse();
  for (const c of fresh) await post(guild, "git-commits", formatCommit(c));
  if (fresh.length) {
    state.patch(guild.id, (g) => {
      g.feeds.lastCommitSha = commits[0].sha;
    });
  }
  return fresh.length;
}

async function pollReleases(guild) {
  const releases = await githubJson(`/repos/${repoName()}/releases?per_page=5`);
  const feeds = feedState(guild.id);
  if (!Array.isArray(releases) || !releases.length) {
    if (feeds.lastReleaseId == null) {
      state.patch(guild.id, (g) => {
        g.feeds.lastReleaseId = 0;
      });
    }
    return 0;
  }
  // null = never polled. 0 = polled when the repo had no releases; the next one should post.
  if (feeds.lastReleaseId == null) {
    state.patch(guild.id, (g) => {
      g.feeds.lastReleaseId = releases[0].id;
    });
    return 0;
  }
  const fresh = [];
  for (const r of releases) {
    if (r.id === feeds.lastReleaseId) break;
    fresh.push(r);
  }
  fresh.reverse();
  for (const r of fresh) await post(guild, "github-releases", formatRelease(r));
  if (fresh.length) {
    state.patch(guild.id, (g) => {
      g.feeds.lastReleaseId = releases[0].id;
    });
  }
  return fresh.length;
}

async function pollIssues(guild) {
  const items = await githubJson(`/repos/${repoName()}/issues?state=all&sort=updated&direction=desc&per_page=15`);
  if (!Array.isArray(items) || !items.length) return 0;
  const feeds = feedState(guild.id);
  if (!feeds.lastIssueAt) {
    state.patch(guild.id, (g) => {
      g.feeds.lastIssueAt = items[0].updated_at;
    });
    return 0;
  }
  const last = Date.parse(feeds.lastIssueAt);
  const newer = items.filter((i) => Date.parse(i.updated_at) > last);
  const fresh = newer.filter((i) => !isPullRequest(i)).reverse();
  for (const item of fresh) await post(guild, "github-issues", formatIssue(item));
  if (newer.length) {
    state.patch(guild.id, (g) => {
      g.feeds.lastIssueAt = items[0].updated_at;
    });
  }
  return fresh.length;
}

async function announceConnected(guild) {
  const feeds = feedState(guild.id);
  if (feeds.announced) return;
  const intro = (what) => ({
    embeds: [
      new EmbedBuilder()
        .setColor(config.color)
        .setTitle("Lodestar GitHub feed is live")
        .setDescription(`New **${what}** from [${repoName()}](${repoUrl()}) will show up here.`)
        .setTimestamp(new Date()),
    ],
  });
  for (const feed of FEEDS) {
    await post(guild, feed.key, intro(feed.label));
  }
  state.patch(guild.id, (g) => {
    g.feeds.announced = true;
  });
}

async function pollGuild(guild) {
  let n = 0;
  try {
    n += await pollCommits(guild);
  } catch (err) {
    console.error("commit feed failed:", err.message);
  }
  try {
    n += await pollReleases(guild);
  } catch (err) {
    console.error("release feed failed:", err.message);
  }
  try {
    n += await pollIssues(guild);
  } catch (err) {
    console.error("issue feed failed:", err.message);
  }
  return n;
}

function start(client) {
  const run = async () => {
    for (const guild of client.guilds.cache.values()) {
      try {
        await ensureGuildWebhooks(guild);
        await announceConnected(guild);
        await pollGuild(guild);
      } catch (err) {
        console.error(`GitHub feeds failed in ${guild.name}:`, err.message);
      }
    }
  };
  run().catch((err) => console.error("GitHub feeds startup failed:", err.message));
  const timer = setInterval(run, POLL_MS);
  timer.unref();
  return timer;
}

module.exports = {
  start,
  pollGuild,
  formatCommit,
  formatRelease,
  formatIssue,
  isPullRequest,
  resolveHookRecord,
  ensureChannelWebhook,
  ensureGuildWebhooks,
  POLL_MS,
};
