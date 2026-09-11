import fs from "node:fs";
import path from "node:path";
import { execFile } from "node:child_process";
import { ROOT, AI_DIR, RUNS_DIR, readJson, writeJson, writeText, readText, appendJsonl, nowIso, runId as makeRunId, slugify, truncate, log } from "./util.mjs";
import { resolveModels } from "./config.mjs";
import { callAgent, killActiveChildren } from "./providers.mjs";
import { loadTasks, saveTasks, newTask, setStatus, tasksForRun, resolveDependencyRefs } from "./tasks.mjs";
import { planWaves } from "./planner.mjs";
import { classifyTask, checkChangedFiles } from "./guardrails.mjs";
import * as g from "./git.mjs";
import { roleSystemPrompt, projectContext, brainPlanPrompt, specPrompt, tasksPlanPrompt, workerPrompt, reviewPrompt, qaPrompt, brainFinalPrompt, approvalPrompt } from "./roles.mjs";

export class StopRequested extends Error {}
export class RunPaused extends Error {
  constructor(reason) {
    super(reason);
    this.paused = true;
  }
}

export function runDir(id) {
  return path.join(RUNS_DIR, id);
}

export function loadRun(id) {
  return readJson(path.join(runDir(id), "run.json"));
}

export function saveRun(run) {
  run.updated_at = nowIso();
  writeJson(path.join(runDir(run.id), "run.json"), run);
}

export function latestRunId() {
  if (!fs.existsSync(RUNS_DIR)) return null;
  const ids = fs.readdirSync(RUNS_DIR).filter((d) => fs.existsSync(path.join(RUNS_DIR, d, "run.json"))).sort();
  return ids[ids.length - 1] || null;
}

function event(run, type, data = {}) {
  appendJsonl(path.join(runDir(run.id), "events.jsonl"), { ts: nowIso(), type, ...data });
}

function checkStop(run) {
  if (fs.existsSync(path.join(runDir(run.id), "STOP"))) throw new StopRequested("STOP file present");
}

function addCost(run, meta) {
  if (typeof meta?.cost_usd === "number") run.cost_usd = Number(((run.cost_usd || 0) + meta.cost_usd).toFixed(4));
  if (run.cost_usd > run.limits.MAX_BUDGET_USD_PER_RUN) throw new RunPaused(`budget exceeded: $${run.cost_usd} > MAX_BUDGET_USD_PER_RUN=${run.limits.MAX_BUDGET_USD_PER_RUN}`);
}

async function agent(run, { label, role, roleKey, prompt, schemaName, cwd = ROOT, policy = "none", opts = {} }) {
  checkStop(run);
  const cfg = run.models.roles[roleKey];
  log(`${label}: ${roleKey} -> ${cfg.provider}/${cfg.model} (${cfg.reasoning})`);
  const res = await callAgent({ label, role, cfg, system: roleSystemPrompt(role), prompt, schemaName, cwd, policy, timeoutMs: run.limits.CALL_TIMEOUT_MS, runDir: runDir(run.id), opts });
  addCost(run, res.meta);
  saveRun(run);
  return res.output;
}

function runCommand(cmd, cwd, timeoutMs = 600000) {
  return new Promise((resolve) => {
    execFile("bash", ["-lc", cmd], { cwd, timeout: timeoutMs, maxBuffer: 16 * 1024 * 1024, env: { ...process.env, CI: "1" } }, (err, stdout, stderr) => {
      resolve({ cmd, code: err ? (typeof err.code === "number" ? err.code : 1) : 0, output: `${stdout}\n${stderr}`.trim(), timedOut: !!(err && err.killed) });
    });
  });
}

async function runTestCommands(cmds, cwd) {
  const results = [];
  for (const cmd of cmds) results.push(await runCommand(cmd, cwd));
  const allPassed = results.every((r) => r.code === 0);
  const report = results.length
    ? results.map((r) => `$ ${r.cmd}\nexit=${r.code}${r.timedOut ? " (timeout)" : ""}\n${truncate(r.output, 4000)}`).join("\n\n")
    : "(no test commands defined)";
  return { allPassed, report, results };
}

