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
    const catNames = CATEGORY_SPECS.map((c) => c.name);
    assert.equal(new Set(catNames).size, catNames.length);
    const fakeGuild = { id: "1", features: ["COMMUNITY"], roles: { everyone: { id: "everyone" } } };
    const fakeRoles = { support: { id: "s" }, moderator: { id: "m" } };
    const channels = channelSpecs(fakeGuild, fakeRoles);
    const names = channels.map((c) => c.name);
    assert.equal(new Set(names).size, names.length);
    assert.ok(names.includes("git-commits"));
    assert.ok(names.includes("get-help"));
    assert.ok(names.includes("faq"));
  });

  it("hides Tickets and Staff from @everyone", () => {
    assert.ok(CATEGORY_SPECS.filter((c) => c.hidden).map((c) => c.name).includes("Tickets"));
    assert.ok(CATEGORY_SPECS.filter((c) => c.hidden).map((c) => c.name).includes("Staff"));
  });
});
