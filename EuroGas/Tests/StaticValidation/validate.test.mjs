import test from 'node:test';
import assert from 'node:assert/strict';
import { validate } from '../../Tools/validate-windows.mjs';

test('EuroGas static project contract', () => assert.deepEqual(validate(), []));