// ---------- run creation ----------

export function createRun(objective, opts = {}) {
  const models = resolveModels(undefined, { mock: opts.mock });
  const id = makeRunId();
  const run = {
    id,
    objective,
    status: "RUNNING",
    phase: "brain_plan",
    created_at: nowIso(),
    base_branch: null,
    feature_branch: null,
    in_place: opts.inPlace ?? models.git.in_place,
    models,
    limits: models.limits,
    cost_usd: 0,
    qa_round: 0,
    human_approved: false,
    pause_reason: null,
    pid: process.pid,
  };
  fs.mkdirSync(runDir(id), { recursive: true });
  writeJson(path.join(runDir(id), "input.json"), { objective, created_at: run.created_at, models: models.roles, limits: models.limits });
  saveRun(run);
  event(run, "run_created", { objective });
  return run;
}

function ensureGit(run) {
  if (!g.hasCommits()) throw new Error("Repository has no commits yet. Make an initial commit first.");
  if (!run.base_branch) {
    run.base_branch = g.currentBranch();
    if (!run.in_place) {
      run.feature_branch = `${run.models.git.feature_branch_prefix}${slugify(run.objective)}-${run.id.slice(-6)}`;
      if (!g.isClean()) throw new Error("Working tree is not clean. Commit or stash your changes before `agents run` (or use --in-place with a clean tree).");
      g.createBranchFromHead(run.feature_branch);
      log(`created branch ${run.feature_branch} from ${run.base_branch}`);
    } else {
      run.feature_branch = run.base_branch;
    }
    run.base_commit = g.git(["rev-parse", "HEAD"]);
    saveRun(run);
    event(run, "git_setup", { base_branch: run.base_branch, feature_branch: run.feature_branch });
  } else if (g.currentBranch() !== run.feature_branch) {
    g.checkout(run.feature_branch);
  }
}

// ---------- phases ----------

async function phaseBrainPlan(run) {
  const ctx = projectContext();
  const lastId = latestRunIdBefore(run.id);
  const lastRun = lastId ? readText(path.join(runDir(lastId), "final-summary.md")).slice(0, 2000) : "";
  const plan = await agent(run, { label: "brain-plan", role: "brain", roleKey: "brain", prompt: brainPlanPrompt({ objective: run.objective, ctx, limits: run.limits, lastRun }), schemaName: "brain_plan" });
  writeJson(path.join(runDir(run.id), "plan.json"), plan);
  run.plan = plan;
  if (!plan.proceed) {
    run.pause_reason = `Brain needs answers from you:\n${plan.questions_for_human.map((q) => `  - ${q}`).join("\n")}\nAnswer by re-running: agents run "<objective + answers>"`;
    run.status = "BLOCKED";
    saveRun(run);
    throw new RunPaused(run.pause_reason);
  }
  run.phase = "spec";
  saveRun(run);
}

function latestRunIdBefore(id) {
  if (!fs.existsSync(RUNS_DIR)) return null;
  return fs.readdirSync(RUNS_DIR).filter((d) => d < id && fs.existsSync(path.join(RUNS_DIR, d, "final-summary.md"))).sort().pop() || null;
}

function nextDecisionNumber() {
  const dir = path.join(AI_DIR, "DECISIONS");
  fs.mkdirSync(dir, { recursive: true });
  const nums = fs.readdirSync(dir).map((f) => Number((f.match(/^DEC-(\d+)/) || [])[1] || 0));
  return Math.max(0, ...nums) + 1;
}

