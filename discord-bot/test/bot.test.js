"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { PermissionFlagsBits } = require("discord.js");
const { FAQS, findFaq, suggestFaq, faqChoices } = require("../src/faqs");
const { ROLE_SPECS, CATEGORY_SPECS, channelSpecs } = require("../src/setup");

const P = PermissionFlagsBits;

function hasFlag(list, bit) {
  return Array.isArray(list) && list.some((x) => BigInt(x) === BigInt(bit));
}

describe("faqs", () => {
  it("has unique ids and at least a dozen topics", () => {
    const ids = FAQS.map((f) => f.id);
    assert.equal(new Set(ids).size, ids.length);
    assert.ok(FAQS.length >= 12);
  });

  it("finds install, debug, and gold by id or keyword", () => {
    assert.equal(findFaq("install").id, "install");
    assert.equal(findFaq("debug").id, "debug");
    assert.equal(findFaq("/ls debug").id, "debug");
    assert.equal(findFaq("auctionator").id, "gold");
    assert.equal(findFaq("handynotes").id, "rares");
    assert.equal(findFaq("paypal").id, "donate");
  });

  it("returns null for noise", () => {
    assert.equal(findFaq(""), null);
    assert.equal(findFaq("zzzz-not-a-topic"), null);
  });

  it("suggests a faq from a support sentence", () => {
    const gold = suggestFaq("why is gold making quiet even with auctionator loaded");
    assert.ok(gold);
    assert.equal(gold.id, "gold");
    const rares = suggestFaq("handynotes is loaded but rares never show on the plan");
    assert.ok(rares);
    assert.equal(rares.id, "rares");
    assert.equal(suggestFaq("ok"), null);
  });

  it("autocomplete choices stay within Discord's 25-option cap", () => {
    const choices = faqChoices();
    assert.ok(choices.length <= 25);
    for (const c of choices) {
      assert.ok(c.name.length <= 100);
      assert.ok(c.value.length <= 100);
    }
  });
});

