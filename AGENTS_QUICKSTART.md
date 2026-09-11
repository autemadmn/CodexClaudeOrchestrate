# AGENTS QUICKSTART (guía para humanos, sin conocimientos de DevOps)

Este repositorio tiene un "equipo" de agentes de IA que trabaja por ti:

```
TÚ  →  BRAIN (director)  →  MANAGERS (Claude Opus)  →  WORKERS (Codex)  →  REVIEW  →  QA  →  BRAIN  →  resumen
```

Tú solo das un objetivo. El sistema planifica, reparte tareas, implementa, prueba, revisa y te devuelve un resumen.

## 1. Cómo iniciar (una sola vez)

```bash
npm install            # instala Codex CLI en el proyecto (versión fijada)
npx codex login        # opcional pero recomendado: activa Codex (GPT Astra / Luna). Abre el navegador.
claude auth login      # si Claude Code aún no está autenticado
npx agents doctor      # comprueba que todo está listo
```

Si `doctor` dice "codex auth ⚠ not logged in", el sistema sigue funcionando: usa Claude para el Brain y los Workers hasta que hagas `npx codex login`.

> Puedes escribir `npx agents ...` o, si prefieres el comando corto `agents`, ejecuta una vez `npm link` en la carpeta del proyecto.

## 2. Cómo dar una tarea

Asegúrate de tener el trabajo guardado (`git status` limpio) y ejecuta:

```bash
npx agents run "Implementa el sistema Pro de la aplicación"
```

Qué pasa entonces:
1. Se crea una rama `feature/<objetivo>-<id>` (tu rama actual no se toca).
2. El Brain entiende el objetivo y decide prioridades.
3. El manager de producto/arquitectura escribe la especificación y las decisiones (ADR en `.ai/DECISIONS/`).
4. El manager de implementación divide el trabajo en tareas pequeñas (`.ai/TASKS.json`).
5. Los workers implementan cada tarea en su propia carpeta aislada (`.worktrees/TASK-xxx`), hasta 3 en paralelo.
6. Cada cambio se prueba, se revisa y se fusiona en la rama `feature/...`.
7. QA revisa todo el conjunto; si pide cambios, se crean tareas de corrección (máximo 3 rondas).
8. El Brain decide SUCCESS / PARTIAL / BLOCKED, actualiza `.ai/PROJECT_STATE.md` y te muestra el resumen.

Al final tú revisas la rama `feature/...` y la fusionas en `main` cuando quieras (`git merge` o pull request).

## 3. Cómo mirar el estado

```bash
npx agents status          # milestone, tareas abiertas, bloqueos, último run, modelos
npx agents tasks           # lista de tareas con su estado
npx agents logs            # eventos del último run + resumen final
npx agents logs <run-id> --calls   # además lista cada llamada a un agente (guardadas en .ai/RUNS/<run-id>/calls/)
```

## 4. Cómo parar

Desde otra terminal:

```bash
npx agents stop            # para el run en curso de forma limpia (o Ctrl+C en la terminal del run)
npx agents resume          # continúa más tarde donde se quedó
```

## 5. Cómo aprobar acciones sensibles

Algunas cosas nunca se hacen solas: producción, secretos, pagos/billing, cuentas externas, borrado de datos, infraestructura crítica. Cuando el sistema las detecta, se para y te dice qué aprobar:

```bash
npx agents approve TASK-007       # apruebas una tarea bloqueada
npx agents approve <run-id>       # apruebas una especificación completa
npx agents resume                 # y sigue
```

Las dependencias nuevas, migraciones de base de datos, cambios de arquitectura o de auth las aprueba el Brain automáticamente (o los escala a ti si duda).

## 6. Cómo ver los logs

Todo queda en `.ai/RUNS/<run-id>/`:

| Archivo | Qué es |
|---|---|
| `input.json` | objetivo y modelos usados |
| `plan.json` | plan del Brain |
| `spec.md` / `spec.json` | especificación del manager de producto |
| `tasks.json` | tareas creadas |
| `tests-*.txt` | salida de los comandos de test |
| `qa-report.json` | veredicto de QA |
| `manager-summary.json` | resumen comprimido enviado al Brain |
| `final-summary.md` | resultado final legible |
| `events.jsonl` | cronología de eventos |
| `calls/` | entrada/salida de cada llamada a un agente (sin secretos) |

## 7. Skills externas (solo managers)

```bash
npx agents skills list                                   # registro de skills aprobadas
npx agents skills audit owner/repo [--path skills/x]     # el Skill Curator (Claude Opus) audita y clasifica (tier 0-3)
npx agents skills approve <name> [--install]             # aprueba (tier 2 requiere aprobación del Brain) e instala en .claude/skills/
```

Los workers nunca instalan ni modifican skills.

## 8. Cambiar modelos

Edita `.ai/config.json` (o usa variables de entorno como `MODEL_WORKER=gpt-5.6-terra`). Por defecto:

| Rol | Preferido (Codex logueado) | Fallback (sin Codex) |
|---|---|---|
| Brain | `gpt-6-astra` (high) | `claude-opus-5` |
| Managers | `claude-opus-5` (high) | — |
| Workers | `gpt-5.6-luna` (medium) | `claude-sonnet-5` |

## Windows

- Funciona con PowerShell o cmd: los comandos de test de cada tarea se ejecutan con `cmd.exe`, así que escríbelos como en Windows (`npm test`, `npx vitest run`, …). En Linux/macOS se usan con `bash`.
- Requisitos: Git para Windows (los workers usan `git worktree`), Node 22+, Claude Code CLI y `npm install` (instala `codex.exe` en `node_modules`).
- Si `agents doctor` muestra `claude flags ⚠`, tu Claude CLI es anterior y no admite `--permission-prompts`; el sistema lo omite automáticamente y sigue aplicando la lista de herramientas permitidas/denegadas del worker.

## Problemas frecuentes

- **"Working tree is not clean"**: guarda tus cambios (`git add -A && git commit -m "wip"`) y vuelve a lanzar.
- **"Repository has no commits yet"**: haz un primer commit.
- **Se queda parado con "PAUSED"**: lee el motivo en `npx agents status` y aprueba o corrige.
- **Coste**: cada run tiene un tope (`MAX_BUDGET_USD_PER_RUN`, 25 $ por defecto) y cada llamada a Claude un tope propio. Los costes de Codex no se estiman (depende de tu plan).