async function phaseSpec(run) {
  const ctx = projectContext();
  const spec = await agent(run, { label: "product-architect-spec", role: "product-architect-manager", roleKey: "manager", prompt: specPrompt({ objective: run.objective, plan: run.plan, ctx, overview: g.repoOverview() }), schemaName: "spec", policy: "readonly" });
  writeJson(path.join(runDir(run.id), "spec.json"), spec);
  writeText(path.join(runDir(run.id), "spec.md"), `# ${spec.feature_name}\n\n${spec.feature_spec_md}\n\n## Acceptance criteria\n${spec.acceptance_criteria.map((c) => `- ${c}`).join("\n")}\n`);
  run.spec = spec;
  const written = [];
  for (const d of spec.decisions || []) {
    const n = nextDecisionNumber();
    const id = `DEC-${String(n).padStart(3, "0")}`;
    const file = path.join(AI_DIR, "DECISIONS", `${id}-${slugify(d.title, 50)}.md`);
    writeText(file, `# ${id} ${d.title}\n\n## Context\n${d.context}\n\n## Decision\n${d.decision}\n\n## Reason\n${d.reason}\n\n## Alternatives\n${d.alternatives.map((a) => `- ${a}`).join("\n") || "- (none)"}\n\n## Consequences\n${d.consequences}\n\n_Recorded by product-architect-manager in run ${run.id}._\n`);
    written.push(path.relative(ROOT, file));
  }
  run.decisions_written = written;
  event(run, "spec_written", { decisions: written, needs_brain_decision: spec.needs_brain_decision, requires_human_approval: spec.requires_human_approval });
  if (spec.requires_human_approval && !run.human_approved) {
    run.pause_reason = `The spec requires HUMAN approval:\n${spec.human_approval_reasons.map((r) => `  - ${r}`).join("\n")}\nIf you agree, run: agents approve ${run.id}   then: agents resume ${run.id}`;
    run.status = "PAUSED";
    saveRun(run);
    throw new RunPaused(run.pause_reason);
  }
  if (spec.needs_brain_decision?.length) {
    const ok = await brainApproval(run, "Spec-level decisions requested by product-architect-manager", spec.needs_brain_decision.map((x) => `- ${x}`).join("\n"));
    if (!ok) throw new RunPaused(run.pause_reason);
  }
  run.phase = "tasks";
  saveRun(run);
}

async function brainApproval(run, subject, details) {
  const ctx = projectContext();
  const decision = await agent(run, { label: `brain-approval-${slugify(subject, 30)}`, role: "brain", roleKey: "brain", prompt: approvalPrompt({ subject, details, ctx }), schemaName: "approval" });
  event(run, "brain_approval", { subject, decision: decision.decision, reason: decision.reason });
  run.approvals = [...(run.approvals || []), { subject, ...decision }];
  if (decision.decision === "approve") return true;
  run.status = decision.decision === "escalate_to_human" ? "PAUSED" : "BLOCKED";
  run.pause_reason = `Brain ${decision.decision} for "${subject}": ${decision.reason}` + (decision.decision === "escalate_to_human" ? `\nIf you approve, run: agents approve ${run.id}   then: agents resume ${run.id}` : "");
  saveRun(run);
  return false;
}

async function phaseTasks(run) {
  const ctx = projectContext();
  const plan = await agent(run, { label: "implementation-plan", role: "implementation-manager", roleKey: "manager", prompt: tasksPlanPrompt({ spec: run.spec, overview: g.repoOverview(), limits: run.limits, ctx }), schemaName: "tasks_plan", policy: "readonly" });
  writeJson(path.join(runDir(run.id), "tasks-plan.json"), plan);
  if (plan.needs_escalation) {
    run.status = "BLOCKED";
    run.pause_reason = `Implementation manager escalated: ${plan.escalation_reason}`;
    saveRun(run);
    throw new RunPaused(run.pause_reason);
  }
  if (plan.tasks.length > run.limits.MAX_TASKS_PER_RUN) {
    log(`plan has ${plan.tasks.length} tasks; keeping the first ${run.limits.MAX_TASKS_PER_RUN} (MAX_TASKS_PER_RUN)`);
    plan.tasks = plan.tasks.slice(0, run.limits.MAX_TASKS_PER_RUN);
  }
  const store = loadTasks();
  const created = plan.tasks.map((t) => newTask(store, { ...t, run_id: run.id }));
  resolveDependencyRefs(plan.tasks, created);
  await applyApprovals(run, store, created);
  saveTasks(store);
  writeJson(path.join(runDir(run.id), "tasks.json"), created);
  run.task_ids = created.map((t) => t.id);
  run.phase = "execute";
  saveRun(run);
  event(run, "tasks_created", { ids: run.task_ids });
}

