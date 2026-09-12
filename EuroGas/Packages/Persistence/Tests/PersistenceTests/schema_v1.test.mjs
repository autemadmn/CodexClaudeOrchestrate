import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

let DatabaseSync;
let sqliteError;
try { ({ DatabaseSync } = await import('node:sqlite')); } catch (error) { sqliteError = error; }
const ddlPath = join(dirname(fileURLToPath(import.meta.url)), '../../Sources/Persistence/Migrations/v1_initial.sql');
const ddl = readFileSync(ddlPath, 'utf8');

function database() {
  const db = new DatabaseSync(':memory:');
  db.exec(ddl);
  assert.equal(db.prepare('PRAGMA foreign_keys').get().foreign_keys, 1);
  return db;
}

function seed(db) {
  db.exec(`
    INSERT INTO Vehicle (id,displayName,energyKind,createdAt,updatedAt) VALUES ('v1','Car','gasoline','2026-01-01','2026-01-01');
    INSERT INTO Person (id,name,isOwner,createdAt) VALUES ('owner','Owner',1,'2026-01-01'),('p1','P1',0,'2026-01-01'),('p2','P2',0,'2026-01-01');
    INSERT INTO "Group" (id,name,isUngrouped,createdAt) VALUES ('g1','Work',0,'2026-01-01'),('g2','Uni',0,'2026-01-02');
    INSERT INTO Trip (id,vehicleID,status,startedAt,accountingMonth,profileConsumptionPer100,profileRealWorldFactor,fuelPriceMilliEUR,costModelVersion,totalPeople,splitRule,groupID,accountingMode,createdAt,updatedAt)
      VALUES ('t1','v1','active','2026-01-01T10:00:00Z','2026-01','6.0','1.0',1499,1,2,'everyone','g1','named','2026-01-01','2026-01-01');
    INSERT INTO PaymentBatch (id,personID,occurredAt,createdAt) VALUES ('b1','p1','2026-01-02T10:00:00Z','2026-01-02T10:00:00Z');
  `);
}

function charge(id = 'e', debtor = 'p1', amount = 1, group = 'g1', trip = 't1') {
  return `INSERT INTO LedgerEntry (id,kind,debtorID,creditorID,amountCents,groupID,tripID,occurredAt,accountingMonth,createdAt) VALUES ('${id}','charge','${debtor}','owner',${amount},'${group}','${trip}','2026-01-01','2026-01','2026-01-01')`;
}

