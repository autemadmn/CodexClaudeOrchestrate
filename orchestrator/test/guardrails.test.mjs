import { test } from "node:test";
import assert from "node:assert/strict";
import { classifyTask, checkChangedFiles } from "../guardrails.mjs";
import { validate } from "../validate.mjs";
import { readJson, ROOT } from "../util.mjs";
import path from "node:path";

const guardrails = readJson(path.join(ROOT, ".ai", "config.json")).guardrails;
const task = (over) => ({ title: "t", description: "normal implementation", allowed_files: ["src/a.js"], approval_category: "AUTO_APPROVED", ...over });

test("normal task stays AUTO_APPROVED", () => {
  assert.equal(classifyTask(task({}), guardrails).category, "AUTO_APPROVED");
});

test("new dependency requires brain approval (escalation test)", () => {
  assert.equal(classifyTask(task({ allowed_files: ["package.json"] }), guardrails).category, "REQUIRES_BRAIN_APPROVAL");
  assert.equal(classifyTask(task({ description: "add dependency lodash" }), guardrails).category, "REQUIRES_BRAIN_APPROVAL");
  assert.equal(classifyTask(task({ allowed_files: ["db/migrations/001.sql"] }), guardrails).category, "REQUIRES_BRAIN_APPROVAL");
});

test("billing / production / secrets require human approval", () => {
  assert.equal(classifyTask(task({ allowed_files: ["src/billing/charge.js"] }), guardrails).category, "REQUIRES_HUMAN_APPROVAL");
  assert.equal(classifyTask(task({ description: "rotate the production secret" }), guardrails).category, "REQUIRES_HUMAN_APPROVAL");
  assert.equal(classifyTask(task({ allowed_files: [".github/workflows/deploy.yml"] }), guardrails).category, "REQUIRES_HUMAN_APPROVAL");
});

test("category never lowered below manager declaration", () => {
  assert.equal(classifyTask(task({ approval_category: "REQUIRES_HUMAN_APPROVAL" }), guardrails).category, "REQUIRES_HUMAN_APPROVAL");
});

test("changed files outside allowed_files or forbidden are detected", () => {
  const r = checkChangedFiles(["src/a.js", "src/b.js", ".env"], task({}), guardrails);
  assert.equal(r.ok, false);
  assert.deepEqual(r.violations, ["src/b.js"]);
  assert.deepEqual(r.forbidden, [".env"]);
  assert.equal(checkChangedFiles(["src/a.js"], task({}), guardrails).ok, true);
});

test("schema validator catches missing/enum/extra", () => {
  const schema = readJson(path.join(ROOT, ".ai", "schemas", "review.schema.json"));
  assert.equal(validate(schema, { task_id: "TASK-001", decision: "approve", issues: [], required_changes: [], summary: "ok" }).length, 0);
  assert.ok(validate(schema, { task_id: "TASK-001", decision: "maybe", issues: [], required_changes: [], summary: "ok" }).length > 0);
  assert.ok(validate(schema, { task_id: "TASK-001", decision: "approve", issues: [], summary: "ok" }).length > 0);
  assert.ok(validate(schema, { task_id: "TASK-001", decision: "approve", issues: [], required_changes: [], summary: "ok", extra: 1 }).length > 0);
});
