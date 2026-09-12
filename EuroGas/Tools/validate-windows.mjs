import { readFileSync, readdirSync, statSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const euroGas = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const repo = resolve(euroGas, '..');

function walk(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const full = join(directory, entry.name);
    return entry.isDirectory() ? walk(full) : [full];
  });
}

function assert(condition, message, errors) { if (!condition) errors.push(message); }

function plistLooksWellFormed(text) {
  if (!text.includes('<?xml') || !/<plist\b/.test(text) || !text.includes('</plist>')) return false;
  const stack = [];
  for (const token of text.matchAll(/<(\/)?(dict|array)(\s*)\/?\s*>/g)) {
    const closing = Boolean(token[1]);
    const selfClosing = token[0].includes('/>');
    if (selfClosing) continue;
    if (!closing) stack.push(token[2]);
    else if (stack.pop() !== token[2]) return false;
  }
  return stack.length === 0;
}

export function validate() {
  const errors = [];
  const required = [
    'EuroGas.xcodeproj/project.pbxproj',
    'EuroGas.xcodeproj/xcshareddata/xcschemes/EuroGas.xcscheme',
    'ProjectDefinition.json',
    'Config/Project.xcconfig',
    'App/EuroGasApp.swift', 'App/AppContainer.swift', 'App/RootView.swift', 'App/AppEnvironment.swift',
    'App/Features/Onboarding/OnboardingView.swift', 'App/Features/Drive/DriveView.swift',
    'App/Features/Plan/PlanViewModel.swift', 'App/Features/Trips/TripsView.swift',
    'App/Features/Accounts/AccountsView.swift', 'App/Features/People/PeopleView.swift',
    'App/Features/Paywall/PaywallView.swift', 'App/Features/Settings/SettingsView.swift',
    'App/Services/Trip/TripController.swift', 'App/Services/Location/AppleLocationProvider.swift',
    'App/Services/Routing/AppleRoutingService.swift', 'App/Services/LiveActivity/ActivityKitLiveActivityService.swift',
    'App/Services/Ledger/LedgerService.swift', 'App/Services/Store/StoreKitPurchaseAccess.swift',
    'App/Services/Backup/LocalBackupService.swift', 'App/Resources/Localizable.xcstrings',
    'App/Resources/PrivacyInfo.xcprivacy', 'App/Resources/EuroGas.storekit', 'Widgets/TripLiveActivity.swift',
    'Packages/CostCore/Package.swift', 'Packages/Persistence/Package.swift', 'Packages/EuroGasShared/Package.swift',
    'Packages/Persistence/Sources/Persistence/Migrations/v1_initial.sql'
  ];
  for (const item of required) assert(statSafe(join(euroGas, item)), `Falta ${item}`, errors);

  for (const item of ['ProjectDefinition.json','App/Resources/Localizable.xcstrings','App/Resources/EuroGas.storekit','App/Resources/Assets.xcassets/Contents.json','App/Resources/Assets.xcassets/AccentColor.colorset/Contents.json','App/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json']) {
    try { JSON.parse(readFileSync(join(euroGas, item), 'utf8')); } catch (error) { errors.push(`JSON inválido ${item}: ${error.message}`); }
  }
  for (const item of ['App/Resources/Info.plist','App/Resources/PrivacyInfo.xcprivacy','App/Resources/EuroGas.entitlements','Widgets/Info.plist','Widgets/EuroGasWidgets.entitlements']) {
    assert(plistLooksWellFormed(readFileSync(join(euroGas, item), 'utf8')), `Plist/XML mal formado: ${item}`, errors);
  }

  const project = readFileSync(join(euroGas, 'EuroGas.xcodeproj/project.pbxproj'), 'utf8');
  assert(project.includes('name = EuroGas;') && project.includes('name = EuroGasWidgets;') && project.includes('name = EuroGasTests;'), 'Faltan targets esperados en pbxproj', errors);
  assert(project.includes('Packages/CostCore') && project.includes('Packages/Persistence') && project.includes('Packages/EuroGasShared'), 'Faltan paquetes locales en pbxproj', errors);
  assert(!/\b[A-F0-9]{25,}\b/.test(project), 'Hay identificadores PBX de más de 24 caracteres', errors);
  const definitions = new Set([...project.matchAll(/^\s*([A-F0-9]{24})(?:\s+\/\*.*?\*\/)?\s+=/gm)].map(match => match[1]));
  const references = new Set([...project.matchAll(/\b[A-F0-9]{24}\b/g)].map(match => match[0]));
  for (const id of references) assert(definitions.has(id), `Referencia PBX sin definición: ${id}`, errors);

  const definition = JSON.parse(readFileSync(join(euroGas, 'ProjectDefinition.json'), 'utf8'));
  for (const target of definition.targets) for (const source of target.sources) assert(statSafe(join(euroGas, source)), `Ruta de target inexistente: ${source}`, errors);
  for (const source of Object.values(definition.localPackages)) assert(statSafe(join(euroGas, source, 'Package.swift')), `Paquete local inexistente: ${source}`, errors);

  const allFiles = walk(euroGas);
  const ddlMarker = ['CREATE', 'TABLE', 'Vehicle'].join(' ');
  const ddlOwners = allFiles.filter(file => /\.(sql|swift|mjs|md)$/.test(file) && readFileSync(file, 'utf8').includes(ddlMarker));
  assert(ddlOwners.length === 1 && ddlOwners[0].endsWith(join('Migrations','v1_initial.sql')), `El DDL no es único: ${ddlOwners.map(file => relative(repo, file)).join(', ')}`, errors);

  const costCoreFiles = walk(join(euroGas, 'Packages/CostCore/Sources')).filter(file => file.endsWith('.swift'));
  const forbiddenCore = /import\s+(SwiftUI|UIKit|CoreLocation|MapKit|StoreKit|ActivityKit|GRDB)\b/;
  for (const file of costCoreFiles) assert(!forbiddenCore.test(readFileSync(file, 'utf8')), `CostCore acoplado a framework: ${relative(repo, file)}`, errors);

  const viewFiles = walk(join(euroGas, 'App/Features')).filter(file => file.endsWith('View.swift'));
  const forbiddenView = /import\s+(GRDB|StoreKit|CoreLocation)\b|\b(SELECT|INSERT|UPDATE|DELETE)\s+(FROM|INTO|SET)?/i;
  for (const file of viewFiles) assert(!forbiddenView.test(readFileSync(file, 'utf8')), `View accede a infraestructura: ${relative(repo, file)}`, errors);

  const config = readFileSync(join(euroGas, 'Config/Project.xcconfig'), 'utf8');
  assert(config.includes('PRODUCT_BUNDLE_IDENTIFIER = com.example.EuroGas'), 'Bundle ID provisional no centralizado', errors);
  assert(/^DEVELOPMENT_TEAM\s*=\s*$/m.test(config), 'Development Team no está vacío', errors);
  const sourceText = allFiles.filter(file => /\.(swift|plist|entitlements|xcconfig|pbxproj|storekit)$/.test(file)).map(file => readFileSync(file, 'utf8')).join('\n');
  assert(!/com\.autem\.eurogas/i.test(sourceText), 'Aparece un identificador definitivo no autorizado', errors);
  assert(!/(sk-(proj-)?[A-Za-z0-9_-]{20,}|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|AKIA[0-9A-Z]{16})/.test(sourceText), 'Posible secreto detectado', errors);
  assert(!allFiles.some(file => /(^|[\\/])\.env($|\.)/.test(file)), 'Hay un archivo .env dentro de EuroGas', errors);

  return errors;
}

function statSafe(path) { try { return statSync(path); } catch { return null; } }

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  const errors = validate();
  if (errors.length) { for (const error of errors) console.error(`FAIL ${error}`); process.exitCode = 1; }
  else console.log('PASS EuroGas static Windows validation');
}