const cases = [
  ['amountCents = 0', charge('e', 'p1', 0)],
  ['debtorID == creditorID', "INSERT INTO LedgerEntry (id,kind,debtorID,creditorID,amountCents,groupID,tripID,occurredAt,accountingMonth,createdAt) VALUES ('e','charge','p1','p1',1,'g1','t1','2026-01-01','2026-01','2026-01-01')"],
  ['charge con paymentBatchID', "INSERT INTO LedgerEntry (id,kind,debtorID,creditorID,amountCents,groupID,tripID,paymentBatchID,occurredAt,accountingMonth,createdAt) VALUES ('e','charge','p1','owner',1,'g1','t1','b1','2026-01-01','2026-01','2026-01-01')"],
  ['payment con tripID', "INSERT INTO LedgerEntry (id,kind,debtorID,creditorID,amountCents,groupID,tripID,paymentBatchID,occurredAt,accountingMonth,createdAt) VALUES ('e','payment','p1','owner',1,'g1','t1','b1','2026-01-01','2026-01','2026-01-01')"],
  ['groupID NULL', "INSERT INTO LedgerEntry (id,kind,debtorID,creditorID,amountCents,groupID,tripID,occurredAt,accountingMonth,createdAt) VALUES ('e','charge','p1','owner',1,NULL,'t1','2026-01-01','2026-01','2026-01-01')"],
  ['segundo owner', "INSERT INTO Person (id,name,isOwner,createdAt) VALUES ('owner2','Owner 2',1,'2026-01-01')"],
  ['segundo viaje active/interrupted', "INSERT INTO Trip (id,vehicleID,status,startedAt,accountingMonth,profileConsumptionPer100,profileRealWorldFactor,fuelPriceMilliEUR,costModelVersion,totalPeople,splitRule,groupID,accountingMode,createdAt,updatedAt) VALUES ('t2','v1','interrupted','2026-01-01T11:00:00Z','2026-01','6','1',1499,1,1,'everyone','g1','anonymous','2026-01-01','2026-01-01')"],
  ['cargo duplicado por persona+viaje', `${charge('e1')}; ${charge('e2', 'p1', 1, 'g2')}`],
  ['precio <= 0', "INSERT INTO FuelPrice (id,energyKind,unitPriceMilliEUR,source,effectiveFrom) VALUES ('fp','gasoline',0,'manual','2026-01-01')"],
  ['consumo <= 0', "INSERT INTO ConsumptionProfile (id,vehicleID,source,consumptionPer100,realWorldFactor,unit,createdAt) VALUES ('cp','v1','userEntered','0','1','litresPer100KM','2026-01-01')"],
  ['endedAt < startedAt', "INSERT INTO Trip (id,vehicleID,status,startedAt,endedAt,accountingMonth,profileConsumptionPer100,profileRealWorldFactor,fuelPriceMilliEUR,costModelVersion,totalPeople,splitRule,groupID,accountingMode,createdAt,updatedAt) VALUES ('bad','v1','completed','2026-01-02','2026-01-01','2026-01','6','1',1499,1,1,'everyone','g1','anonymous','2026-01-01','2026-01-01')"],
  ['FK inexistente', "INSERT INTO Trip (id,vehicleID,status,startedAt,accountingMonth,profileConsumptionPer100,profileRealWorldFactor,fuelPriceMilliEUR,costModelVersion,totalPeople,splitRule,groupID,accountingMode,createdAt,updatedAt) VALUES ('bad','missing','completed','2026-01-01','2026-01','6','1',1499,1,1,'everyone','g1','anonymous','2026-01-01','2026-01-01')"]
];

if (sqliteError) {
  for (const [name] of cases) test(`schema: ${name}`, t => t.skip(`node:sqlite no disponible: ${sqliteError.message}`));
} else {
  test('PRAGMA foreign_keys está activo', () => assert.equal(database().prepare('PRAGMA foreign_keys').get().foreign_keys, 1));
  test('control positivo: inserción válida', () => { const db = database(); seed(db); db.exec(charge('valid')); assert.equal(db.prepare('SELECT count(*) AS n FROM LedgerEntry').get().n, 1); });
  test('control positivo: segundo Trip completed', () => { const db = database(); seed(db); db.exec("INSERT INTO Trip (id,vehicleID,status,startedAt,endedAt,accountingMonth,profileConsumptionPer100,profileRealWorldFactor,fuelPriceMilliEUR,costModelVersion,totalPeople,splitRule,groupID,accountingMode,createdAt,updatedAt) VALUES ('t2','v1','completed','2026-01-02T10:00:00Z','2026-01-02T11:00:00Z','2026-01','6','1',1499,1,1,'everyone','g1','anonymous','2026-01-02','2026-01-02')"); });
  test('control positivo: cargo de otra persona en el mismo viaje', () => { const db = database(); seed(db); db.exec(charge('other', 'p2')); });
  test('Group.createdAt existe y es NOT NULL', () => { const db = database(); assert.throws(() => db.exec("INSERT INTO \"Group\" (id,name) VALUES ('bad','Bad')"), /constraint|NOT NULL/i); });
  for (const [name, sql] of cases) test(`schema rechaza ${name}`, () => { const db = database(); seed(db); assert.throws(() => db.exec(sql), /constraint|FOREIGN KEY|UNIQUE|CHECK/i); });
  test('borrar Trip con cargos está restringido', () => { const db = database(); seed(db); db.exec(charge('charge')); assert.throws(() => db.exec("DELETE FROM Trip WHERE id='t1'"), /constraint|FOREIGN KEY/i); });
}