describe("server layout", () => {
  it("uses unique role, category, and channel names", () => {
    const roleNames = ROLE_SPECS.map((r) => r.name);
    assert.equal(new Set(roleNames).size, roleNames.length);
    assert.ok(roleNames.includes("Member"));
    assert.ok(roleNames.includes("Unverified"));
    const unverified = ROLE_SPECS.find((r) => r.key === "unverified");
    assert.equal(unverified.hoist, false);
    assert.equal(unverified.mentionable, false);
    assert.ok(roleNames.includes("Developer"));
    assert.ok(roleNames.includes("Bot"));
    assert.ok(roleNames.includes("Moderator"));
    assert.ok(roleNames.includes("Support"));
    assert.ok(roleNames.includes("Alpha Tester"));
    assert.ok(roleNames.includes("Contributor"));
    const catNames = CATEGORY_SPECS.map((c) => c.name);
    assert.equal(new Set(catNames).size, catNames.length);
    assert.ok(catNames.includes("🧪 Alpha"));
    assert.ok(catNames.includes("📢 Dev Feeds"));
    assert.ok(catNames.includes("ℹ️ Info"));
    assert.ok(catNames.includes("🛠️ Staff"));
    const fakeGuild = { id: "1", features: ["COMMUNITY"], roles: { everyone: { id: "everyone" } } };
    const fakeRoles = {
      support: { id: "s" },
      moderator: { id: "m" },
      developer: { id: "d" },
      bot: { id: "b" },
      member: { id: "mem" },
      unverified: { id: "uv" },
      alpha: { id: "a" },
      contributor: { id: "c" },
    };
    const channels = channelSpecs(fakeGuild, fakeRoles);
    const names = channels.map((c) => c.name);
    assert.equal(new Set(names).size, names.length);
    assert.ok(names.includes("📝git-commits"));
    assert.ok(names.includes("🚀github-releases"));
    assert.ok(names.includes("🐛github-issues"));
    assert.ok(names.includes("🎫get-help"));
    assert.ok(names.includes("❓faq"));
    assert.ok(names.includes("⚖️mod-log"));
    assert.ok(names.includes("🍯silence-enforced"));
    assert.ok(names.includes("🧪alpha-news"));
    assert.ok(names.includes("🗣️alpha-chat"));
    assert.ok(names.includes("📋alpha-feedback"));
    assert.ok(names.includes("👋welcome"));
    const alphaChat = channels.find((c) => c.key === "alpha-chat");
    const everyone = alphaChat.overwrites.find((o) => o.id === "everyone");
    assert.ok(everyone);
    assert.ok(everyone.deny && everyone.deny.length);
    const tester = alphaChat.overwrites.find((o) => o.id === "a");
    assert.ok(tester);
    assert.ok(tester.allow && tester.allow.length);
    const issues = channels.find((c) => c.key === "github");
    assert.ok(issues.aliases.includes("github-actions"));
    assert.equal(issues.name, "🐛github-issues");
    assert.ok(issues.webhook);
    assert.equal(issues.webhookKey, "github-issues");
    assert.ok(channels.find((c) => c.key === "git-commits").webhook);
    assert.ok(channels.find((c) => c.key === "github-releases").webhook);
  });

  it("hides Tickets, Staff, and Alpha from @everyone", () => {
    const hidden = CATEGORY_SPECS.filter((c) => c.hidden).map((c) => c.key);
    assert.ok(hidden.includes("tickets"));
    assert.ok(hidden.includes("staff"));
    const alpha = CATEGORY_SPECS.find((c) => c.key === "alpha");
    assert.ok(alpha);
    assert.equal(typeof alpha.overwrites, "function");
    const fakeGuild = { roles: { everyone: { id: "everyone" } } };
    const overwrites = alpha.overwrites(fakeGuild, { alpha: { id: "a" } });
    const everyone = overwrites.find((o) => o.id === "everyone");
    assert.ok(everyone.deny && everyone.deny.length);
  });

  it("hides welcome and honeypot from Member, keeps them for Unverified and staff", () => {
    const fakeGuild = { id: "1", features: ["COMMUNITY"], roles: { everyone: { id: "everyone" } } };
    const fakeRoles = {
      support: { id: "s" },
      moderator: { id: "m" },
      developer: { id: "d" },
      bot: { id: "b" },
      member: { id: "mem" },
      unverified: { id: "uv" },
      alpha: { id: "a" },
    };
    const channels = channelSpecs(fakeGuild, fakeRoles);
    const welcome = channels.find((c) => c.key === "welcome");
    const honeypot = channels.find((c) => c.key === "silence-enforced");
    const rules = channels.find((c) => c.key === "rules");

    const welcomeEveryone = welcome.overwrites.find((o) => o.id === "everyone");
    const welcomeUnverified = welcome.overwrites.find((o) => o.id === "uv");
    const welcomeMember = welcome.overwrites.find((o) => o.id === "mem");
    const welcomeBot = welcome.overwrites.find((o) => o.id === "b");
    const welcomeStaff = welcome.overwrites.find((o) => o.id === "d");
    assert.ok(hasFlag(welcomeEveryone.deny, P.ViewChannel));
    assert.ok(hasFlag(welcomeUnverified.allow, P.ViewChannel));
    assert.ok(hasFlag(welcomeUnverified.allow, P.ReadMessageHistory));
    assert.ok(hasFlag(welcomeUnverified.allow, P.AddReactions));
    assert.ok(hasFlag(welcomeUnverified.deny, P.SendMessages));
    assert.ok(hasFlag(welcomeMember.deny, P.ViewChannel));
    assert.ok(hasFlag(welcomeBot.allow, P.ViewChannel));
    assert.ok(hasFlag(welcomeBot.allow, P.SendMessages));
    assert.ok(hasFlag(welcomeStaff.allow, P.ViewChannel));

    const potEveryone = honeypot.overwrites.find((o) => o.id === "everyone");
    const potUnverified = honeypot.overwrites.find((o) => o.id === "uv");
    const potMember = honeypot.overwrites.find((o) => o.id === "mem");
    const potBot = honeypot.overwrites.find((o) => o.id === "b");
    const potStaff = honeypot.overwrites.find((o) => o.id === "s");
    assert.ok(hasFlag(potEveryone.deny, P.ViewChannel));
    assert.ok(hasFlag(potUnverified.allow, P.ViewChannel));
    assert.ok(hasFlag(potUnverified.allow, P.SendMessages));
    assert.ok(hasFlag(potUnverified.allow, P.ReadMessageHistory));
    assert.ok(hasFlag(potUnverified.deny, P.AddReactions));
    assert.ok(hasFlag(potUnverified.deny, P.AttachFiles));
    assert.ok(hasFlag(potUnverified.deny, P.EmbedLinks));
    assert.ok(hasFlag(potMember.deny, P.ViewChannel));
    assert.ok(hasFlag(potBot.allow, P.ViewChannel));
    assert.ok(hasFlag(potStaff.allow, P.ViewChannel));

    const rulesEveryone = rules.overwrites.find((o) => o.id === "everyone");
    assert.ok(hasFlag(rulesEveryone.allow, P.ViewChannel));
    assert.ok(hasFlag(rulesEveryone.deny, P.SendMessages));
  });
});