/** Deterministic guardrail classification + brain/human approval gating. */
async function applyApprovals(run, store, tasks) {
  const needBrain = [];
  for (const t of tasks) {
    const { category, reasons } = classifyTask(t, run.models.guardrails);
    t.approval_category = category;
    if (category === "REQUIRES_HUMAN_APPROVAL" && !t.human_approved) {
      setStatus(t, "BLOCKED", `REQUIRES_HUMAN_APPROVAL: ${reasons.join("; ") || "declared by manager"}. Approve with: agents approve ${t.id}`);
    } else if (category === "REQUIRES_BRAIN_APPROVAL" && !t.brain_approved) {
      needBrain.push({ t, reasons });
    } else {
      setStatus(t, "READY");
    }
  }
  if (needBrain.length) {
    saveTasks(store);
    const details = needBrain.map(({ t, reasons }) => `- ${t.id} "${t.title}": ${t.description}\n  files: ${t.allowed_files.join(", ")}\n  reasons: ${reasons.join("; ") || "declared by manager"}`).join("\n");
    const ctx = projectContext();
    const decision = await agent(run, { label: "brain-approval-tasks", role: "brain", roleKey: "brain", prompt: approvalPrompt({ subject: "Tasks requiring Brain approval", details, ctx }), schemaName: "approval" });
    event(run, "brain_approval", { subject: "tasks", decision: decision.decision, reason: decision.reason, tasks: needBrain.map((x) => x.t.id) });
    for (const { t } of needBrain) {
      if (decision.decision === "approve") {
        t.brain_approved = true;
        setStatus(t, "READY");
      } else if (decision.decision === "escalate_to_human") {
        setStatus(t, "BLOCKED", `Brain escalated to human: ${decision.reason}. Approve with: agents approve ${t.id}`);
      } else {
        setStatus(t, "FAILED", `Brain rejected: ${decision.reason}`);
      }
    }
  }
  const blocked = tasks.filter((t) => t.status === "BLOCKED");
  if (blocked.length) {
    run.human_pending = blocked.map((t) => t.id);
    saveRun(run);
  }
}

