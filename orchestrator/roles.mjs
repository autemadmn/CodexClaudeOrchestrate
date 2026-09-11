import fs from "node:fs";
import path from "node:path";
import { ROOT, AI_DIR, SKILLS_DIR, readText, truncate } from "./util.mjs";

export function skillText(name) {
  const file = path.join(SKILLS_DIR, name, "SKILL.md");
  const raw = readText(file);
  if (!raw) throw new Error(`skill not found: ${file}`);
  return raw.replace(/^---[\s\S]*?---\s*/, "");
}

export function roleSystemPrompt(role) {
  return `${skillText("agent-common")}\n\n${skillText(role)}`;
}

export function projectContext() {
  const state = readText(path.join(AI_DIR, "PROJECT_STATE.md"), "(no PROJECT_STATE.md)");
  const roadmap = readText(path.join(AI_DIR, "ROADMAP.md"), "(no ROADMAP.md)");
  const decDir = path.join(AI_DIR, "DECISIONS");
  let decisions = "(none)";
  if (fs.existsSync(decDir)) {
    const items = fs
      .readdirSync(decDir)
      .filter((f) => f.endsWith(".md"))
      .sort()
      .map((f) => {
        const first = readText(path.join(decDir, f)).split("\n").find((l) => l.startsWith("#")) || f;
        return `- ${f}: ${first.replace(/^#+\s*/, "")}`;
      });
    if (items.length) decisions = items.join("\n");
  }
  return { state: truncate(state, 6000), roadmap: truncate(roadmap, 6000), decisions: truncate(decisions, 3000) };
}

export function brainPlanPrompt({ objective, ctx, limits, lastRun }) {
  return `OBJECTIVE FROM THE USER:\n${objective}\n\n## PROJECT_STATE.md\n${ctx.state}\n\n## ROADMAP.md\n${ctx.roadmap}\n\n## DECISIONS (index)\n${ctx.decisions}\n\n## LAST RUN SUMMARY\n${lastRun || "(none)"}\n\n## LIMITS\nMAX_TASKS_PER_RUN=${limits.MAX_TASKS_PER_RUN}, MAX_PARALLEL_WORKERS=${limits.MAX_PARALLEL_WORKERS}, MAX_FIX_ATTEMPTS=${limits.MAX_FIX_ATTEMPTS}\n\nProduce the brain_plan JSON. Set proceed=false only if a product decision is impossible to infer.`;
}

export function specPrompt({ objective, plan, ctx, overview }) {
  return `OBJECTIVE:\n${objective}\n\n## BRAIN PLAN\n${JSON.stringify(plan, null, 2)}\n\n## PROJECT_STATE.md\n${ctx.state}\n\n## DECISIONS (index)\n${ctx.decisions}\n\n## REPOSITORY OVERVIEW\n${truncate(overview, 8000)}\n\nInspect the repository with your read-only tools where needed (existing patterns, interfaces, tests). Then produce the spec JSON.`;
}

export function tasksPlanPrompt({ spec, overview, limits, ctx }) {
  return `## FEATURE SPEC\n${spec.feature_spec_md}\n\n## ACCEPTANCE CRITERIA\n${spec.acceptance_criteria.map((c) => `- ${c}`).join("\n")}\n\n## COMPONENTS TO CHANGE\n${spec.components_to_change.map((c) => `- ${c}`).join("\n") || "- (not specified)"}\n\n## INTERFACES\n${spec.interfaces.map((c) => `- ${c}`).join("\n") || "- (none)"}\n\n## RISKS\n${spec.risks.map((c) => `- ${c}`).join("\n") || "- (none)"}\n\n## REPOSITORY OVERVIEW\n${truncate(overview, 8000)}\n\n## DECISIONS (index)\n${ctx.decisions}\n\n## LIMITS\nAt most ${limits.MAX_TASKS_PER_RUN} tasks. Up to ${limits.MAX_PARALLEL_WORKERS} run in parallel when their allowed_files do not overlap and dependencies allow.\n\nRules: allowed_files are glob patterns relative to the repo root (e.g. "src/screens/onboarding/*", "docs/README.md"). Dependencies reference other tasks by their number (1-based) or exact title. test_commands must be real commands that exist in this repository (or empty). Produce the tasks_plan JSON.`;
}

function fileExcerpt(rel, maxChars) {
  const abs = path.join(ROOT, rel);
  if (!fs.existsSync(abs) || fs.statSync(abs).isDirectory()) return `### ${rel}\n(not found)`;
  return `### ${rel}\n\`\`\`\n${truncate(fs.readFileSync(abs, "utf8"), maxChars)}\n\`\`\``;
}

