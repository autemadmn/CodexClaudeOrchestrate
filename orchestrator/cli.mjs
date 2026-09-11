import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { ROOT, AI_DIR, RUNS_DIR, readJson, readText, writeText, log } from "./util.mjs";
import { resolveModels, loadRawConfig, codexStatus, claudeStatus, codexBinary, claudeBinary } from "./config.mjs";
import { loadTasks, saveTasks, getTask, setStatus } from "./tasks.mjs";
import { createRun, loadRun, saveRun, latestRunId, drive, runDir } from "./run.mjs";
import { listSkills, auditSkill, approveSkill, formatAudit, loadRegistry } from "./skills.mjs";
import * as g from "./git.mjs";

const HELP = `agents — multi-agent development system (Brain -> Managers -> Workers -> Review -> QA -> Brain)

Usage:
  agents run "<objective>" [--in-place] [--mock]   Run the full pipeline on an objective
  agents resume [run-id]                            Continue a paused/stopped run (latest by default)
  agents stop [run-id]                              Stop a running run gracefully (latest by default)
  agents approve <TASK-ID | run-id>                 Human approval for a blocked task or a paused run
  agents status                                     Milestone, tasks, blockers, latest run, models
  agents tasks [run-id]                             List tasks (all, or for one run)
  agents logs [run-id] [--calls]                    Show run events (and agent calls)
  agents skills [list | audit <owner/repo> [--path dir] [--ref tag] | approve <name> [--install] [--version v]]
  agents doctor                                     Check git, claude, codex, credentials, models, config, registry

Environment overrides: MODEL_BRAIN, MODEL_MANAGER, MODEL_WORKER, BRAIN_PROVIDER, MANAGER_PROVIDER, WORKER_PROVIDER,
  BRAIN_REASONING, MANAGER_REASONING, WORKER_REASONING, MAX_PARALLEL_WORKERS, MAX_FIX_ATTEMPTS, MAX_TASKS_PER_RUN,
  MAX_BUDGET_USD_PER_RUN, AGENTS_MOCK=1 (offline deterministic providers, for tests).`;

function flags(args) {
  const out = { _: [] };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a.startsWith("--")) {
      const k = a.slice(2);
      const next = args[i + 1];
      if (next && !next.startsWith("--")) {
        out[k] = next;
        i++;
      } else out[k] = true;
    } else out._.push(a);
  }
  return out;
}

export async function main(argv) {
  const cmd = argv[0];
  const f = flags(argv.slice(1));
  switch (cmd) {
    case "run":
      return cmdRun(f);
    case "resume":
      return cmdResume(f);
    case "stop":
      return cmdStop(f);
    case "approve":
      return cmdApprove(f);
    case "status":
      return cmdStatus();
    case "tasks":
      return cmdTasks(f);
    case "logs":
      return cmdLogs(f);
    case "skills":
      return cmdSkills(f);
    case "doctor":
      return cmdDoctor();
    case undefined:
    case "help":
    case "--help":
    case "-h":
      console.log(HELP);
      return 0;
    default:
      console.log(`unknown command: ${cmd}\n\n${HELP}`);
      return 1;
  }
}

async function cmdRun(f) {
  const objective = f._.join(" ").trim();
  if (!objective) throw new Error('usage: agents run "<objective>"');
  const run = createRun(objective, { inPlace: !!f["in-place"], mock: !!f.mock || process.env.AGENTS_MOCK === "1" });
  const m = run.models.roles;
  log(`run ${run.id} | brain=${m.brain.provider}/${m.brain.model} manager=${m.manager.provider}/${m.manager.model} worker=${m.worker.provider}/${m.worker.model}`);
  for (const r of ["brain", "worker"]) if (m[r].fallbackNote) log(`note: ${r}: ${m[r].fallbackNote}`);
  const summary = await drive(run);
  console.log(`\n${summary}`);
  return run.status === "FAILED" ? 1 : 0;
}

async function cmdResume(f) {
  const id = f._[0] || latestRunId();
  if (!id) throw new Error("no runs found");
  const run = loadRun(id);
  if (run.status === "DONE" && run.phase === "done") {
    console.log(`Run ${id} already finished (${run.final?.result}).`);
    return 0;
  }
  if (run.status === "RUNNING" && run.pid && isAlive(run.pid)) throw new Error(`run ${id} appears to be running (pid ${run.pid}). Use agents stop first.`);
  // refresh model resolution (codex may have been logged in since) but keep the same providers for consistency
  const summary = await drive(run);
  console.log(`\n${summary}`);
  return 0;
}

