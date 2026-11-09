import path from 'node:path';

import { buildApp } from './app';
import { loadEnvFile } from './env';
import { isRealDate } from './domain';

loadEnvFile(path.resolve(__dirname, '../../../.env'));

function main(): void {
  if (process.env.DEMO_MODE === 'false') {
    console.error(
      'DEMO_MODE=false needs Supabase, which this prototype does not connect to. Leave DEMO_MODE unset or true.',
    );
    process.exit(1);
  }
  const port = Number(process.env.API_PORT ?? 4317);
  const host = process.env.API_HOST ?? '0.0.0.0';
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    console.error('API_PORT must be an integer port.');
    process.exit(1);
  }
  const today = process.env.DEMO_TODAY;
  if (today && !isRealDate(today)) {
    console.error('DEMO_TODAY must be a real YYYY-MM-DD calendar date.');
    process.exit(1);
  }
  const app = buildApp(today ? { today, logger: false } : { logger: false });
  app.listen({ port, host }).then(
    (address) => {
      console.log(`Billo demo API listening on ${address}`);
    },
    (error: unknown) => {
      const message = error instanceof Error ? error.message : 'Failed to start';
      console.error(message);
      process.exit(1);
    },
  );
}

const entry = process.argv[1] ?? '';
if (entry.endsWith('index.ts') || entry.endsWith('index.js')) {
  main();
}
