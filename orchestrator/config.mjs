import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { ROOT, AI_DIR, readJson } from "./util.mjs";

const CONFIG_FILE = path.join(AI_DIR, "config.json");

export function loadRawConfig() {
  return readJson(CONFIG_FILE);
}

export function codexBinary() {
  const local = path.join(ROOT, "node_modules", ".bin", "codex");
  if (fs.existsSync(local)) return local;
  try {
    return execFileSync(process.platform === "win32" ? "where" : "which", ["codex"], { encoding: "utf8" }).trim().split("\n")[0] || null;
  } catch {
    return null;
  }
}

export function claudeBinary() {
  try {
    return execFileSync(process.platform === "win32" ? "where" : "which", ["claude"], { encoding: "utf8" }).trim().split("\n")[0] || null;
  } catch {
    return null;
  }
}

let codexAuthCache;
/** Returns { available: bool, loggedIn: bool, detail: string } without revealing credentials. */
export function codexStatus() {
  if (codexAuthCache) return codexAuthCache;
  const bin = codexBinary();
  if (!bin) return (codexAuthCache = { available: false, loggedIn: false, detail: "codex binary not found (npm install or npm i -g @openai/codex)" });
  let loggedIn = false;
  let detail = "";
  try {
    const out = execFileSync(bin, ["login", "status"], { encoding: "utf8", timeout: 20000, stdio: ["ignore", "pipe", "pipe"] });
    detail = out.trim().split("\n")[0];
    loggedIn = !/not logged in/i.test(out);
  } catch (err) {
    detail = (err.stdout || err.stderr || err.message || "").toString().trim().split("\n")[0];
    loggedIn = /logged in/i.test(detail) && !/not logged in/i.test(detail);
  }
  if (!loggedIn && (process.env.OPENAI_API_KEY || process.env.CODEX_API_KEY)) {
    loggedIn = true;
    detail = "API key present in environment";
  }
  return (codexAuthCache = { available: true, loggedIn, detail, bin });
}

export function claudeStatus() {
  const bin = claudeBinary();
  if (!bin) return { available: false, loggedIn: false, detail: "claude binary not found (npm i -g @anthropic-ai/claude-code)" };
  try {
    const out = execFileSync(bin, ["auth", "status"], { encoding: "utf8", timeout: 20000, stdio: ["ignore", "pipe", "pipe"] });
    const j = JSON.parse(out);
    return { available: true, loggedIn: !!j.loggedIn, detail: `${j.authMethod || "?"} / ${j.apiProvider || "?"}`, bin };
  } catch (err) {
    const loggedIn = !!process.env.ANTHROPIC_API_KEY;
    return { available: true, loggedIn, detail: loggedIn ? "ANTHROPIC_API_KEY present" : "auth status unavailable", bin };
  }
}

function envOr(name, fallback) {
  const v = process.env[name];
  return v && v.trim() ? v.trim() : fallback;
}

/** Resolve the effective provider/model/reasoning for each role, honoring env overrides and "auto". */
export function resolveModels(raw = loadRawConfig(), opts = {}) {
  const mock = opts.mock ?? process.env.AGENTS_MOCK === "1";
  const codex = mock ? { available: true, loggedIn: true, detail: "mock" } : codexStatus();
  const roles = {};
  for (const role of ["brain", "manager", "worker"]) {
    const R = role.toUpperCase();
    const cfg = raw.roles[role];
    let provider = envOr(`${R}_PROVIDER`, cfg.provider);
    let fallbackNote = null;
    if (provider === "auto") {
      provider = codex.loggedIn ? "codex" : "claude";
      if (!codex.loggedIn) fallbackNote = `codex not authenticated (${codex.detail}); using claude`;
    }
    if (mock) provider = "mock";
    const modelDefault = typeof cfg.model === "string" ? cfg.model : cfg.model[provider === "mock" ? "claude" : provider];
    roles[role] = {
      provider,
      model: envOr(`MODEL_${R}`, modelDefault),
      reasoning: envOr(`${R}_REASONING`, cfg.reasoning),
      max_budget_usd: Number(envOr(`${R}_MAX_BUDGET_USD`, cfg.max_budget_usd)),
      fallbackNote,
    };
  }
  const limits = { ...raw.limits };
  for (const k of Object.keys(limits)) limits[k] = Number(envOr(k, limits[k]));
  return { roles, limits, git: raw.git, guardrails: raw.guardrails, mock };
}
