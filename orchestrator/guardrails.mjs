import { matchesAny } from "./util.mjs";

const ORDER = { AUTO_APPROVED: 0, REQUIRES_BRAIN_APPROVAL: 1, REQUIRES_HUMAN_APPROVAL: 2 };

export function maxCategory(a, b) {
  return ORDER[a] >= ORDER[b] ? a : b;
}

/** Deterministically classify a task's approval category from its paths and wording; never lowers the manager-declared category. */
export function classifyTask(task, guardrails) {
  let cat = task.approval_category || "AUTO_APPROVED";
  const reasons = [];
  const text = `${task.title} ${task.description}`.toLowerCase();
  const paths = [...(task.allowed_files || []), ...((task.result && task.result.files_changed) || [])];
  for (const p of paths) {
    if (matchesAny(p, guardrails.human_approval_paths) || guardrails.human_approval_paths.some((g) => globsTouch(g, p))) {
      cat = maxCategory(cat, "REQUIRES_HUMAN_APPROVAL");
      reasons.push(`path ${p} matches human-approval list`);
    } else if (matchesAny(p, guardrails.brain_approval_paths) || guardrails.brain_approval_paths.some((g) => globsTouch(g, p))) {
      cat = maxCategory(cat, "REQUIRES_BRAIN_APPROVAL");
      reasons.push(`path ${p} matches brain-approval list`);
    }
  }
  for (const k of guardrails.human_approval_keywords || []) if (text.includes(k)) {
    cat = maxCategory(cat, "REQUIRES_HUMAN_APPROVAL");
    reasons.push(`keyword "${k}"`);
  }
  for (const k of guardrails.brain_approval_keywords || []) if (text.includes(k)) {
    cat = maxCategory(cat, "REQUIRES_BRAIN_APPROVAL");
    reasons.push(`keyword "${k}"`);
  }
  return { category: cat, reasons };
}

/** A pattern from allowed_files (may itself be a glob) "touches" a guard glob if their prefixes nest. */
function globsTouch(guardGlob, taskGlob) {
  if (!/[*?]/.test(taskGlob)) return false;
  const prefix = (g) => g.slice(0, g.search(/[*?]/) === -1 ? g.length : g.search(/[*?]/)).replace(/\/$/, "");
  const gp = prefix(guardGlob.replace(/^\*\*\//, ""));
  const tp = prefix(taskGlob);
  if (!gp || !tp) return false;
  return gp.startsWith(tp + "/") || tp.startsWith(gp + "/") || gp === tp;
}

/** Check the files a worker actually changed against allowed_files and forbidden paths. */
export function checkChangedFiles(changedFiles, task, guardrails) {
  const violations = [];
  const forbidden = [];
  for (const f of changedFiles) {
    if (matchesAny(f, guardrails.forbidden_paths)) forbidden.push(f);
    else if (!matchesAny(f, task.allowed_files)) violations.push(f);
  }
  return { ok: violations.length === 0 && forbidden.length === 0, violations, forbidden };
}
