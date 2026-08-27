"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { FAQS, findFaq, suggestFaq, faqChoices } = require("../src/faqs");
const { ROLE_SPECS, CATEGORY_SPECS, channelSpecs } = require("../src/setup");

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
    assert.ok(roleNames.includes("Developer"));
    assert.ok(roleNames.includes("Bot"));
    assert.ok(roleNames.includes("Moderator"));
    assert.ok(roleNames.includes("Support"));
    assert.ok(roleNames.includes("Alpha Tester"));
    assert.ok(roleNames.includes("Contributor"));
    const catNames = CATEGORY_SPECS.map((c) => c.name);
    assert.equal(new Set(catNames).size, catNames.length);
    assert.ok(catNames.includes("Alpha"));
    assert.ok(catNames.includes("📢 Dev Feeds"));
    const fakeGuild = { id: "1", features: ["COMMUNITY"], roles: { everyone: { id: "everyone" } } };
    const fakeRoles = {
      support: { id: "s" },
      moderator: { id: "m" },
      developer: { id: "d" },
      bot: { id: "b" },
      member: { id: "mem" },
      alpha: { id: "a" },
      contributor: { id: "c" },
    };
    const channels = channelSpecs(fakeGuild, fakeRoles);
    const names = channels.map((c) => c.name);
    assert.equal(new Set(names).size, names.length);
    assert.ok(names.includes("📝git-commits"));
    assert.ok(names.includes("🚀github-releases"));
    assert.ok(names.includes("🐛github-issues"));
    assert.ok(names.includes("get-help"));
    assert.ok(names.includes("faq"));
    assert.ok(names.includes("mod-log"));
    assert.ok(names.includes("silence-enforced"));
    assert.ok(names.includes("alpha-news"));
    assert.ok(names.includes("alpha-chat"));
    assert.ok(names.includes("alpha-feedback"));
    const alphaChat = channels.find((c) => c.name === "alpha-chat");
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
  });

  it("hides Tickets, Staff, and Alpha from @everyone", () => {
    assert.ok(CATEGORY_SPECS.filter((c) => c.hidden).map((c) => c.name).includes("Tickets"));
    assert.ok(CATEGORY_SPECS.filter((c) => c.hidden).map((c) => c.name).includes("Staff"));
    const alpha = CATEGORY_SPECS.find((c) => c.key === "alpha");
    assert.ok(alpha);
    assert.equal(typeof alpha.overwrites, "function");
    const fakeGuild = { roles: { everyone: { id: "everyone" } } };
    const overwrites = alpha.overwrites(fakeGuild, { alpha: { id: "a" } });
    const everyone = overwrites.find((o) => o.id === "everyone");
    assert.ok(everyone.deny && everyone.deny.length);
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
  const { accountTooNew } = require("../src/verification");

  it("rejects brand-new Discord accounts", () => {
    const fresh = { createdTimestamp: Date.now() };
    const old = { createdTimestamp: Date.now() - 2 * 60 * 60 * 1000 };
    assert.equal(accountTooNew(fresh), true);
    assert.equal(accountTooNew(old), false);
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
  });
});
