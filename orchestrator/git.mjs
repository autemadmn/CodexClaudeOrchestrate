import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { ROOT } from "./util.mjs";

export function git(args, opts = {}) {
  return execFileSync("git", args, { cwd: opts.cwd || ROOT, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"], ...opts }).trim();
}

export function tryGit(args, opts = {}) {
  try {
    return { ok: true, out: git(args, opts) };
  } catch (err) {
    return { ok: false, out: (err.stderr || err.stdout || err.message || "").toString().trim() };
  }
}

export function currentBranch(cwd) {
  return git(["rev-parse", "--abbrev-ref", "HEAD"], { cwd });
}

export function isClean(cwd = ROOT) {
  return git(["status", "--porcelain", "--untracked-files=normal"], { cwd }) === "";
}

export function hasCommits(cwd = ROOT) {
  return tryGit(["rev-parse", "--verify", "HEAD"], { cwd }).ok;
}

export function branchExists(name, cwd = ROOT) {
  return tryGit(["rev-parse", "--verify", "--quiet", `refs/heads/${name}`], { cwd }).ok;
}

export function createBranchFromHead(name, cwd = ROOT) {
  git(["checkout", "-b", name], { cwd });
}

export function checkout(name, cwd = ROOT) {
  git(["checkout", name], { cwd });
}

export function addWorktree(dir, branch, base, cwd = ROOT) {
  fs.mkdirSync(path.dirname(dir), { recursive: true });
  if (branchExists(branch, cwd)) git(["branch", "-D", branch], { cwd });
  git(["worktree", "add", "-b", branch, dir, base], { cwd });
}

export function removeWorktree(dir, branch, cwd = ROOT) {
  tryGit(["worktree", "remove", "--force", dir], { cwd });
  tryGit(["worktree", "prune"], { cwd });
  if (branch) tryGit(["branch", "-D", branch], { cwd });
}

export function changedFiles(cwd) {
  const out = git(["status", "--porcelain", "--untracked-files=all"], { cwd });
  return out
    .split("\n")
    .filter(Boolean)
    .map((l) => l.slice(3).trim().replace(/^"|"$/g, ""))
    .map((f) => (f.includes(" -> ") ? f.split(" -> ")[1] : f));
}

export function commitAll(cwd, message) {
  git(["add", "-A"], { cwd });
  if (git(["status", "--porcelain"], { cwd }) === "") return null;
  git(["-c", "user.name=agents-orchestrator", "-c", "user.email=agents@localhost", "commit", "-q", "-m", message], { cwd });
  return git(["rev-parse", "--short", "HEAD"], { cwd });
}

export function diffBetween(base, head, cwd = ROOT) {
  return git(["diff", `${base}...${head}`], { cwd, maxBuffer: 64 * 1024 * 1024 });
}

export function diffFiles(base, head, cwd = ROOT) {
  const out = git(["diff", "--name-only", `${base}...${head}`], { cwd });
  return out ? out.split("\n").filter(Boolean) : [];
}

/** Merge branch into the current branch (no-ff). Returns { ok, conflict, out }. */
export function mergeBranch(branch, message, cwd = ROOT) {
  const r = tryGit(["-c", "user.name=agents-orchestrator", "-c", "user.email=agents@localhost", "merge", "--no-ff", "-m", message, branch], { cwd });
  if (r.ok) return { ok: true, conflict: false, out: r.out };
  tryGit(["merge", "--abort"], { cwd });
  return { ok: false, conflict: /conflict/i.test(r.out), out: r.out };
}

export function repoOverview(cwd = ROOT, maxFiles = 250) {
  const files = tryGit(["ls-files"], { cwd });
  const list = files.ok ? files.out.split("\n").filter(Boolean) : [];
  const shown = list.slice(0, maxFiles);
  let summary = `Tracked files: ${list.length}\n` + shown.join("\n");
  if (list.length > maxFiles) summary += `\n... (${list.length - maxFiles} more)`;
  const pkg = path.join(cwd, "package.json");
  if (fs.existsSync(pkg)) {
    try {
      const j = JSON.parse(fs.readFileSync(pkg, "utf8"));
      summary += `\n\npackage.json: name=${j.name} scripts=${Object.keys(j.scripts || {}).join(",")} deps=${Object.keys(j.dependencies || {}).join(",")}`;
    } catch {}
  }
  for (const f of ["pyproject.toml", "requirements.txt", "go.mod", "Cargo.toml", "pubspec.yaml"]) if (fs.existsSync(path.join(cwd, f))) summary += `\n${f}: present`;
  return summary;
}
