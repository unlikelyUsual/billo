import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';

import { buildApp } from '../src/app';

const specPath = path.resolve(__dirname, '../../../packages/contracts/openapi.json');

test('openapi lists every registered route', async () => {
  const app = buildApp();
  const spec = JSON.parse(fs.readFileSync(specPath, 'utf8')) as {
    paths: Record<string, Record<string, unknown>>;
    components: { schemas: { Home: { required: string[] }; Totals: { required: string[] } } };
  };
  const registered = new Set(
    app.registeredRoutes.map((route) => `${route.method.toLowerCase()} ${route.url.replace(/:([A-Za-z]+)/g, '{$1}')}`),
  );
  const documented = new Set<string>();
  for (const [url, methods] of Object.entries(spec.paths)) {
    for (const method of Object.keys(methods)) {
      documented.add(`${method.toLowerCase()} ${url}`);
    }
  }
  assert.deepEqual([...registered].sort(), [...documented].sort());

  const home = (await app.inject({ method: 'GET', url: '/v1/home' })).json() as Record<string, unknown>;
  for (const key of spec.components.schemas.Home.required) {
    assert.equal(Object.hasOwn(home, key), true, key);
  }
  const totals = home.totals as Record<string, unknown>;
  for (const key of spec.components.schemas.Totals.required) {
    assert.equal(Object.hasOwn(totals, key), true, key);
  }
  await app.close();
});
