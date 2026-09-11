import { test } from "node:test";
import assert from "node:assert/strict";
import { planWaves } from "../planner.mjs";
import { globsOverlap, matchesAny } from "../util.mjs";

const T = (id, allowed, deps = [], priority = "P1") => ({ id, allowed_files: allowed, dependencies: deps, priority });

test("independent tasks run in one wave up to maxParallel", () => {
  const { waves } = planWaves([T("TASK-001", ["src/a.js"]), T("TASK-002", ["src/b.js"]), T("TASK-003", ["src/c.js"]), T("TASK-004", ["src/d.js"])], new Set(), 3);
  assert.deepEqual(waves, [["TASK-001", "TASK-002", "TASK-003"], ["TASK-004"]]);
});

test("two tasks editing the same file are serialized (conflict test)", () => {
  const { waves, conflicts } = planWaves([T("TASK-001", ["src/app.js"]), T("TASK-002", ["src/app.js"])]);
  assert.deepEqual(waves, [["TASK-001"], ["TASK-002"]]);
  assert.equal(conflicts.length, 1);
  assert.equal(conflicts[0].conflicts_with, "TASK-001");
});

test("glob overlap detection", () => {
  assert.equal(globsOverlap(["src/screens/*"], ["src/screens/Home.tsx"]), true);
  assert.equal(globsOverlap(["src/**"], ["src/lib/x.js"]), true);
  assert.equal(globsOverlap(["src/a/*"], ["src/b/*"]), false);
  assert.equal(globsOverlap(["docs/README.md"], ["docs/GUIDE.md"]), false);
  assert.equal(globsOverlap(["docs"], ["docs/GUIDE.md"]), true);
});

test("dependencies order waves", () => {
  const { waves } = planWaves([T("TASK-001", ["a"]), T("TASK-002", ["b"], ["TASK-001"]), T("TASK-003", ["c"], ["TASK-002"])]);
  assert.deepEqual(waves, [["TASK-001"], ["TASK-002"], ["TASK-003"]]);
});

test("unsatisfiable dependency reported", () => {
  const { unschedulable } = planWaves([T("TASK-001", ["a"], ["TASK-999"])]);
  assert.deepEqual(unschedulable, ["TASK-001"]);
});

test("matchesAny handles globs and directories", () => {
  assert.equal(matchesAny("src/x/y.js", ["src/**"]), true);
  assert.equal(matchesAny("src/x/y.js", ["src/*"]), false);
  assert.equal(matchesAny(".env", [".env", ".env.*"]), true);
  assert.equal(matchesAny(".env.local", [".env", ".env.*"]), true);
  assert.equal(matchesAny("docs/a.md", ["docs"]), true);
});