async function executeTask(run, task, store, spec) {
  const wtDir = path.join(ROOT, run.models.git.worktrees_dir, task.id);
  const branch = `${run.models.git.task_branch_prefix}${task.id}`;
  if (!fs.existsSync(wtDir)) {
    g.addWorktree(wtDir, branch, run.feature_branch);
  }
  task.worktree = path.relative(ROOT, wtDir);
  task.branch = branch;
  task.assigned_worker = `${run.models.roles.worker.provider}/${run.models.roles.worker.model}`;
  setStatus(task, "IN_PROGRESS");
  saveTasks(store);
  let requiredChanges = [];
  while (true) {
    task.attempts += 1;
    saveTasks(store);
    event(run, "worker_start", { task: task.id, attempt: task.attempts });
    let result;
    try {
      result = await agent(run, { label: `worker-${task.id}-a${task.attempts}`, role: "worker", roleKey: "worker", prompt: workerPrompt({ task, spec, limits: run.limits, requiredChanges, attempt: task.attempts }), schemaName: "worker_result", cwd: wtDir, policy: "worker", opts: { testCommands: task.test_commands } });
    } catch (err) {
      if (err instanceof StopRequested || err.paused) throw err;
      result = { task_id: task.id, status: "failed", files_changed: [], tests_run: [], tests_passed: false, issues: [`worker call failed: ${err.message}`], summary: "worker call failed", needs_escalation: true, escalation_reason: err.message };
    }
    task.result = result;
    const changed = g.changedFiles(wtDir);
    const guard = checkChangedFiles(changed, task, run.models.guardrails);
    if (!guard.ok) {
      g.tryGit(["checkout", "--", "."], { cwd: wtDir });
      g.tryGit(["clean", "-fdq"], { cwd: wtDir });
      setStatus(task, "FAILED", `guardrail: worker changed files outside allowed_files (${guard.violations.join(", ")})${guard.forbidden.length ? `; FORBIDDEN paths: ${guard.forbidden.join(", ")}` : ""}. Changes reverted; escalated.`);
      event(run, "guardrail_violation", { task: task.id, violations: guard.violations, forbidden: guard.forbidden });
      saveTasks(store);
      return;
    }
    const commit = g.commitAll(wtDir, `${task.id}: ${task.title} (attempt ${task.attempts})`);
    if (result.needs_escalation || result.status === "blocked") {
      setStatus(task, "BLOCKED", `worker escalated: ${result.escalation_reason || result.summary}`);
      event(run, "worker_escalation", { task: task.id, reason: result.escalation_reason });
      saveTasks(store);
      return;
    }
    const tests = await runTestCommands(task.test_commands, wtDir);
    writeText(path.join(runDir(run.id), `tests-${task.id}-a${task.attempts}.txt`), tests.report);
    const diff = g.diffBetween(run.feature_branch, branch);
    setStatus(task, "REVIEW");
    task.review_status = "pending";
    saveTasks(store);
    let review;
    if (!commit && !changed.length && result.status !== "completed") {
      review = { task_id: task.id, decision: "request_changes", issues: ["worker produced no changes"], required_changes: ["Implement the task; no files were changed."], summary: "no changes" };
    } else {
      review = await agent(run, { label: `review-${task.id}-a${task.attempts}`, role: "implementation-manager", roleKey: "manager", prompt: reviewPrompt({ task, workerResult: result, testReport: `${tests.allPassed ? "ALL TEST COMMANDS PASSED" : "SOME TEST COMMANDS FAILED"}\n\n${tests.report}`, diff, spec, limits: run.limits }), schemaName: "review", cwd: wtDir, policy: "readonly" });
    }
    if (review.decision === "approve" && !tests.allPassed) {
      review.decision = "request_changes";
      review.required_changes = [...review.required_changes, "Test commands must pass (orchestrator verified failure)."];
    }
    task.review_status = review.decision;
    task.review = review;
    event(run, "review", { task: task.id, attempt: task.attempts, decision: review.decision, tests_passed: tests.allPassed });
    if (review.decision === "approve") {
      saveTasks(store);
      return;
    }
    if (review.decision === "reject") {
      setStatus(task, "FAILED", `review rejected: ${review.summary}`);
      saveTasks(store);
      return;
    }
    if (task.attempts >= run.limits.MAX_FIX_ATTEMPTS) {
      setStatus(task, "FAILED", `MAX_FIX_ATTEMPTS (${run.limits.MAX_FIX_ATTEMPTS}) reached; escalated to Brain. Last issues: ${review.issues.join("; ")}`);
      event(run, "escalate_to_brain", { task: task.id, reason: "max_fix_attempts" });
      saveTasks(store);
      return;
    }
    requiredChanges = review.required_changes.length ? review.required_changes : review.issues;
    setStatus(task, "IN_PROGRESS");
    saveTasks(store);
  }
}