describe("moderation", () => {
  const { parseDuration, offenseFromMessage, spamOffense, resetSpam } = require("../src/moderation");

  it("parses timeout durations", () => {
    assert.equal(parseDuration("10m", 0), 10 * 60 * 1000);
    assert.equal(parseDuration("1h", 0), 60 * 60 * 1000);
    assert.equal(parseDuration("1d", 0), 24 * 60 * 60 * 1000);
    assert.equal(parseDuration("nope", 0), null);
  });

  it("flags invite ads and mass mentions", () => {
    assert.equal(offenseFromMessage("join discord.gg/notours", 0, false), "invite spam");
    assert.equal(offenseFromMessage("hello", 5, false), "mass mentions");
    assert.equal(offenseFromMessage("hello", 1, true), "mass mentions");
    assert.equal(offenseFromMessage("gold making is quiet", 0, false), null);
  });

  it("flags repeated and rapid messages", () => {
    resetSpam("u1");
    const now = Date.now();
    assert.equal(spamOffense("u1", "hello", now), null);
    assert.equal(spamOffense("u1", "hello", now + 1), null);
    assert.equal(spamOffense("u1", "hello", now + 2), null);
    assert.equal(spamOffense("u1", "hello", now + 3), "repeated messages");
    resetSpam("u2");
    let hit = null;
    for (let i = 0; i < 6; i++) hit = spamOffense("u2", `msg ${i}`, now + i);
    assert.equal(hit, "message spam");
  });
});

describe("emoji pack", () => {
  const fs = require("fs");
  const path = require("path");
  const { PACK } = require("../src/emojis");

  it("ships a png for every named emoji", () => {
    assert.ok(PACK.includes("lodestar"));
    for (const name of PACK) {
      const file = path.join(__dirname, "..", "emojis", `${name}.png`);
      assert.ok(fs.existsSync(file), file);
      assert.ok(fs.statSync(file).size < 256 * 1024);
      const png = fs.readFileSync(file);
      // PNG must have an alpha channel so Discord does not paint a white box.
      assert.equal(png[25], 6, `${name} should be RGBA`);
    }
  });
});

describe("verification", () => {
  const {
    accountTooNew,
    joinPromptContent,
    generalWelcomeContent,
    isJoinPrompt,
  } = require("../src/verification");

  it("rejects brand-new Discord accounts", () => {
    const fresh = { createdTimestamp: Date.now() };
    const old = { createdTimestamp: Date.now() - 2 * 60 * 60 * 1000 };
    assert.equal(accountTooNew(fresh), true);
    assert.equal(accountTooNew(old), false);
  });

  it("builds a join ping that is later recognized as a prompt", () => {
    const text = joinPromptContent("<@123>");
    assert.match(text, /I have read the rules/);
    assert.match(text, /silence-enforced/);
    assert.equal(
      isJoinPrompt({ content: text, author: { id: "bot" } }, "bot"),
      true
    );
    assert.equal(
      isJoinPrompt({ content: text, author: { id: "other" } }, "bot"),
      false
    );
  });

  it("welcomes members in general without mentioning the honeypot", () => {
    const text = generalWelcomeContent("<@123>");
    assert.match(text, /Welcome <@123>/);
    assert.match(text, /Chat here/);
    assert.doesNotMatch(text, /silence-enforced/);
  });
});