function isAlive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

async function cmdStop(f) {
  const id = f._[0] || latestRunId();
  if (!id) throw new Error("no runs found");
  const run = loadRun(id);
  writeText(path.join(runDir(id), "STOP"), new Date().toISOString());
  if (run.pid && isAlive(run.pid) && run.pid !== process.pid) {
    try {
      process.kill(run.pid, "SIGTERM");
      console.log(`Sent SIGTERM to run ${id} (pid ${run.pid}). STOP marker written; resume later with: agents resume ${id}`);
      return 0;
    } catch {}
  }
  console.log(`STOP marker written for run ${id} (no live process found). Resume later with: agents resume ${id}`);
  return 0;
}

async function cmdApprove(f) {
  const target = f._[0];
  if (!target) throw new Error("usage: agents approve <TASK-ID | run-id>");
  if (/^TASK-\d+$/.test(target)) {
    const store = loadTasks();
    const t = getTask(store, target);
    t.human_approved = true;
    t.brain_approved = true;
    setStatus(t, "READY");
    t.blockers = [...(t.blockers || []), `human approved at ${new Date().toISOString()}`];
    saveTasks(store);
    const run = t.run_id ? loadRun(t.run_id) : null;
    if (run) {
      run.human_pending = (run.human_pending || []).filter((x) => x !== t.id);
      if (run.phase === "done") run.phase = "execute";
      saveRun(run);
    }
    console.log(`${t.id} approved by human -> READY. Continue with: agents resume ${t.run_id || ""}`.trim());
    return 0;
  }
  const run = loadRun(target);
  run.human_approved = true;
  saveRun(run);
  console.log(`Run ${target} marked as human-approved. Continue with: agents resume ${target}`);
  return 0;
}

function cmdStatus() {
  const models = resolveModels();
  const store = loadTasks();
  const counts = {};
  for (const t of store.tasks) counts[t.status] = (counts[t.status] || 0) + 1;
  const latest = latestRunId();
  const run = latest ? loadRun(latest) : null;
  const roadmap = readText(path.join(AI_DIR, "ROADMAP.md"));
  const milestone = (roadmap.match(/^\d+\.\s+\*\*(.+?)\*\*/gm) || []).map((m) => m.replace(/^\d+\.\s+\*\*|\*\*$/g, "")).find((m, i, arr) => !roadmap.includes(`${m}** (done)`)) || "(see ROADMAP.md)";
  const blockers = store.tasks.filter((t) => t.status === "BLOCKED").map((t) => `  - ${t.id} ${t.title}: ${(t.blockers || []).slice(-1)[0] || ""}`);
  const running = store.tasks.filter((t) => ["IN_PROGRESS", "REVIEW", "QA"].includes(t.status)).map((t) => `  - ${t.id} ${t.title} [${t.status}]`);
  const lines = [
    `CURRENT MILESTONE: ${milestone}`,
    `PROJECT_STATE: ${readText(path.join(AI_DIR, "PROJECT_STATE.md")).split("\n").find((l) => l.includes("Current status")) || "(see .ai/PROJECT_STATE.md)"}`,
    `OPEN TASKS: ${Object.entries(counts).map(([k, v]) => `${k}=${v}`).join(" ") || "none"}`,
    `RUNNING TASKS:\n${running.join("\n") || "  (none)"}`,
    `BLOCKERS:\n${blockers.join("\n") || "  (none)"}`,
    `LATEST RUN: ${run ? `${run.id} [${run.status}] phase=${run.phase} branch=${run.feature_branch || "-"} cost=$${run.cost_usd}${run.pause_reason ? "\n  " + run.pause_reason.split("\n")[0] : ""}` : "(none)"}`,
    `MODELS:`,
    ...["brain", "manager", "worker"].map((r) => `  ${r.padEnd(8)} ${models.roles[r].provider}/${models.roles[r].model} (reasoning=${models.roles[r].reasoning})${models.roles[r].fallbackNote ? "  [" + models.roles[r].fallbackNote + "]" : ""}`),
    `MANAGERS: product-architect-manager, implementation-manager, qa-manager (+ skill-curator capability)`,
    `WORKERS: up to ${models.limits.MAX_PARALLEL_WORKERS} parallel, ${models.limits.MAX_FIX_ATTEMPTS} fix attempts, ${models.limits.MAX_TASKS_PER_RUN} tasks/run`,
  ];
  console.log(lines.join("\n"));
  return 0;
}