function mergeTask(run, task, store) {
  const wtDir = path.join(ROOT, task.worktree);
  const merge = g.mergeBranch(task.branch, `Merge ${task.id}: ${task.title}`);
  if (merge.ok) {
    setStatus(task, "DONE");
    g.removeWorktree(wtDir, task.branch);
    task.worktree = null;
    event(run, "merged", { task: task.id });
    saveTasks(store);
    return true;
  }
  event(run, "merge_failed", { task: task.id, conflict: merge.conflict, out: merge.out.slice(0, 500) });
  g.removeWorktree(wtDir, task.branch);
  task.worktree = null;
  task.branch = null;
  if (merge.conflict && task.attempts < run.limits.MAX_FIX_ATTEMPTS) {
    // Implementation manager policy: serialize — re-run the task on top of the new HEAD.
    setStatus(task, "READY", `merge conflict on attempt ${task.attempts}; re-running on updated branch`);
    task.review_status = null;
  } else {
    setStatus(task, "FAILED", `merge failed: ${merge.out.slice(0, 200)}`);
  }
  saveTasks(store);
  return false;
}

async function phaseExecute(run) {
  const store = loadTasks();
  const spec = run.spec;
  let guardIterations = 0;
  while (true) {
    checkStop(run);
    if (++guardIterations > 50) throw new Error("execute phase: too many iterations");
    const mine = tasksForRun(store, run.id);
    const done = new Set(mine.filter((t) => t.status === "DONE").map((t) => t.id));
    const pending = mine.filter((t) => ["READY", "BACKLOG"].includes(t.status));
    if (!pending.length) break;
    const terminal = new Set(mine.filter((t) => ["FAILED", "BLOCKED"].includes(t.status)).map((t) => t.id));
    // tasks depending on failed/blocked tasks cannot run
    for (const t of pending) if (t.dependencies.some((d) => terminal.has(d))) setStatus(t, "BLOCKED", `dependency ${t.dependencies.find((d) => terminal.has(d))} failed or blocked`);
    const schedulable = pending.filter((t) => t.status !== "BLOCKED");
    if (!schedulable.length) break;
    const { waves, conflicts, unschedulable } = planWaves(schedulable, done, run.limits.MAX_PARALLEL_WORKERS);
    for (const c of conflicts) event(run, "conflict_serialized", c);
    for (const id of unschedulable) setStatus(store.tasks.find((t) => t.id === id), "BLOCKED", "unsatisfiable dependencies");
    saveTasks(store);
    const wave = waves[0] || [];
    if (!wave.length) break;
    log(`wave: ${wave.join(", ")}`);
    event(run, "wave_start", { tasks: wave });
    const tasks = wave.map((id) => store.tasks.find((t) => t.id === id));
    await Promise.all(tasks.map((t) => executeTask(run, t, store, spec)));
    for (const t of tasks) if (t.status === "REVIEW" && t.review_status === "approve") mergeTask(run, t, store);
    saveTasks(store);
  }
  const mine = tasksForRun(store, run.id);
  run.human_pending = mine.filter((t) => t.status === "BLOCKED" && /agents approve/.test((t.blockers || []).join(" "))).map((t) => t.id);
  run.phase = mine.some((t) => t.status === "DONE") ? "qa" : "final";
  saveRun(run);
}

