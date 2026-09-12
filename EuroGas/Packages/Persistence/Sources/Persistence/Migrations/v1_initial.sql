PRAGMA foreign_keys = ON;

CREATE TABLE Vehicle (
    id TEXT PRIMARY KEY,
    displayName TEXT NOT NULL,
    energyKind TEXT NOT NULL CHECK (energyKind IN ('gasoline','diesel','lpg','hev','bev')),
    activeProfileID TEXT,
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL
);

CREATE TABLE ConsumptionProfile (
    id TEXT PRIMARY KEY,
    vehicleID TEXT NOT NULL REFERENCES Vehicle(id),
    source TEXT NOT NULL CHECK (source IN ('userEntered','official','calibrated','bodyDefault')),
    consumptionPer100 TEXT NOT NULL CHECK (CAST(consumptionPer100 AS REAL) > 0),
    realWorldFactor TEXT NOT NULL CHECK (CAST(realWorldFactor AS REAL) > 0),
    unit TEXT NOT NULL CHECK (unit IN ('litresPer100KM','kWhPer100KM')),
    sourceReference TEXT,
    testCycle TEXT,
    createdAt TEXT NOT NULL
);

CREATE TABLE FuelPrice (
    id TEXT PRIMARY KEY,
    energyKind TEXT NOT NULL CHECK (energyKind IN ('gasoline','diesel','lpg','hev','bev')),
    unitPriceMilliEUR INTEGER NOT NULL CHECK (unitPriceMilliEUR > 0),
    currency TEXT NOT NULL DEFAULT 'EUR' CHECK (currency = 'EUR'),
    source TEXT NOT NULL CHECK (source IN ('manual','suggested','stationFuture')),
    effectiveFrom TEXT NOT NULL
);

CREATE TABLE Person (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    emoji TEXT,
    isOwner INTEGER NOT NULL DEFAULT 0 CHECK (isOwner IN (0,1)),
    createdAt TEXT NOT NULL,
    archivedAt TEXT
);
CREATE UNIQUE INDEX one_owner ON Person(isOwner) WHERE isOwner = 1;

CREATE TABLE "Group" (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL CHECK (length(trim(name)) > 0),
    emoji TEXT,
    isUngrouped INTEGER NOT NULL DEFAULT 0 CHECK (isUngrouped IN (0,1)),
    defaultSplitRule TEXT NOT NULL DEFAULT 'everyone' CHECK (defaultSplitRule IN ('everyone','passengersOnly')),
    createdAt TEXT NOT NULL,
    archivedAt TEXT
);
CREATE UNIQUE INDEX one_ungrouped ON "Group"(isUngrouped) WHERE isUngrouped = 1;

CREATE TABLE GroupMember (
    groupID TEXT NOT NULL REFERENCES "Group"(id),
    personID TEXT NOT NULL REFERENCES Person(id),
    sortOrder INTEGER NOT NULL CHECK (sortOrder >= 0),
    PRIMARY KEY(groupID, personID),
    UNIQUE(groupID, sortOrder)
);

CREATE TABLE Trip (
    id TEXT PRIMARY KEY,
    vehicleID TEXT NOT NULL REFERENCES Vehicle(id),
    status TEXT NOT NULL CHECK(status IN ('planned','active','interrupted','completed')),
    startedAt TEXT NOT NULL,
    endedAt TEXT,
    accountingMonth TEXT NOT NULL,
    accountingTimeZone TEXT NOT NULL DEFAULT 'Europe/Madrid',
    acceptedDistanceMeters REAL NOT NULL DEFAULT 0 CHECK (acceptedDistanceMeters >= 0),
    gapDistanceMeters REAL NOT NULL DEFAULT 0 CHECK (gapDistanceMeters >= 0),
    movingSeconds REAL NOT NULL DEFAULT 0 CHECK (movingSeconds >= 0),
    pausedSeconds REAL NOT NULL DEFAULT 0 CHECK (pausedSeconds >= 0),
    estimatedEnergy TEXT NOT NULL DEFAULT '0',
    energyCostCents INTEGER NOT NULL DEFAULT 0 CHECK (energyCostCents >= 0),
    profileConsumptionPer100 TEXT NOT NULL,
    profileRealWorldFactor TEXT NOT NULL,
    fuelPriceMilliEUR INTEGER NOT NULL CHECK (fuelPriceMilliEUR > 0),
    costModelVersion INTEGER NOT NULL,
    totalPeople INTEGER NOT NULL CHECK (totalPeople BETWEEN 1 AND 8),
    splitRule TEXT NOT NULL CHECK (splitRule IN ('everyone','passengersOnly')),
    groupID TEXT NOT NULL REFERENCES "Group"(id),
    accountingMode TEXT NOT NULL CHECK (accountingMode IN ('anonymous','named')),
    origin TEXT,
    destination TEXT,
    qualityFlags TEXT NOT NULL DEFAULT '[]',
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 1 CHECK (revision > 0),
    CHECK(endedAt IS NULL OR endedAt >= startedAt)
);
CREATE UNIQUE INDEX one_active_trip ON Trip((1)) WHERE status IN ('active','interrupted');
CREATE INDEX trip_started_at ON Trip(startedAt);
CREATE INDEX trip_status ON Trip(status);

