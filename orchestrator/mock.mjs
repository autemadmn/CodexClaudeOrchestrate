/**
 * Deterministic mock provider for routing/conflict/escalation tests. No network, no cost.
 * Scenario via env AGENTS_MOCK_SCENARIO:
 *   default          -> everything approves first time
 *   qa_reject_once   -> QA requests changes on first pass, approves on second
 *   review_reject_once -> implementation review requests changes once
 *   worker_fails     -> worker always reports failed (exercises MAX_FIX_ATTEMPTS + escalation)
 *   conflict         -> two tasks with overlapping allowed_files (exercises serialization)
 *   escalation       -> a task that adds a dependency (brain approval) and one touching billing (human approval)
 */
import fs from "node:fs";
import path from "node:path";

const counters = {};
function bump(key) {
  counters[key] = (counters[key] || 0) + 1;
  return counters[key];
}
export function resetMockCounters() {
  for (const k of Object.keys(counters)) delete counters[k];
}

export async function mockCall({ label, role, prompt, schemaName, cwd, opts }) {
  const scenario = process.env.AGENTS_MOCK_SCENARIO || "default";
  const out = (output) => ({ output, cost_usd: 0, turns: 1, models: ["mock"], denials: [], stderr: "" });
  const taskId = (prompt.match(/TASK_ID:\s*(TASK-\d+)/) || [])[1] || "TASK-000";

  switch (schemaName) {
    case "brain_plan":
      return out({ understanding: "Mock understanding of objective", scope: ["mock scope"], out_of_scope: [], priorities: ["p1"], managers: ["product-architect-manager", "implementation-manager", "qa-manager"], constraints: [], proceed: true, questions_for_human: [], risk_level: "low" });
    case "spec":
      return out({ feature_name: "mock-feature", feature_spec_md: "# Mock feature\n\nAppend a marker line to docs/MOCK.md.", acceptance_criteria: ["docs/MOCK.md contains the marker line"], components_to_change: ["docs/MOCK.md"], interfaces: [], dependencies_between_components: [], risks: [], technical_debt_detected: [], decisions: [{ title: "Use mock docs marker", context: "test", decision: "append marker", reason: "deterministic", alternatives: ["none"], consequences: "none" }], needs_brain_decision: [], requires_human_approval: false, human_approval_reasons: [] });
    case "tasks_plan": {
      const base = (n, extra = {}) => ({ title: `Mock task ${n}`, description: `Append marker line ${n} to the target file so the pipeline is exercised.`, priority: "P1", dependencies: [], allowed_files: [`docs/MOCK-${n}.md`], context_files: [], acceptance_criteria: [`docs/MOCK-${n}.md contains marker ${n}`], test_commands: [], forbidden: ["do not touch other files"], approval_category: "AUTO_APPROVED", ...extra });
      let tasks = [base(1), base(2)];
      if (scenario === "conflict") tasks = [base(1, { allowed_files: ["docs/*.md"] }), base(2, { allowed_files: ["docs/MOCK-2.md"] }), base(3)];
      if (scenario === "escalation") tasks = [base(1), base(2, { allowed_files: ["package.json"], title: "Add dependency", description: "Add a new dependency to package.json (mock)" }), base(3, { allowed_files: ["src/billing/charge.js"], title: "Change billing", description: "Modify production billing charge flow (mock)" })];
      return out({ tasks, parallelization_notes: "mock", risks: [], needs_escalation: false, escalation_reason: "" });
    }
    case "worker_result": {
      const n = bump(`worker:${taskId}`);
      const allowed = (prompt.match(/FILES YOU MAY EDIT:\n([\s\S]*?)\n\n/) || [])[1]?.split("\n").map((s) => s.replace(/^- /, "").trim()).filter(Boolean) || [];
      let target = allowed[0] || "docs/MOCK.md";
      if (/[*?]/.test(target)) target = target.replace(/\*.*$/, "MOCK-glob.md");
      if (scenario === "worker_violates_files") target = ".env";
      if (scenario === "worker_fails") return out({ task_id: taskId, status: "failed", files_changed: [], tests_run: [], tests_passed: false, issues: ["mock failure"], summary: "mock worker failed on purpose", needs_escalation: false, escalation_reason: "" });
      const file = path.join(cwd, target);
      fs.mkdirSync(path.dirname(file), { recursive: true });
      fs.appendFileSync(file, `marker ${taskId} attempt ${n}\n`);
      return out({ task_id: taskId, status: "completed", files_changed: [target], tests_run: [], tests_passed: true, issues: [], summary: `mock worker appended marker (attempt ${n})`, needs_escalation: false, escalation_reason: "" });
    }
    case "review": {
      const n = bump(`review:${taskId}`);
      const reject = scenario === "review_reject_once" && n === 1;
      return out({ task_id: taskId, decision: reject ? "request_changes" : "approve", issues: reject ? ["mock: marker missing suffix"] : [], required_changes: reject ? ["append one more marker line"] : [], summary: reject ? "mock review requested changes" : "mock review approved" });
    }
    case "qa_report": {
      const n = bump("qa");
      const reject = scenario === "qa_reject_once" && n === 1;
      return out({ decision: reject ? "request_changes" : "approve", acceptance_criteria_met: reject ? [] : ["all"], acceptance_criteria_unmet: reject ? ["marker count"] : [], issues: reject ? ["mock QA: needs a second marker"] : [], edge_cases_checked: ["empty file"], regressions_suspected: [], required_changes: reject ? [{ title: "Add second marker", description: "Append a second marker line to docs/MOCK-1.md", allowed_files: ["docs/MOCK-1.md"], acceptance_criteria: ["two marker lines"], test_commands: [] }] : [], definition_of_done_met: !reject, summary: reject ? "QA requested changes" : "QA approved" });
    }
    case "brain_final":
      return out({ objective: "mock", result: /BLOCKED|FAILED/.test(prompt) && !/tasks_failed": 0/.test(prompt) ? "PARTIAL" : "SUCCESS", completed: ["mock"], failed: [], blockers: [], decisions: [], next_recommended_action: "nothing (mock)", project_state_md: "# PROJECT STATE (mock)\n\nUpdated by mock brain.\n", roadmap_update: "" });
    case "approval":
      return out({ subject: "mock", decision: scenario === "escalation" ? "approve" : "approve", reason: "mock approval", conditions: [] });
    case "skill_audit":
      return out({ skill: "mock-skill", source: "mock/mock", author: "mock", purpose: "test", trust_tier: 2, files_reviewed: ["SKILL.md"], permissions: "none", network_access: "none", filesystem_access: "none", shell_commands: "none", security_findings: [], quality_findings: [], why_this_one: "mock", alternatives_considered: [], recommendation: "needs_brain_approval", recommendation_reason: "mock tier 2" });
    default:
      return out(`mock text for ${label}`);
  }
}
