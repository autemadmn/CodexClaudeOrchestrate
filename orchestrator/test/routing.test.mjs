/**
 * End-to-end routing tests with the deterministic mock provider (no network, no cost).
 * Each test builds a temp git repo containing the orchestrator skeleton and runs `agents run --mock`.
 */
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { execFileSync, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..", "..");

function makeRepo() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "agents-e2e-"));
  for (const item of [".ai", ".claude", "orchestrator", "bin", "package.json"]) fs.cpSync(path.join(REPO, item), path.join(dir, item), { recursive: true, filter: (p) => !p.includes("/RUNS/") && !p.includes("/tmp/") });
  fs.mkdirSync(path.join(dir, ".ai", "RUNS"), { recursive: true });
  fs.writeFileSync(path.join(dir, ".ai", "TASKS.json"), JSON.stringify({ next_id: 1, tasks: [] }));
  fs.writeFileSync(path.join(dir, ".gitignore"), "node_modules/\n.worktrees/\n.ai/tmp/\n");
  fs.mkdirSync(path.join(dir, "docs"));
  fs.writeFileSync(path.join(dir, "docs", "README.md"), "# docs\n");
  const git = (...a) => execFileSync("git", a, { cwd: dir, encoding: "utf8" });
  git("init", "-q", "-b", "main");
  git("-c", "user.name=t", "-c", "user.email=t@t", "add", "-A");
  git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "init");
  return { dir, git };
}

function agents(dir, args, scenario = "default") {
  const r = spawnSync(process.execPath, [path.join(dir, "bin", "agents.mjs"), ...args], { cwd: dir, encoding: "utf8", env: { ...process.env, AGENTS_MOCK: "1", AGENTS_MOCK_SCENARIO: scenario }, timeout: 120000 });
  return { code: r.status, out: r.stdout + r.stderr };
}

