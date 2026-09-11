import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawn } from "node:child_process";
import { SCHEMAS_DIR, readJson, writeJson, nowIso, appendJsonl } from "./util.mjs";
import { assertValid } from "./validate.mjs";
import { claudeBinary, codexBinary } from "./config.mjs";
import { mockCall } from "./mock.mjs";

export const activeChildren = new Set();

export function killActiveChildren() {
  for (const child of activeChildren) {
    try {
      child.kill("SIGTERM");
    } catch {}
  }
}

function spawnCollect(bin, args, { cwd, input, timeoutMs, env }) {
  return new Promise((resolve) => {
    const child = spawn(bin, args, { cwd, env: { ...process.env, ...(env || {}) }, stdio: ["pipe", "pipe", "pipe"] });
    activeChildren.add(child);
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
      setTimeout(() => child.kill("SIGKILL"), 5000).unref();
    }, timeoutMs);
    child.stdout.on("data", (d) => (stdout += d));
    child.stderr.on("data", (d) => (stderr += d));
    child.on("close", (code) => {
      clearTimeout(timer);
      activeChildren.delete(child);
      resolve({ code, stdout, stderr, timedOut });
    });
    child.on("error", (err) => {
      clearTimeout(timer);
      activeChildren.delete(child);
      resolve({ code: -1, stdout, stderr: stderr + "\n" + err.message, timedOut });
    });
    child.stdin.on("error", () => {});
    child.stdin.end(input || "");
  });
}

export function loadSchema(name) {
  return readJson(path.join(SCHEMAS_DIR, `${name}.schema.json`));
}

const SAFE_BASH_PREFIXES = ["ls", "cat", "head", "tail", "wc", "grep", "find", "pwd", "echo", "node --version", "npm --version", "python3 --version", "git status", "git diff", "git log", "git show", "git ls-files"];

function claudeToolArgs(policy, opts) {
  if (policy === "none") return ["--tools", "", "--max-turns", String(opts.maxTurns ?? 1)];
  if (policy === "readonly") return ["--tools", "Read,Glob,Grep", "--permission-mode", "manual", "--max-turns", String(opts.maxTurns ?? 40)];
  if (policy === "worker") {
    const allowed = ["Read", "Edit", "Write", "MultiEdit", "Glob", "Grep"];
    for (const p of SAFE_BASH_PREFIXES) allowed.push(`Bash(${p}*)`);
    for (const cmd of opts.testCommands || []) allowed.push(`Bash(${cmd}*)`);
    const disallowed = ["Bash(git push*)", "Bash(rm -rf*)", "Bash(sudo*)", "Bash(curl*)", "Bash(wget*)", "Bash(npm install*)", "Bash(npm i *)", "Bash(pip install*)", "Bash(git reset*)", "Bash(git checkout*)", "WebFetch", "WebSearch", "Agent"];
    return ["--tools", "Read,Edit,Write,MultiEdit,Glob,Grep,Bash", "--permission-mode", "acceptEdits", "--allowedTools", ...allowed, "--disallowedTools", ...disallowed, "--max-turns", String(opts.maxTurns ?? 80)];
  }
  throw new Error(`unknown tool policy ${policy}`);
}

async function callClaude({ cfg, system, prompt, schema, cwd, policy, timeoutMs, opts }) {
  const bin = claudeBinary();
  if (!bin) throw new Error("claude CLI not found on PATH");
  const args = ["-p", "--model", cfg.model, "--effort", cfg.reasoning, "--output-format", "json", "--no-session-persistence", "--max-budget-usd", String(cfg.max_budget_usd)];
  if (schema) args.push("--json-schema", JSON.stringify(schema));
  if (system) args.push("--append-system-prompt", system);
  for (const d of opts.addDirs || []) args.push("--add-dir", d);
  args.push(...claudeToolArgs(policy, opts));
  const res = await spawnCollect(bin, args, { cwd, input: prompt, timeoutMs, env: { CLAUDECODE: "" } });
  if (res.timedOut) throw new Error(`claude call timed out after ${timeoutMs}ms`);
  let json;
  try {
    json = JSON.parse(res.stdout.trim().split("\n").filter(Boolean).pop());
  } catch {
    throw new Error(`claude returned non-JSON output (exit ${res.code}): ${res.stderr.slice(-800) || res.stdout.slice(-800)}`);
  }
  if (json.is_error) throw new Error(`claude error: ${String(json.result || json.error || "").slice(0, 800)}`);
  let output = json.structured_output;
  if (schema && output == null) {
    try {
      output = JSON.parse(json.result);
    } catch {
      throw new Error(`claude produced no structured output (subtype=${json.subtype}, result=${String(json.result).slice(0, 300)})`);
    }
  }
  return {
    output: schema ? output : json.result,
    cost_usd: json.total_cost_usd ?? null,
    turns: json.num_turns ?? null,
    models: Object.keys(json.modelUsage || {}),
    denials: (json.permission_denials || []).map((d) => `${d.tool_name}: ${JSON.stringify(d.tool_input).slice(0, 120)}`),
    stderr: res.stderr.slice(-2000),
  };
}