export function workerPrompt({ task, spec, limits, requiredChanges = [], attempt }) {
  const context = (task.context_files || []).slice(0, 8).map((f) => fileExcerpt(f, limits.MAX_CONTEXT_FILE_CHARS)).join("\n\n");
  const fix = requiredChanges.length ? `\nREQUIRED CHANGES FROM REVIEW (attempt ${attempt}):\n${requiredChanges.map((c) => `- ${c}`).join("\n")}\n` : "";
  return `TASK_ID:\n${task.id}\n\nOBJECTIVE:\n${task.title}\n\nDESCRIPTION:\n${task.description}\n${fix}\nFILES YOU MAY EDIT:\n${task.allowed_files.map((f) => `- ${f}`).join("\n")}\n\nFILES YOU MAY READ:\n- any file in the repository (read-only outside FILES YOU MAY EDIT)\n\nCONTEXT:\n- Feature spec excerpt:\n${truncate(spec?.feature_spec_md || "(no spec)", 4000)}\n\n${context || "(no context files)"}\n\nACCEPTANCE CRITERIA:\n${task.acceptance_criteria.map((c) => `- ${c}`).join("\n")}\n\nTEST COMMANDS:\n${task.test_commands.length ? task.test_commands.map((c) => `- ${c}`).join("\n") : "- (none; verify manually by reading your change)"}\n\nFORBIDDEN:\n${[...task.forbidden, "editing files outside FILES YOU MAY EDIT", "adding dependencies", "git push / reset / history rewrite", "network downloads", "touching secrets, billing, auth, production"].map((c) => `- ${c}`).join("\n")}\n\nDEFINITION OF DONE:\n- every acceptance criterion holds\n- test commands pass\n- only allowed files changed\n- worker_result JSON is accurate\n\nYou are working inside an isolated git worktree at the current directory. Do not commit; the orchestrator commits for you. When finished, output the worker_result JSON.`;
}

export function reviewPrompt({ task, workerResult, testReport, diff, spec, limits }) {
  return `REVIEW TASK ${task.id}: ${task.title}\n\n## TASK\n${task.description}\n\nAllowed files: ${task.allowed_files.join(", ")}\nAcceptance criteria:\n${task.acceptance_criteria.map((c) => `- ${c}`).join("\n")}\n\n## SPEC EXCERPT\n${truncate(spec?.feature_spec_md || "", 3000)}\n\n## WORKER RESULT\n${JSON.stringify(workerResult, null, 2)}\n\n## TEST RESULTS (run by the orchestrator)\n${truncate(testReport, 6000)}\n\n## DIFF\n\`\`\`diff\n${truncate(diff, limits.MAX_DIFF_CHARS)}\n\`\`\`\n\nProduce the review JSON (task_id="${task.id}").`;
}

export function qaPrompt({ spec, tasks, diff, testReport, limits, round }) {
  const taskLines = tasks.map((t) => `- ${t.id} [${t.status}] ${t.title} (review: ${t.review_status || "n/a"}, attempts: ${t.attempts})`).join("\n");
  return `QA ROUND ${round}\n\n## FEATURE SPEC\n${truncate(spec.feature_spec_md, 6000)}\n\n## ACCEPTANCE CRITERIA\n${spec.acceptance_criteria.map((c) => `- ${c}`).join("\n")}\n\n## TASKS\n${taskLines}\n\n## TEST RESULTS (run by the orchestrator on the integrated branch)\n${truncate(testReport, 8000)}\n\n## FULL DIFF (feature branch vs base)\n\`\`\`diff\n${truncate(diff, limits.MAX_DIFF_CHARS)}\n\`\`\`\n\nInspect files with your read-only tools when the diff is not enough. Produce the qa_report JSON. required_changes must be executable by a worker (each with allowed_files).`;
}

export function brainFinalPrompt({ objective, managerSummary, qaReport, ctx }) {
  return `OBJECTIVE:\n${objective}\n\n## MANAGER SUMMARY (compressed)\n${JSON.stringify(managerSummary, null, 2)}\n\n## QA REPORT (summary)\n${JSON.stringify({ decision: qaReport?.decision, summary: qaReport?.summary, unmet: qaReport?.acceptance_criteria_unmet, issues: qaReport?.issues?.slice(0, 10) }, null, 2)}\n\n## CURRENT PROJECT_STATE.md\n${ctx.state}\n\n## CURRENT ROADMAP.md\n${ctx.roadmap}\n\nDecide the final result and rewrite PROJECT_STATE.md (keep it short: current status, features done, in progress, blockers, important debt, pending decisions, next priority; no logs). In roadmap_update put a short Markdown fragment to append to ROADMAP.md or an empty string. Produce the brain_final JSON.`;
}

export function approvalPrompt({ subject, details, ctx }) {
  return `APPROVAL REQUEST\n\nSubject: ${subject}\n\nDetails:\n${details}\n\n## PROJECT_STATE.md\n${ctx.state}\n\n## DECISIONS (index)\n${ctx.decisions}\n\nDecide approve / reject / escalate_to_human. Anything touching production, secrets, billing, payments, external accounts or data deletion MUST be escalate_to_human. Produce the approval JSON.`;
}

export function skillAuditPrompt({ source, cloneDir, metadata, findings }) {
  return `SKILL / REPOSITORY AUDIT\n\nSOURCE: ${source}\nLOCAL CLONE (read-only, do not execute anything from it): ${cloneDir}\n\n## METADATA (collected by the orchestrator)\n${JSON.stringify(metadata, null, 2)}\n\n## AUTOMATED GREP FINDINGS (risky patterns; verify each)\n${findings.length ? findings.map((f) => `- ${f}`).join("\n") : "- (none)"}\n\nRead SKILL.md, README, scripts, package manifests, install scripts, hooks and MCP config in the clone. Classify the trust tier, list security findings with locations, decide the recommendation. Produce the skill_audit JSON.`;
}