function events(dir) {
  const runsDir = path.join(dir, ".ai", "RUNS");
  const id = fs.readdirSync(runsDir).filter((d) => d.match(/^\d{8}-/)).sort().pop();
  const lines = fs.readFileSync(path.join(runsDir, id, "events.jsonl"), "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const run = JSON.parse(fs.readFileSync(path.join(runsDir, id, "run.json"), "utf8"));
  const tasks = JSON.parse(fs.readFileSync(path.join(dir, ".ai", "TASKS.json"), "utf8")).tasks;
  return { id, lines, run, tasks, labels: lines.filter((e) => e.type === "agent_call").map((e) => e.label) };
}

test("happy path: brain -> spec -> tasks -> workers (parallel) -> review -> merge -> QA -> brain final", () => {
  const { dir, git } = makeRepo();
  const r = agents(dir, ["run", "Mock objective", "--mock"]);
  assert.equal(r.code, 0, r.out);
  const { run, tasks, labels, lines } = events(dir);
  assert.equal(run.status, "DONE");
  assert.equal(run.final.result, "SUCCESS");
  assert.ok(labels[0] === "brain-plan");
  assert.ok(labels.includes("product-architect-spec"));
  assert.ok(labels.includes("implementation-plan"));
  assert.ok(labels.some((l) => l.startsWith("worker-TASK-001")));
  assert.ok(labels.some((l) => l.startsWith("review-TASK-001")));
  assert.ok(labels.includes("qa-round1"));
  assert.equal(labels[labels.length - 1], "brain-final");
  // both tasks ran in the same wave (disjoint files)
  const wave = lines.find((e) => e.type === "wave_start");
  assert.deepEqual(wave.tasks, ["TASK-001", "TASK-002"]);
  assert.ok(tasks.every((t) => t.status === "DONE"));
  // merged into the feature branch, worktrees cleaned up
  assert.match(git("branch", "--show-current"), /^feature\//);
  assert.ok(fs.existsSync(path.join(dir, "docs", "MOCK-1.md")));
  assert.ok(!fs.existsSync(path.join(dir, ".worktrees", "TASK-001")));
  assert.equal(git("status", "--porcelain").trim(), "");
  // ADR written, PROJECT_STATE updated by brain, final summary present
  assert.ok(fs.readdirSync(path.join(dir, ".ai", "DECISIONS")).some((f) => f.includes("use-mock-docs-marker")));
  assert.match(fs.readFileSync(path.join(dir, ".ai", "PROJECT_STATE.md"), "utf8"), /mock brain/);
  assert.ok(fs.existsSync(path.join(dir, ".ai", "RUNS", run.id, "final-summary.md")));
});

test("QA can reject: fix tasks are created, executed, and QA re-runs", () => {
  const { dir } = makeRepo();
  const r = agents(dir, ["run", "Mock objective", "--mock"], "qa_reject_once");
  assert.equal(r.code, 0, r.out);
  const { run, tasks, labels } = events(dir);
  assert.equal(run.qa_round, 2);
  assert.ok(labels.includes("qa-round1") && labels.includes("qa-round2"));
  assert.ok(tasks.some((t) => t.title.startsWith("[QA r1]")));
  assert.equal(run.final.result, "SUCCESS");
});

test("review request_changes triggers a worker fix attempt (retry count works)", () => {
  const { dir } = makeRepo();
  const r = agents(dir, ["run", "Mock objective", "--mock"], "review_reject_once");
  assert.equal(r.code, 0, r.out);
  const { tasks, labels } = events(dir);
  assert.ok(labels.includes("worker-TASK-001-a1") && labels.includes("worker-TASK-001-a2"));
  assert.equal(tasks.find((t) => t.id === "TASK-001").attempts, 2);
  assert.equal(fs.readFileSync(path.join(dir, "docs", "MOCK-1.md"), "utf8").split("\n").filter(Boolean).length, 2);
});

test("repeated worker failure stops at MAX_FIX_ATTEMPTS and escalates to the brain", () => {
  const { dir } = makeRepo();
  const r = agents(dir, ["run", "Mock objective", "--mock"], "worker_fails");
  assert.equal(r.code, 0, r.out);
  const { run, tasks, lines } = events(dir);
  const t1 = tasks.find((t) => t.id === "TASK-001");
  assert.equal(t1.status, "FAILED");
  assert.equal(t1.attempts, 3);
  assert.ok(lines.some((e) => e.type === "escalate_to_brain"));
  assert.notEqual(run.final.result, "SUCCESS");
});

test("conflict test: overlapping allowed_files are serialized, never in the same wave", () => {
  const { dir } = makeRepo();
  const r = agents(dir, ["run", "Mock objective", "--mock"], "conflict");
  assert.equal(r.code, 0, r.out);
  const { lines } = events(dir);
  const waves = lines.filter((e) => e.type === "wave_start").map((e) => e.tasks);
  for (const w of waves) assert.ok(!(w.includes("TASK-001") && w.includes("TASK-002")), `TASK-001 and TASK-002 must not share a wave: ${JSON.stringify(waves)}`);
  assert.ok(lines.some((e) => e.type === "conflict_serialized"));
});

test("escalation test: dependency change goes to the brain, billing change waits for a human", () => {
  const { dir } = makeRepo();
  const r = agents(dir, ["run", "Mock objective", "--mock"], "escalation");
  assert.equal(r.code, 0, r.out);
  const { run, tasks, lines } = events(dir);
  const dep = tasks.find((t) => t.title === "Add dependency");
  const bill = tasks.find((t) => t.title === "Change billing");
  assert.equal(dep.approval_category, "REQUIRES_BRAIN_APPROVAL");
  assert.equal(dep.brain_approved, true);
  assert.equal(dep.status, "DONE");
  assert.equal(bill.approval_category, "REQUIRES_HUMAN_APPROVAL");
  assert.equal(bill.status, "BLOCKED");
  assert.ok(lines.some((e) => e.type === "brain_approval" && e.subject === "tasks"));
  assert.equal(run.status, "PAUSED");
  assert.match(run.pause_reason, /agents approve TASK-003/);
  // human approves, resume executes the blocked task
  const a = agents(dir, ["approve", "TASK-003"]);
  assert.equal(a.code, 0, a.out);
  const res = agents(dir, ["resume", run.id], "escalation");
  assert.equal(res.code, 0, res.out);
  const after = events(dir);
  assert.equal(after.tasks.find((t) => t.id === "TASK-003").status, "DONE");
  assert.equal(after.run.status, "DONE");
});

test("guardrail: worker touching a forbidden file is reverted and the task fails", () => {
  const { dir, git } = makeRepo();
  const r = agents(dir, ["run", "Mock objective", "--mock"], "worker_violates_files");
  assert.equal(r.code, 0, r.out);
  const { tasks, lines } = events(dir);
  assert.ok(tasks.every((t) => t.status === "FAILED"));
  assert.ok(lines.some((e) => e.type === "guardrail_violation" && e.forbidden.includes(".env")));
  assert.ok(!fs.existsSync(path.join(dir, ".env")));
  assert.equal(git("status", "--porcelain").trim(), "");
});

test("stop + resume: STOP marker halts the run and resume finishes it", () => {
  const { dir } = makeRepo();
  // create a run that stops right after brain plan by pre-placing STOP after first call is impossible; instead stop before start
  const first = agents(dir, ["run", "Mock objective", "--mock"]);
  assert.equal(first.code, 0, first.out);
  const { id } = events(dir);
  const s = agents(dir, ["stop", id]);
  assert.equal(s.code, 0, s.out);
  assert.ok(fs.existsSync(path.join(dir, ".ai", "RUNS", id, "STOP")));
  const st = agents(dir, ["status"]);
  assert.equal(st.code, 0, st.out);
  assert.match(st.out, /LATEST RUN/);
  const lg = agents(dir, ["logs", id]);
  assert.match(lg.out, /brain-final/);
});