async function callCodex({ cfg, system, prompt, schema, cwd, policy, timeoutMs, opts }) {
  const bin = codexBinary();
  if (!bin) throw new Error("codex CLI not found (run npm install, or npm i -g @openai/codex)");
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "agents-codex-"));
  const outFile = path.join(tmp, "last-message.json");
  const args = ["exec", "--model", cfg.model, "-c", `model_reasoning_effort="${cfg.reasoning}"`, "--ephemeral", "--color", "never", "--cd", cwd, "--output-last-message", outFile];
  if (policy === "worker") args.push("--sandbox", "workspace-write", "-c", 'approval_policy="never"');
  else args.push("--sandbox", "read-only");
  for (const d of opts.addDirs || []) args.push("--add-dir", d);
  if (schema) {
    const schemaFile = path.join(tmp, "schema.json");
    writeJson(schemaFile, schema);
    args.push("--output-schema", schemaFile);
  }
  args.push("-");
  const full = (system ? `${system}\n\n---\n\n` : "") + prompt;
  const res = await spawnCollect(bin, args, { cwd, input: full, timeoutMs });
  if (res.timedOut) throw new Error(`codex call timed out after ${timeoutMs}ms`);
  const last = fs.existsSync(outFile) ? fs.readFileSync(outFile, "utf8") : "";
  fs.rmSync(tmp, { recursive: true, force: true });
  if (res.code !== 0 && !last.trim()) throw new Error(`codex exited ${res.code}: ${(res.stderr || res.stdout).slice(-800)}`);
  if (!last.trim()) throw new Error("codex produced an empty final message");
  let output = last;
  if (schema) {
    try {
      output = JSON.parse(last);
    } catch {
      const m = last.match(/\{[\s\S]*\}/);
      if (!m) throw new Error(`codex final message is not JSON: ${last.slice(0, 300)}`);
      output = JSON.parse(m[0]);
    }
  }
  return { output, cost_usd: null, turns: null, models: [cfg.model], denials: [], stderr: res.stderr.slice(-2000) };
}

/**
 * Call an agent role. Returns { output, meta }.
 * - cfg: { provider, model, reasoning, max_budget_usd }
 * - policy: "none" | "readonly" | "worker"
 * - schemaName: name of a schema in .ai/schemas (output validated) or null for free text
 */
export async function callAgent({ label, role, cfg, system, prompt, schemaName, cwd, policy = "none", timeoutMs = 1200000, runDir = null, opts = {} }) {
  const schema = schemaName ? loadSchema(schemaName) : null;
  const started = Date.now();
  let result;
  let error = null;
  try {
    if (cfg.provider === "mock") result = await mockCall({ label, role, prompt, schemaName, cwd, opts });
    else if (cfg.provider === "claude") result = await callClaude({ cfg, system, prompt, schema, cwd, policy, timeoutMs, opts });
    else if (cfg.provider === "codex") result = await callCodex({ cfg, system, prompt, schema, cwd, policy, timeoutMs, opts });
    else throw new Error(`unknown provider ${cfg.provider}`);
    if (schema) assertValid(schema, result.output, `${label} output`);
  } catch (err) {
    error = err;
  }
  const meta = {
    label,
    role,
    provider: cfg.provider,
    model: cfg.model,
    reasoning: cfg.reasoning,
    policy,
    started_at: new Date(started).toISOString(),
    duration_ms: Date.now() - started,
    cost_usd: result?.cost_usd ?? null,
    turns: result?.turns ?? null,
    models_used: result?.models ?? [],
    permission_denials: result?.denials ?? [],
    error: error ? error.message : null,
  };
  if (runDir) {
    const callsDir = path.join(runDir, "calls");
    fs.mkdirSync(callsDir, { recursive: true });
    const n = fs.readdirSync(callsDir).length + 1;
    writeJson(path.join(callsDir, `${String(n).padStart(3, "0")}-${label}.json`), { meta, prompt_chars: prompt.length, prompt, output: result?.output ?? null, stderr_tail: result?.stderr ?? null });
    appendJsonl(path.join(runDir, "events.jsonl"), { ts: nowIso(), type: "agent_call", ...meta });
  }
  if (error) throw error;
  return { output: result.output, meta };
}