CREATE TABLE TripParticipant (
    tripID TEXT NOT NULL REFERENCES Trip(id) ON DELETE CASCADE,
    personID TEXT NOT NULL REFERENCES Person(id),
    role TEXT NOT NULL CHECK (role IN ('driver','passenger')),
    sortOrder INTEGER NOT NULL CHECK (sortOrder >= 0),
    PRIMARY KEY(tripID, personID),
    UNIQUE(tripID, sortOrder)
);

CREATE TABLE ManualExpense (
    id TEXT PRIMARY KEY,
    tripID TEXT NOT NULL REFERENCES Trip(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('toll','parking','other')),
    amountCents INTEGER NOT NULL CHECK(amountCents > 0),
    createdAt TEXT NOT NULL,
    updatedAt TEXT NOT NULL
);

CREATE TABLE PaymentBatch (
    id TEXT PRIMARY KEY,
    personID TEXT NOT NULL REFERENCES Person(id),
    occurredAt TEXT NOT NULL,
    note TEXT,
    createdAt TEXT NOT NULL
);

CREATE TABLE LedgerEntry (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL CHECK(kind IN ('charge','payment')),
    debtorID TEXT NOT NULL REFERENCES Person(id),
    creditorID TEXT NOT NULL REFERENCES Person(id),
    amountCents INTEGER NOT NULL CHECK(amountCents > 0),
    groupID TEXT NOT NULL REFERENCES "Group"(id),
    tripID TEXT REFERENCES Trip(id) ON DELETE RESTRICT,
    paymentBatchID TEXT REFERENCES PaymentBatch(id) ON DELETE RESTRICT,
    occurredAt TEXT NOT NULL,
    accountingMonth TEXT NOT NULL,
    createdAt TEXT NOT NULL,
    note TEXT,
    CHECK(debtorID <> creditorID),
    CHECK((kind = 'charge' AND tripID IS NOT NULL AND paymentBatchID IS NULL) OR (kind = 'payment' AND paymentBatchID IS NOT NULL AND tripID IS NULL))
);
CREATE UNIQUE INDEX one_charge_per_person_trip ON LedgerEntry(debtorID, tripID) WHERE kind = 'charge';
CREATE INDEX ledger_person_group_date ON LedgerEntry(debtorID, groupID, occurredAt);
CREATE INDEX ledger_creditor_group_date ON LedgerEntry(creditorID, groupID, occurredAt);
CREATE INDEX ledger_trip ON LedgerEntry(tripID);

CREATE TABLE ActiveTripState (
    tripID TEXT PRIMARY KEY REFERENCES Trip(id) ON DELETE CASCADE,
    schemaVersion INTEGER NOT NULL DEFAULT 1,
    sequence INTEGER NOT NULL CHECK (sequence >= 0),
    savedAt TEXT NOT NULL,
    state TEXT NOT NULL CHECK (state IN ('starting','tracking','paused','interrupted','finishing')),
    lastAcceptedFixJSON TEXT,
    accumulatorJSON TEXT NOT NULL,
    lastMovementAt TEXT,
    unmeasuredIntervalFlag INTEGER NOT NULL DEFAULT 0 CHECK (unmeasuredIntervalFlag IN (0,1)),
    liveActivityID TEXT
);