function cmdTasks(f) {
  const store = loadTasks();
  const runId = f._[0];
  const tasks = runId ? store.tasks.filter((t) => t.run_id === runId) : store.tasks;
  if (!tasks.length) {
    console.log("(no tasks)");
    return 0;
  }
  for (const t of tasks) {
    console.log(`${t.id}  ${t.status.padEnd(11)} ${t.priority}  ${t.title}\n    run=${t.run_id} attempts=${t.attempts} review=${t.review_status ?? "-"} qa=${t.qa_status ?? "-"} deps=${t.dependencies.join(",") || "-"}\n    files=${t.allowed_files.join(", ")}${t.blockers?.length ? `\n    blockers: ${t.blockers.slice(-1)[0]}` : ""}`);
  }
  return 0;
}

function cmdLogs(f) {
  const id = f._[0] || latestRunId();
  if (!id) throw new Error("no runs found");
  const dir = runDir(id);
  const events = readText(path.join(dir, "events.jsonl")).split("\n").filter(Boolean);
  console.log(`RUN ${id} (${dir})`);
  for (const line of events) {
    const e = JSON.parse(line);
    const { ts, type, ...rest } = e;
    const short = Object.entries(rest)
      .filter(([k]) => !["prompt", "output"].includes(k))
      .map(([k, v]) => `${k}=${typeof v === "string" ? v.slice(0, 120).replace(/\n/g, " ") : JSON.stringify(v).slice(0, 120)}`)
      .join(" ");
    console.log(`${ts.slice(11, 19)} ${type.padEnd(20)} ${short}`);
  }
  if (f.calls) {
    const callsDir = path.join(dir, "calls");
    if (fs.existsSync(callsDir)) for (const c of fs.readdirSync(callsDir).sort()) console.log(`  call: ${path.join("calls", c)}`);
  }
  const fin = path.join(dir, "final-summary.md");
  if (fs.existsSync(fin)) console.log(`\n${readText(fin)}`);
  return 0;
}

async function cmdSkills(f) {
  const sub = f._[0] || "list";
  if (sub === "list") {
    console.log(listSkills());
    return 0;
  }
  if (sub === "audit") {
    const source = f._[1];
    if (!source) throw new Error("usage: agents skills audit <owner/repo> [--path dir] [--ref tag] [--name n]");
    const rec = await auditSkill(source, { path: f.path, ref: f.ref, name: f.name, mock: !!f.mock });
    console.log(formatAudit(rec));
    return 0;
  }
  if (sub === "approve") {
    const name = f._[1];
    if (!name) throw new Error("usage: agents skills approve <name> [--install] [--version v]");
    const entry = await approveSkill(name, { install: !!f.install, version: f.version, mock: !!f.mock });
    console.log(`approved: ${entry.name} (tier ${entry.trust_tier}, commit ${entry.commit})${entry.installed_path ? ` installed at ${entry.installed_path}` : ""}`);
    return 0;
  }
  throw new Error(`unknown skills subcommand ${sub}`);
}

