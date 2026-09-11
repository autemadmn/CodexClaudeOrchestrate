import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";

export function findRepoRoot(start = process.cwd()) {
  let dir = path.resolve(start);
  for (;;) {
    if (fs.existsSync(path.join(dir, ".ai", "config.json"))) return dir;
    const parent = path.dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  try {
    return execFileSync("git", ["rev-parse", "--show-toplevel"], { cwd: start, encoding: "utf8" }).trim();
  } catch {
    return path.resolve(start);
  }
}

export const ROOT = findRepoRoot();
export const AI_DIR = path.join(ROOT, ".ai");
export const RUNS_DIR = path.join(AI_DIR, "RUNS");
export const TASKS_FILE = path.join(AI_DIR, "TASKS.json");
export const SCHEMAS_DIR = path.join(AI_DIR, "schemas");
export const SKILLS_DIR = path.join(ROOT, ".claude", "skills");
export const REGISTRY_FILE = path.join(AI_DIR, "skills", "registry.json");

export function readJson(file, fallback) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (err) {
    if (fallback !== undefined) return fallback;
    throw new Error(`Cannot read JSON ${file}: ${err.message}`);
  }
}

export function writeJson(file, data) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n");
}

export function readText(file, fallback = "") {
  try {
    return fs.readFileSync(file, "utf8");
  } catch {
    return fallback;
  }
}

export function writeText(file, text) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, text);
}

export function appendJsonl(file, obj) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.appendFileSync(file, JSON.stringify(obj) + "\n");
}

export function truncate(text, max) {
  if (!text) return "";
  if (text.length <= max) return text;
  return text.slice(0, max) + `\n... [truncated ${text.length - max} chars]`;
}

export function nowIso() {
  return new Date().toISOString();
}

export function slugify(text, max = 40) {
  return (
    text
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, max) || "objective"
  );
}

export function runId() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, "0");
  return `${d.getFullYear()}${p(d.getMonth() + 1)}${p(d.getDate())}-${p(d.getHours())}${p(d.getMinutes())}${p(d.getSeconds())}`;
}

/** Minimal glob matcher: supports **, *, ? and trailing "/" meaning directory prefix. */
export function globToRegExp(glob) {
  let g = glob.replace(/\\/g, "/");
  if (g.startsWith("./")) g = g.slice(2);
  if (g.endsWith("/")) g += "**";
  let re = "";
  for (let i = 0; i < g.length; i++) {
    const c = g[i];
    if (c === "*") {
      if (g[i + 1] === "*") {
        i++;
        if (g[i + 1] === "/") {
          i++;
          re += "(?:.*/)?";
        } else re += ".*";
      } else re += "[^/]*";
    } else if (c === "?") re += "[^/]";
    else if (".+^${}()|[]\\".includes(c)) re += "\\" + c;
    else re += c;
  }
  return new RegExp("^" + re + "$");
}

export function matchesAny(file, globs) {
  const f = file.replace(/\\/g, "/").replace(/^\.\//, "");
  return (globs || []).some((g) => {
    const rx = globToRegExp(g);
    if (rx.test(f)) return true;
    // "src/screens" (no wildcard) also matches everything under it
    if (!/[*?]/.test(g) && f.startsWith(g.replace(/\/$/, "") + "/")) return true;
    return false;
  });
}

/** Heuristic: can two allowed_files sets touch the same file? */
export function globsOverlap(globsA, globsB) {
  const prefix = (g) => {
    const i = g.search(/[*?]/);
    return (i === -1 ? g : g.slice(0, i)).replace(/\/$/, "");
  };
  for (const a of globsA || []) {
    for (const b of globsB || []) {
      if (a === b) return true;
      const pa = prefix(a);
      const pb = prefix(b);
      const aHasWild = /[*?]/.test(a);
      const bHasWild = /[*?]/.test(b);
      if (!aHasWild && !bHasWild) {
        // both concrete: overlap only if equal or one is a directory containing the other
        if (pa.startsWith(pb + "/") || pb.startsWith(pa + "/")) return true;
        continue;
      }
      if (aHasWild && !bHasWild && (globToRegExp(a).test(b) || b.startsWith(pa))) return true;
      if (bHasWild && !aHasWild && (globToRegExp(b).test(a) || a.startsWith(pb))) return true;
      if (aHasWild && bHasWild && (pa.startsWith(pb) || pb.startsWith(pa))) return true;
    }
  }
  return false;
}

export function log(msg) {
  const ts = new Date().toTimeString().slice(0, 8);
  process.stdout.write(`[${ts}] ${msg}\n`);
}