async function phaseQA(run) {
  const store = loadTasks();
  const mine = tasksForRun(store, run.id);
  run.qa_round += 1;
  const cmds = [...new Set(mine.flatMap((t) => t.test_commands))];
  const tests = await runTestCommands(cmds, ROOT);
  writeText(path.join(runDir(run.id), `tests-qa-round${run.qa_round}.txt`), tests.report);
  const diff = g.diffBetween(run.base_commit, "HEAD");
  const qa = await agent(run, { label: `qa-round${run.qa_round}`, role: "qa-manager", roleKey: "manager", prompt: qaPrompt({ spec: run.spec, tasks: mine, diff, testReport: `${tests.allPassed ? "ALL TEST COMMANDS PASSED" : "SOME TEST COMMANDS FAILED"}\n\n${tests.report}`, limits: run.limits, round: run.qa_round }), schemaName: "qa_report", policy: "readonly" });
  if (qa.decision === "approve" && !tests.allPassed) {
    qa.decision = "request_changes";
    qa.required_changes.push({ title: "Make test commands pass", description: `These commands failed on the integrated branch:\n${tests.report.slice(0, 2000)}`, allowed_files: ["."], acceptance_criteria: ["all test commands exit 0"], test_commands: cmds });
  }
  writeJson(path.join(runDir(run.id), `qa-report-round${run.qa_round}.json`), qa);
  writeJson(path.join(runDir(run.id), "qa-report.json"), qa);
  run.qa = qa;
  event(run, "qa", { round: run.qa_round, decision: qa.decision });
  for (const t of mine) if (t.status === "DONE") t.qa_status = qa.decision;
  if (qa.decision === "request_changes" && run.qa_round < run.limits.MAX_FIX_ATTEMPTS && qa.required_changes.length) {
    const created = qa.required_changes.map((c) => newTask(store, { title: `[QA r${run.qa_round}] ${c.title}`, description: c.description, priority: "P1", allowed_files: c.allowed_files, acceptance_criteria: c.acceptance_criteria, test_commands: c.test_commands, run_id: run.id, parent_task: mine[0]?.id ?? null }));
    await applyApprovals(run, store, created);
    saveTasks(store);
    run.task_ids.push(...created.map((t) => t.id));
    event(run, "qa_fix_tasks", { ids: created.map((t) => t.id) });
    run.phase = "execute";
  } else {
    saveTasks(store);
    if (qa.decision === "request_changes") event(run, "escalate_to_brain", { reason: "qa max rounds" });
    run.phase = "final";
  }
  saveRun(store && run);
}

function buildManagerSummary(run, mine) {
  const completed = mine.filter((t) => t.status === "DONE");
  const failed = mine.filter((t) => ["FAILED", "BLOCKED"].includes(t.status));
  const qa = run.qa;
  const status = qa?.decision === "approve" && failed.length === 0 ? "SUCCESS" : completed.length ? "PARTIAL" : "BLOCKED";
  return {
    objective: run.objective,
    status,
    result: `${completed.length}/${mine.length} tasks merged into ${run.feature_branch}. QA: ${qa ? `${qa.decision} (round ${run.qa_round})` : "not run"}.`,
    tasks_completed: completed.length,
    tasks_failed: failed.length,
    tests: qa ? (readText(path.join(runDir(run.id), `tests-qa-round${run.qa_round}.txt`)).split("\n").filter((l) => l.startsWith("exit=")).join(", ") || "no test commands") : "not run",
    blockers: failed.map((t) => `${t.id} ${t.title}: ${(t.blockers || []).slice(-1)[0] || t.status}`),
    risks: [...(run.spec?.risks || []).slice(0, 5), ...(qa?.regressions_suspected || []).slice(0, 5)],
    decisions_needed: [...(run.spec?.needs_brain_decision || []), ...(run.human_pending || []).map((id) => `human approval pending for ${id}`)],
    recommendation: qa?.decision === "approve" ? "Merge the feature branch after a human glance." : failed.length ? "Review blockers; re-run with clarified objective or approve blocked tasks." : "Re-run QA after fixes.",
  };
}

