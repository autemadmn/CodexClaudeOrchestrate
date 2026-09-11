import { globsOverlap } from "./util.mjs";

/**
 * Compute execution waves: tasks whose dependencies are DONE and whose allowed_files do not overlap
 * with any other task in the same wave. Returns array of waves (arrays of task ids).
 * Pure function so it can be unit tested. `tasks` must contain only pending tasks (READY/BACKLOG).
 */
export function planWaves(tasks, doneIds = new Set(), maxParallel = 3) {
  const pending = tasks.filter((t) => !doneIds.has(t.id));
  const done = new Set(doneIds);
  const waves = [];
  const conflicts = [];
  const prio = { P0: 0, P1: 1, P2: 2, P3: 3 };
  let guard = 0;
  while (pending.some((t) => !done.has(t.id))) {
    if (++guard > 1000) throw new Error("planWaves: too many iterations");
    const ready = pending.filter((t) => !done.has(t.id) && (t.dependencies || []).every((d) => done.has(d))).sort((a, b) => (prio[a.priority] ?? 9) - (prio[b.priority] ?? 9));
    if (!ready.length) {
      const stuck = pending.filter((t) => !done.has(t.id)).map((t) => t.id);
      return { waves, conflicts, unschedulable: stuck };
    }
    const wave = [];
    for (const t of ready) {
      if (wave.length >= maxParallel) break;
      const clash = wave.find((w) => globsOverlap(w.allowed_files, t.allowed_files));
      if (clash) {
        conflicts.push({ task: t.id, conflicts_with: clash.id, reason: "overlapping allowed_files; serialized" });
        continue;
      }
      wave.push(t);
    }
    waves.push(wave.map((t) => t.id));
    wave.forEach((t) => done.add(t.id));
  }
  return { waves, conflicts, unschedulable: [] };
}