describe("github credit", () => {
  const { normalizeLogin, parseLoginsFromText, feedSlug } = require("../src/github");

  it("accepts real GitHub usernames and rejects bots", () => {
    assert.equal(normalizeLogin("Co2Noss"), "Co2Noss");
    assert.equal(normalizeLogin("@octocat"), "octocat");
    assert.equal(normalizeLogin("dependabot[bot]"), null);
    assert.equal(normalizeLogin("not valid"), null);
    assert.equal(normalizeLogin("the"), null);
  });

  it("pulls authors out of GitHub webhook text", () => {
    const logins = parseLoginsFromText("Pull request opened by WidgetDev\n1 new commit by Co2Noss");
    assert.ok(logins.includes("widgetdev"));
    assert.ok(logins.includes("co2noss"));
    assert.ok(!logins.includes("new"));
  });

  it("strips channel icons when matching GitHub feeds", () => {
    assert.equal(feedSlug("📝git-commits"), "git-commits");
    assert.equal(feedSlug("🐛github-issues"), "github-issues");
    assert.equal(feedSlug("github-actions"), "github-actions");
    assert.equal(feedSlug("🛠️ Staff"), "staff");
    assert.equal(feedSlug("👋welcome"), "welcome");
  });
});

describe("github feeds", () => {
  const { formatCommit, formatRelease, formatIssue, isPullRequest, resolveHookRecord } = require("../src/feeds");

  it("formats a commit, release, and issue", () => {
    const commit = formatCommit({
      sha: "abcdef123456",
      html_url: "https://github.com/Co2Noss/Lodestar/commit/abcdef123456",
      author: { login: "Co2Noss" },
      commit: { message: "Fix vault row\n\nmore", author: { date: "2026-08-01T00:00:00Z" } },
    });
    assert.ok(commit.embeds[0].data.description.includes("`abcdef1`"));
    const release = formatRelease({
      name: "1.5.31",
      tag_name: "v1.5.31",
      html_url: "https://github.com/Co2Noss/Lodestar/releases/tag/v1.5.31",
      body: "Bugfixes",
      author: { login: "Co2Noss" },
      published_at: "2026-08-01T00:00:00Z",
    });
    assert.equal(release.embeds[0].data.title, "1.5.31");
    const issue = formatIssue({
      number: 12,
      title: "Gold plan empty",
      html_url: "https://github.com/Co2Noss/Lodestar/issues/12",
      state: "open",
      user: { login: "someone" },
      updated_at: "2026-08-01T00:00:00Z",
    });
    assert.ok(issue.embeds[0].data.title.includes("#12"));
    assert.match(issue.embeds[0].data.author.name, /issue/);
    assert.doesNotMatch(issue.embeds[0].data.author.name, /pull request/);
  });

  it("treats GitHub pull requests as not issues", () => {
    assert.equal(isPullRequest({ number: 1 }), false);
    assert.equal(isPullRequest({ number: 2, pull_request: { url: "https://api.github.com/repos/x/y/pulls/2" } }), true);
    const items = [
      { number: 1, updated_at: "2026-08-01T00:00:00Z" },
      { number: 2, pull_request: {}, updated_at: "2026-08-01T01:00:00Z" },
    ];
    const issues = items.filter((i) => !isPullRequest(i));
    assert.deepEqual(issues.map((i) => i.number), [1]);
  });

  it("reads issue webhooks stored under github or github-issues", () => {
    const storedAsGithub = { github: { id: "1", token: "t" } };
    const storedAsIssues = { "github-issues": { id: "2", token: "u" } };
    assert.equal(resolveHookRecord(storedAsGithub, "github-issues").id, "1");
    assert.equal(resolveHookRecord(storedAsIssues, "github-issues").id, "2");
    assert.equal(resolveHookRecord({}, "git-commits"), null);
  });
});
