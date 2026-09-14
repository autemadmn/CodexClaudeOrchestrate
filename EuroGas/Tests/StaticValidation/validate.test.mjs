import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { validate } from '../../Tools/validate-windows.mjs';

test('EuroGas static project contract', () => assert.deepEqual(validate(), []));

test('distribution builds exclude test targets while Debug tests remain enabled', () => {
  const read = path => readFileSync(new URL(`../../${path}`, import.meta.url), 'utf8');
  const scheme = read('EuroGas.xcodeproj/xcshareddata/xcschemes/EuroGas.xcscheme');
  const entries = [...scheme.matchAll(/<BuildActionEntry\b([^>]*)>([\s\S]*?)<\/BuildActionEntry>/g)];
  const testEntry = entries.find(entry => entry[2].includes('BlueprintName="EuroGasTests"'));
  assert.ok(testEntry, 'test target must remain available');
  assert.match(testEntry[1], /buildForTesting="YES"/);
  for (const action of ['Running', 'Profiling', 'Archiving', 'Analyzing']) {
    assert.match(testEntry[1], new RegExp(`buildFor${action}="NO"`));
  }
  assert.match(scheme, /<TestAction\b[^>]*buildConfiguration="Debug"/);
  assert.match(read('Config/Debug.xcconfig'), /^ENABLE_TESTABILITY\s*=\s*YES$/m);
  assert.match(read('Config/Release.xcconfig'), /^ENABLE_TESTABILITY\s*=\s*NO$/m);
  assert.match(read('Config/Project.xcconfig'), /^LD_RUNPATH_SEARCH_PATHS\s*=.*@executable_path\/Frameworks/m);
});
