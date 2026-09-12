import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

let DatabaseSync;
let sqliteError;
try { ({ DatabaseSync } = await import('node:sqlite')); } catch (error) { sqliteError = error; }
const ddl = readFileSync(join(dirname(fileURLToPath(import.meta.url)), '../../Sources/Persistence/Migrations/v1_initial.sql'), 'utf8');

function database() { const db = new DatabaseSync(':memory:'); db.exec(ddl); assert.equal(db.prepare('PRAGMA foreign_keys').get().foreign_keys, 1); return db; }
function seed(db) {
  db.exec("INSERT INTO Vehicle VALUES ('v1','Car'); INSERT INTO Person VALUES ('owner','Owner',1),('p1','P1',0),('p2','P2',0); INSERT INTO \"Group\" VALUES ('g1','Work','2026-01-01'),('g2','Uni','2026-01-02'); INSERT INTO Trip VALUES ('t1','v1','2026-01-01T10:00:00Z',NULL,'active',NULL); INSERT INTO PaymentBatch VALUES ('b1','p1','2026-01-02T10:00:00Z');");
}
const cases = [
  ['amountCents = 0', "INSERT INTO LedgerEntry VALUES ('e','charge','p1','owner',0,'g1','t1',NULL,'2026-01-01')"],
  ['debtorID == creditorID', "INSERT INTO LedgerEntry VALUES ('e','charge','p1','p1',1,'g1','t1',NULL,'2026-01-01')"],
  ['charge con paymentBatchID', "INSERT INTO LedgerEntry VALUES ('e','charge','p1','owner',1,'g1','t1','b1','2026-01-01')"],
  ['payment con tripID', "INSERT INTO LedgerEntry VALUES ('e','payment','p1','owner',1,'g1','t1','b1','2026-01-01')"],
  ['groupID NULL', "INSERT INTO LedgerEntry VALUES ('e','charge','p1','owner',1,NULL,'t1',NULL,'2026-01-01')"],
  ['segundo owner', "INSERT INTO Person VALUES ('owner2','Owner 2',1)"],
  ['segundo viaje active/interrupted', "INSERT INTO Trip VALUES ('t2','v1','2026-01-01T11:00:00Z',NULL,'interrupted',NULL)"],
  ['cargo duplicado por persona+viaje', "INSERT INTO LedgerEntry VALUES ('e1','charge','p1','owner',1,'g1','t1',NULL,'2026-01-01'); INSERT INTO LedgerEntry VALUES ('e2','charge','p1','owner',1,'g2','t1',NULL,'2026-01-01')"],
  ['precio <= 0', "INSERT INTO FuelPrice VALUES ('fp','v1',0,'2026-01-01')"],
  ['consumo <= 0', "INSERT INTO ConsumptionProfile VALUES ('cp','v1',0)"],
  ['endedAt < startedAt', "INSERT INTO Trip VALUES ('bad','v1','2026-01-02T00:00:00Z','2026-01-01T00:00:00Z','completed',NULL)"],
  ['FK inexistente', "INSERT INTO Trip VALUES ('bad','missing','2026-01-01',NULL,'completed',NULL)"]
];
if (sqliteError) {
  for (const [name] of cases) test(`schema: ${name}`, t => t.skip(`node:sqlite no disponible: ${sqliteError.message}`));
} else {
  test('PRAGMA foreign_keys está activo', () => assert.equal(database().prepare('PRAGMA foreign_keys').get().foreign_keys, 1));
  test('control positivo: inserción válida', () => { const db = database(); seed(db); db.exec("INSERT INTO LedgerEntry VALUES ('valid','charge','p1','owner',1,'g1','t1',NULL,'2026-01-01')"); assert.equal(db.prepare('SELECT count(*) AS n FROM LedgerEntry').get().n, 1); });
  test('control positivo: segundo Trip completed', () => { const db = database(); seed(db); db.exec("INSERT INTO Trip VALUES ('t2','v1','2026-01-02T10:00:00Z','2026-01-02T11:00:00Z','completed',NULL)"); });
  test('control positivo: cargo de otra persona en el mismo viaje', () => { const db = database(); seed(db); db.exec("INSERT INTO LedgerEntry VALUES ('other','charge','p2','owner',1,'g1','t1',NULL,'2026-01-01')"); });
  test('Group.createdAt existe y es NOT NULL', () => { const db = database(); assert.throws(() => db.exec("INSERT INTO \"Group\" (id,name) VALUES ('bad','Bad')"), /constraint|NOT NULL/i); });
  for (const [name, sql] of cases) test(`schema rechaza ${name}`, () => { const db=database(); seed(db); assert.throws(() => db.exec(sql), /constraint|FOREIGN KEY|UNIQUE|CHECK/i); });
  test('borrar Trip con cargos está restringido', () => { const db = database(); seed(db); db.exec("INSERT INTO LedgerEntry VALUES ('charge','charge','p1','owner',1,'g1','t1',NULL,'2026-01-01')"); assert.throws(() => db.exec("DELETE FROM Trip WHERE id='t1'"), /constraint|FOREIGN KEY/i); });
}