async function phaseFinal(run) {
  const store = loadTasks();
  const mine = tasksForRun(store, run.id);
  const managerSummary = buildManagerSummary(run, mine);
  writeJson(path.join(runDir(run.id), "manager-summary.json"), managerSummary);
  const ctx = projectContext();
  const final = await agent(run, { label: "brain-final", role: "brain", roleKey: "brain", prompt: brainFinalPrompt({ objective: run.objective, managerSummary, qaReport: run.qa, ctx }), schemaName: "brain_final" });
  writeJson(path.join(runDir(run.id), "final.json"), final);
  writeText(path.join(AI_DIR, "PROJECT_STATE.md"), final.project_state_md.trim() + "\n");
  if (final.roadmap_update?.trim()) fs.appendFileSync(path.join(AI_DIR, "ROADMAP.md"), `\n<!-- run ${run.id} -->\n${final.roadmap_update.trim()}\n`);
  const md = `# Run ${run.id}\n\nOBJECTIVE:\n${final.objective}\n\nRESULT:\n${final.result}\n\nCOMPLETED:\n${final.completed.map((x) => `- ${x}`).join("\n") || "- (none)"}\n\nFAILED:\n${final.failed.map((x) => `- ${x}`).join("\n") || "- (none)"}\n\nBLOCKERS:\n${final.blockers.map((x) => `- ${x}`).join("\n") || "- (none)"}\n\nDECISIONS:\n${final.decisions.map((x) => `- ${x}`).join("\n") || "- (none)"}\n\nNEXT RECOMMENDED ACTION:\n${final.next_recommended_action}\n\n---\nBranch: ${run.feature_branch} (base: ${run.base_branch})\nTasks: ${mine.map((t) => `${t.id}=${t.status}`).join(", ")}\nQA: ${run.qa?.decision || "n/a"} | Cost (claude calls only): $${run.cost_usd}\nModels: brain=${run.models.roles.brain.provider}/${run.models.roles.brain.model}, manager=${run.models.roles.manager.provider}/${run.models.roles.manager.model}, worker=${run.models.roles.worker.provider}/${run.models.roles.worker.model}\n`;
  writeText(path.join(runDir(run.id), "final-summary.md"), md);
  g.commitAll(ROOT, `agents: run ${run.id} state update (${final.result})`);
  run.final = final;
  run.status = final.result === "BLOCKED" || run.human_pending?.length ? (run.human_pending?.length ? "PAUSED" : "DONE") : "DONE";
  if (run.human_pending?.length) run.pause_reason = `Tasks waiting for HUMAN approval: ${run.human_pending.join(", ")}. Approve with: agents approve <TASK-ID>  then: agents resume ${run.id}`;
  run.phase = "done";
  saveRun(run);
  event(run, "run_finished", { result: final.result, status: run.status });
  return md;
}

// ---------- driver ----------

export async function drive(run) {
  run.status = "RUNNING";
  run.pid = process.pid;
  run.pause_reason = null;
  saveRun(run);
  const stopFile = path.join(runDir(run.id), "STOP");
  if (fs.existsSync(stopFile)) fs.rmSync(stopFile);
  const onSignal = () => {
    killActiveChildren();
    run.status = "STOPPED";
    saveRun(run);
    process.exit(130);
  };
  process.on("SIGINT", onSignal);
  process.on("SIGTERM", onSignal);
  try {
    ensureGit(run);
    while (run.phase !== "done") {
      checkStop(run);
      if (run.phase === "brain_plan") await phaseBrainPlan(run);
      else if (run.phase === "spec") await phaseSpec(run);
      else if (run.phase === "tasks") await phaseTasks(run);
      else if (run.phase === "execute") await phaseExecute(run);
      else if (run.phase === "qa") await phaseQA(run);
      else if (run.phase === "final") return await phaseFinal(run);
      else throw new Error(`unknown phase ${run.phase}`);
    }
    return readText(path.join(runDir(run.id), "final-summary.md"));
  } catch (err) {
    if (err instanceof StopRequested) {
      run.status = "STOPPED";
      run.pause_reason = "stopped by user";
      saveRun(run);
      event(run, "stopped");
      return `Run ${run.id} stopped. Resume with: agents resume ${run.id}`;
    }
    if (err.paused) {
      if (run.status === "RUNNING") run.status = "PAUSED";
      run.pause_reason = run.pause_reason || err.message;
      saveRun(run);
      event(run, "paused", { reason: run.pause_reason });
      return `Run ${run.id} ${run.status}.\n${run.pause_reason}`;
    }
    run.status = "FAILED";
    run.pause_reason = err.message;
    saveRun(run);
    event(run, "error", { message: err.message });
    throw err;
  } finally {
    process.off("SIGINT", onSignal);
    process.off("SIGTERM", onSignal);
  }
}
