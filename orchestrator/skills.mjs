import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { ROOT, AI_DIR, SKILLS_DIR, REGISTRY_FILE, readJson, writeJson, nowIso, slugify, log } from "./util.mjs";
import { resolveModels } from "./config.mjs";
import { callAgent } from "./providers.mjs";
import { roleSystemPrompt, skillAuditPrompt, approvalPrompt, projectContext } from "./roles.mjs";

const AUDITS_DIR = path.join(AI_DIR, "skills", "audits");
const TMP_DIR = path.join(AI_DIR, "tmp", "skill-audits");

const RISKY = [
  ["curl-pipe-shell", /curl[^\n|]*\|\s*(ba|z)?sh/],
  ["wget-pipe-shell", /wget[^\n|]*\|\s*(ba|z)?sh/],
  ["eval", /\beval\s*\(/],
  ["exec", /\bexec\s*\(/],
  ["postinstall", /"(post|pre)install"\s*:/],
  ["ssh-dir", /~\/\.ssh|\.ssh\//],
  ["env-read", /\.env\b/],
  ["api-key", /api[_-]?key/i],
  ["sudo", /\bsudo\b/],
  ["rm-rf", /rm\s+-rf?\s/],
  ["force-push", /push\s+(-f|--force)/],
  ["skip-permissions", /dangerously-skip-permissions|dangerously-bypass/],
  ["base64-decode", /base64\s+(-d|--decode)/],
  ["remote-download", /https?:\/\/[^\s"']+\.(sh|zip|tar\.gz|tgz|exe|bin)\b/],
];

export function loadRegistry() {
  return readJson(REGISTRY_FILE, { skills: [] });
}

export function listSkills() {
  const reg = loadRegistry();
  const rows = reg.skills.map((s) => `${s.status.padEnd(15)} T${s.trust_tier}  ${s.name.padEnd(32)} ${s.source}${s.commit ? "@" + s.commit : ""}`);
  const audits = fs.existsSync(AUDITS_DIR) ? fs.readdirSync(AUDITS_DIR).filter((f) => f.endsWith(".json")) : [];
  return `REGISTRY (${REGISTRY_FILE})\n${rows.join("\n") || "(empty)"}\n\nPENDING AUDITS (.ai/skills/audits): ${audits.join(", ") || "(none)"}`;
}

function gatherMetadata(cloneDir, source) {
  const gitq = (args) => {
    try {
      return execFileSync("git", args, { cwd: cloneDir, encoding: "utf8" }).trim();
    } catch {
      return null;
    }
  };
  const files = (gitq(["ls-files"]) || "").split("\n").filter(Boolean);
  const licenseFile = files.find((f) => /^LICENSE|^LICENCE|^COPYING/i.test(f));
  const licenseHead = licenseFile ? fs.readFileSync(path.join(cloneDir, licenseFile), "utf8").split("\n").slice(0, 2).join(" ").trim() : null;
  let stats = null;
  try {
    const out = execFileSync("curl", ["-sS", "--max-time", "15", `https://api.github.com/repos/${source}`], { encoding: "utf8" });
    const j = JSON.parse(out);
    if (j.stargazers_count != null) stats = { stars: j.stargazers_count, forks: j.forks_count, open_issues: j.open_issues_count, pushed_at: j.pushed_at, created_at: j.created_at, archived: j.archived, license: j.license?.spdx_id };
  } catch {}
  return {
    source,
    commit: gitq(["rev-parse", "--short", "HEAD"]),
    last_commit_date: gitq(["log", "-1", "--format=%cI"]),
    last_commit_author: gitq(["log", "-1", "--format=%an"]),
    file_count: files.length,
    skill_files: files.filter((f) => /SKILL\.md$/.test(f)),
    manifests: files.filter((f) => /(package\.json|pyproject\.toml|requirements.*\.txt|Cargo\.toml|go\.mod|plugin\.json|marketplace\.json|\.mcp\.json|settings\.json|hooks\.json)$/.test(f)),
    scripts: files.filter((f) => /\.(sh|bash|zsh|ps1|py|js|mjs|ts)$/.test(f)).slice(0, 80),
    license_file: licenseFile || null,
    license_head: licenseHead,
    github_stats: stats || "unavailable (network restricted); verify manually",
  };
}

function grepRisky(cloneDir, files) {
  const findings = [];
  for (const rel of files) {
    const abs = path.join(cloneDir, rel);
    let text;
    try {
      if (fs.statSync(abs).size > 512 * 1024) continue;
      text = fs.readFileSync(abs, "utf8");
    } catch {
      continue;
    }
    const lines = text.split("\n");
    for (const [name, rx] of RISKY) {
      lines.forEach((line, i) => {
        if (rx.test(line)) findings.push(`${name} at ${rel}:${i + 1}: ${line.trim().slice(0, 140)}`);
      });
    }
  }
  return findings.slice(0, 200);
}

export async function auditSkill(source, opts = {}) {
  if (!/^[\w.-]+\/[\w.-]+$/.test(source)) throw new Error("source must be owner/repo");
  const models = resolveModels(undefined, { mock: opts.mock });
  const cloneDir = path.join(TMP_DIR, source.replace("/", "__"));
  fs.mkdirSync(TMP_DIR, { recursive: true });
  if (!fs.existsSync(path.join(cloneDir, ".git"))) {
    log(`cloning https://github.com/${source} (shallow, read-only, nothing executed)`);
    execFileSync("git", ["clone", "--depth", "1", "--quiet", `https://github.com/${source}`, cloneDir], { stdio: "inherit", env: { ...process.env, GIT_LFS_SKIP_SMUDGE: "1" } });
  }
  if (opts.ref) execFileSync("git", ["-C", cloneDir, "checkout", "--quiet", opts.ref]);
  const meta = gatherMetadata(cloneDir, source);
  const subdir = opts.path ? path.join(cloneDir, opts.path) : cloneDir;
  const filesAll = execFileSync("git", ["ls-files"], { cwd: cloneDir, encoding: "utf8" }).split("\n").filter(Boolean);
  const scoped = opts.path ? filesAll.filter((f) => f.startsWith(opts.path.replace(/\/$/, "") + "/")) : filesAll;
  const findings = grepRisky(cloneDir, scoped);
  const name = opts.name || slugify(`${source.split("/")[1]}${opts.path ? "-" + path.basename(opts.path) : ""}`, 60);
  const auditDir = path.join(AI_DIR, "RUNS", `skill-audit-${name}-${Date.now()}`);
  const cfg = models.roles.manager;
  log(`skill-curator audit: manager -> ${cfg.provider}/${cfg.model}`);
  const { output, meta: callMeta } = await callAgent({ label: `skill-audit-${name}`, role: "skill-curator", cfg, system: roleSystemPrompt("skill-curator"), prompt: skillAuditPrompt({ source: `${source}${opts.path ? " (path: " + opts.path + ")" : ""}`, cloneDir: subdir, metadata: meta, findings }), schemaName: "skill_audit", cwd: ROOT, policy: "readonly", timeoutMs: models.limits.CALL_TIMEOUT_MS, runDir: auditDir, opts: { addDirs: [cloneDir] } });
  const record = { name, source, path: opts.path || null, commit: meta.commit, audited_at: nowIso(), audited_by: `${cfg.provider}/${cfg.model} (skill-curator)`, metadata: meta, automated_findings: findings, audit: output, cost_usd: callMeta.cost_usd };
  fs.mkdirSync(AUDITS_DIR, { recursive: true });
  writeJson(path.join(AUDITS_DIR, `${name}.json`), record);
  return record;
}

export function formatAudit(record) {
  const a = record.audit;
  return [
    `SKILL: ${a.skill}`,
    `SOURCE: ${record.source}${record.path ? " (" + record.path + ")" : ""}`,
    `AUTHOR: ${a.author}`,
    `STARS/FORKS: ${typeof record.metadata.github_stats === "object" ? `${record.metadata.github_stats.stars}/${record.metadata.github_stats.forks}` : record.metadata.github_stats}`,
    `LAST ACTIVITY: ${record.metadata.last_commit_date}`,
    `LICENSE: ${record.metadata.license_head || "none found"}`,
    `TRUST TIER: ${a.trust_tier}`,
    `FILES REVIEWED: ${a.files_reviewed.join(", ")}`,
    `PERMISSIONS: ${a.permissions}`,
    `NETWORK ACCESS: ${a.network_access}`,
    `FILESYSTEM ACCESS: ${a.filesystem_access}`,
    `SHELL COMMANDS: ${a.shell_commands}`,
    `SECURITY FINDINGS:${a.security_findings.length ? "\n" + a.security_findings.map((f) => `  - [${f.severity}] ${f.finding} (${f.location})`).join("\n") : " none"}`,
    `WHY THIS ONE: ${a.why_this_one}`,
    `ALTERNATIVES CONSIDERED: ${a.alternatives_considered.join("; ") || "none"}`,
    `VERSION/COMMIT: ${record.commit}`,
    `DECISION (recommendation): ${a.recommendation.toUpperCase()} — ${a.recommendation_reason}`,
    `Audit saved: .ai/skills/audits/${record.name}.json`,
  ].join("\n");
}

/** Approve (and optionally install) an audited skill. Tier 2 requires a Brain approval call. Tier 3 refused. */
export async function approveSkill(name, opts = {}) {
  const file = path.join(AUDITS_DIR, `${name}.json`);
  if (!fs.existsSync(file)) throw new Error(`no audit found for ${name}. Run: agents skills audit <owner/repo>`);
  const record = readJson(file);
  const a = record.audit;
  if (a.trust_tier >= 3 || a.recommendation === "reject") throw new Error(`refusing: audit tier ${a.trust_tier} / recommendation ${a.recommendation}`);
  const models = resolveModels(undefined, { mock: opts.mock });
  let brainDecision = null;
  if (a.trust_tier === 2 || a.recommendation === "needs_brain_approval") {
    const ctx = projectContext();
    const cfg = models.roles.brain;
    log(`Tier 2 skill: requesting Brain approval -> ${cfg.provider}/${cfg.model}`);
    const { output } = await callAgent({ label: `brain-skill-approval-${name}`, role: "brain", cfg, system: roleSystemPrompt("brain"), prompt: approvalPrompt({ subject: `Install external skill ${name} from ${record.source}`, details: formatAudit(record), ctx }), schemaName: "approval", cwd: ROOT, policy: "none", timeoutMs: models.limits.CALL_TIMEOUT_MS, runDir: path.join(AI_DIR, "RUNS", `skill-approval-${name}-${Date.now()}`) });
    brainDecision = output;
    if (output.decision !== "approve") throw new Error(`Brain ${output.decision}: ${output.reason}`);
  }
  const reg = loadRegistry();
  const entry = {
    name,
    source: record.source,
    repository: `https://github.com/${record.source}`,
    author: a.author,
    organization: a.author,
    version: opts.version || null,
    tag: opts.version || null,
    commit: record.commit,
    stars_at_audit: typeof record.metadata.github_stats === "object" ? record.metadata.github_stats.stars : null,
    forks: typeof record.metadata.github_stats === "object" ? record.metadata.github_stats.forks : null,
    maintainer_followers: null,
    last_activity: record.metadata.last_commit_date,
    license: record.metadata.license_head,
    trust_tier: a.trust_tier,
    audited_by: record.audited_by,
    audit_date: record.audited_at,
    purpose: a.purpose,
    security_findings: a.security_findings,
    alternatives_considered: a.alternatives_considered,
    brain_approval: brainDecision,
    status: "approved",
    installed_path: null,
  };
  if (opts.install) {
    const cloneDir = path.join(TMP_DIR, record.source.replace("/", "__"));
    const src = record.path ? path.join(cloneDir, record.path) : cloneDir;
    if (!fs.existsSync(path.join(src, "SKILL.md"))) throw new Error(`no SKILL.md at ${src}; pass --path to the skill folder when auditing`);
    const dest = path.join(SKILLS_DIR, name);
    fs.cpSync(src, dest, { recursive: true, filter: (p) => !p.includes("/.git") });
    entry.installed_path = path.relative(ROOT, dest);
  }
  reg.skills = reg.skills.filter((s) => s.name !== name).concat(entry);
  writeJson(REGISTRY_FILE, reg);
  return entry;
}