function cmdDoctor() {
  const rows = [];
  const ok = (name, good, detail) => rows.push(`${good ? "✓" : "✗"} ${name.padEnd(22)} ${detail}`);
  const warn = (name, detail) => rows.push(`⚠ ${name.padEnd(22)} ${detail}`);
  let failures = 0;
  // git
  const gitv = g.tryGit(["--version"]);
  ok("git", gitv.ok, gitv.out || "missing");
  if (!gitv.ok) failures++;
  const inRepo = g.tryGit(["rev-parse", "--is-inside-work-tree"]).ok;
  ok("git repository", inRepo, inRepo ? `${ROOT} (branch ${g.tryGit(["symbolic-ref", "--short", "HEAD"]).out || "detached"})` : "not a git repo");
  if (!inRepo) failures++;
  if (inRepo && !g.hasCommits()) warn("git commits", "no commits yet — make an initial commit before `agents run`");
  if (inRepo && g.hasCommits() && !g.isClean()) warn("working tree", "not clean — `agents run` requires a clean tree (or --in-place)");
  // node
  ok("node", true, process.version);
  // claude
  const c = claudeStatus();
  ok("claude CLI", c.available, c.available ? `${c.bin} ${safeVersion(c.bin)}` : c.detail);
  if (!c.available) failures++;
  ok("claude auth", c.loggedIn, c.loggedIn ? `logged in (${c.detail})` : "not logged in — run `claude auth login` or set ANTHROPIC_API_KEY");
  if (!c.loggedIn) failures++;
  // codex
  const x = codexStatus();
  ok("codex CLI", x.available, x.available ? `${x.bin} ${safeVersion(x.bin)}` : x.detail);
  if (x.available) {
    if (x.loggedIn) ok("codex auth", true, `authenticated (${x.detail})`);
    else warn("codex auth", `${x.detail} — run \`npx codex login\`; brain/worker will fall back to claude until then`);
  }
  // credentials presence (never printed)
  const cred = ["ANTHROPIC_API_KEY", "OPENAI_API_KEY", "CODEX_API_KEY"].map((k) => `${k}=${process.env[k] ? "set" : "unset"}`).join(" ");
  const codexAuthFile = fs.existsSync(path.join(process.env.CODEX_HOME || path.join(process.env.HOME || "", ".codex"), "auth.json"));
  ok("credentials presence", true, `${cred} codex_auth_file=${codexAuthFile ? "present" : "absent"} (values never shown)`);
  // config + models
  let models;
  try {
    models = resolveModels();
    ok("config", true, `.ai/config.json valid`);
    for (const r of ["brain", "manager", "worker"]) {
      const m = models.roles[r];
      const providerOk = m.provider === "claude" ? c.loggedIn : m.provider === "codex" ? x.loggedIn : true;
      (providerOk ? ok : warn)(`model ${r}`, providerOk, `${m.provider}/${m.model} reasoning=${m.reasoning} budget=$${m.max_budget_usd}${m.fallbackNote ? " [" + m.fallbackNote + "]" : ""}`);
    }
    ok("limits", true, Object.entries(models.limits).map(([k, v]) => `${k}=${v}`).join(" "));
  } catch (err) {
    ok("config", false, err.message);
    failures++;
  }
  // schemas
  const schemas = fs.existsSync(path.join(AI_DIR, "schemas")) ? fs.readdirSync(path.join(AI_DIR, "schemas")).filter((s) => s.endsWith(".json")) : [];
  let schemaErr = null;
  for (const s of schemas) try {
    readJson(path.join(AI_DIR, "schemas", s));
  } catch (e) {
    schemaErr = `${s}: ${e.message}`;
  }
  ok("schemas", schemas.length >= 10 && !schemaErr, schemaErr || `${schemas.length} schemas`);
  if (schemaErr) failures++;
  // skills
  const roleSkills = ["agent-common", "brain", "product-architect-manager", "implementation-manager", "qa-manager", "worker", "skill-curator"];
  const missing = roleSkills.filter((s) => !fs.existsSync(path.join(ROOT, ".claude", "skills", s, "SKILL.md")));
  ok("role skills", !missing.length, missing.length ? `missing: ${missing.join(", ")}` : `${roleSkills.length} internal skills present`);
  if (missing.length) failures++;
  try {
    const reg = loadRegistry();
    ok("skills registry", true, `${reg.skills.length} entries (${reg.skills.filter((s) => s.status === "approved").length} approved)`);
  } catch (err) {
    ok("skills registry", false, err.message);
    failures++;
  }
  // state
  for (const fname of ["PROJECT_STATE.md", "ROADMAP.md", "TASKS.json"]) {
    const exists = fs.existsSync(path.join(AI_DIR, fname));
    ok(`state ${fname}`, exists, exists ? "present" : "missing");
    if (!exists) failures++;
  }
  ok("runs dir", true, `${fs.existsSync(RUNS_DIR) ? fs.readdirSync(RUNS_DIR).filter((d) => d !== ".gitkeep").length : 0} runs in .ai/RUNS`);
  console.log(rows.join("\n"));
  console.log(failures ? `\nDOCTOR: ${failures} problem(s) found` : "\nDOCTOR: all checks passed");
  return failures ? 1 : 0;
}

function safeVersion(bin) {
  try {
    return execFileSync(bin, ["--version"], { encoding: "utf8", timeout: 20000, stdio: ["ignore", "pipe", "ignore"] }).trim().split("\n")[0];
  } catch {
    return "";
  }
}
