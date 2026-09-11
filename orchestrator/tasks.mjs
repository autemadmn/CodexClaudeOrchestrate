import { TASKS_FILE, readJson, writeJson, nowIso } from "./util.mjs";
import { loadSchema } from "./providers.mjs";
import { assertValid } from "./validate.mjs";

export const STATES = ["BACKLOG", "READY", "IN_PROGRESS", "BLOCKED", "REVIEW", "QA", "FAILED", "DONE"];

export function loadTasks() {
  return readJson(TASKS_FILE, { next_id: 1, tasks: [] });
}

export function saveTasks(store) {
  store.updated_at = nowIso();
  writeJson(TASKS_FILE, store);
}

export function nextTaskId(store) {
  const id = `TASK-${String(store.next_id).padStart(3, "0")}`;
  store.next_id += 1;
  return id;
}

export function newTask(store, fields) {
  const task = {
    id: nextTaskId(store),
    title: fields.title,
    description: fields.description,
    parent_task: fields.parent_task ?? null,
    assigned_manager: fields.assigned_manager ?? "implementation-manager",
    assigned_worker: null,
    status: "BACKLOG",
    priority: fields.priority ?? "P2",
    dependencies: fields.dependencies ?? [],
    allowed_files: fields.allowed_files?.length ? fields.allowed_files : ["."],
    context_files: fields.context_files ?? [],
    acceptance_criteria: fields.acceptance_criteria?.length ? fields.acceptance_criteria : ["Task described above is implemented"],
    test_commands: fields.test_commands ?? [],
    forbidden: fields.forbidden ?? [],
    approval_category: fields.approval_category ?? "AUTO_APPROVED",
    branch: null,
    worktree: null,
    attempts: 0,
    result: null,
    review_status: null,
    qa_status: null,
    blockers: [],
    run_id: fields.run_id ?? null,
    created_at: nowIso(),
  };
  assertValid(loadSchema("task"), stripExtra(task), `task ${task.id}`);
  store.tasks.push(task);
  return task;
}

function stripExtra(task) {
  const { run_id, created_at, updated_at, ...rest } = task;
  return rest;
}

export function setStatus(task, status, note) {
  if (!STATES.includes(status)) throw new Error(`invalid status ${status}`);
  task.status = status;
  task.updated_at = nowIso();
  if (note) task.blockers = [...new Set([...(task.blockers || []), note])];
}

export function getTask(store, id) {
  const t = store.tasks.find((x) => x.id === id);
  if (!t) throw new Error(`task ${id} not found`);
  return t;
}

export function tasksForRun(store, runId) {
  return store.tasks.filter((t) => t.run_id === runId);
}

/** Resolve dependency references given by title or index ("1", "Mock task 1", "TASK-003") into task ids. */
export function resolveDependencyRefs(planTasks, created) {
  for (let i = 0; i < planTasks.length; i++) {
    const deps = [];
    for (const ref of planTasks[i].dependencies || []) {
      const r = String(ref).trim();
      let match = created.find((t) => t.id === r);
      if (!match) match = created.find((t) => t.title.toLowerCase() === r.toLowerCase());
      if (!match && /^\d+$/.test(r)) match = created[Number(r) - 1];
      if (!match) {
        const m = r.match(/(\d+)/);
        if (m) match = created[Number(m[1]) - 1];
      }
      if (match && match.id !== created[i].id) deps.push(match.id);
    }
    created[i].dependencies = [...new Set(deps)];
  }
}
