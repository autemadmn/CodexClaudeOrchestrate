#!/usr/bin/env node
import { main } from "../orchestrator/cli.mjs";
main(process.argv.slice(2)).then((code) => process.exit(code ?? 0)).catch((err) => {
  console.error(`agents: ${err?.message ?? err}`);
  if (process.env.AGENTS_DEBUG) console.error(err?.stack);
  process.exit(1);
});
