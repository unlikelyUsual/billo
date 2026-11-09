# Deploying the Billo API

The demo process is a normal Node server. It is not a Supabase Edge Function, and it should not be moved there when the data becomes real.

Edge Functions are short-lived and are a poor fit for a payment call that must keep an idempotency record across the request. They also do not give you a straightforward place for a long-running Node host, file limits, or a worker you can scale on its own. Keep Supabase as Postgres and Auth. Keep this API as a separate Node service.

## What runs today

`npm run dev:api` or, after `npm run build:api`, `npm run start:api`. The process listens on `API_HOST` and `API_PORT` (default `0.0.0.0:4317`). `GET /health` returns `{ "ok": true }`.

`DEMO_MODE` must stay unset or `true`. `DEMO_MODE=false` exits on purpose: this build does not open a Supabase connection, and it must not pretend that it does.

The ledger and the idempotency table are in memory. One process is the whole demo. Restarting it, or running two copies, drops or splits that state. Before more than one instance, store idempotency keys and payments in Postgres (the migration already has the tables) and make the payment write conditional on inserting the key.

## Later, with Supabase

1. Create a Supabase project and run `supabase/migrations/0001_billo.sql`.
2. Put `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` in the API environment only.
3. Give the mobile app the anon key for Auth, never the service role.
4. Add a household or user id, and Row Level Security policies, before any real statement is stored. Until then the tables are denied to anon and authenticated roles.
5. Terminate TLS at the reverse proxy. Delete `usesCleartextTraffic` from the Android manifest and do not send the API over plain HTTP.

Do not ship the issuer simulator as a payment integration. A pending demo result is not a bank timeout, and the API refuses to retry it (`POST /v1/payments/:id/retry` returns `no_auto_retry` without changing state). A real partner needs the same rule: an uncertain debit stays put until reconciliation.

Do not log PAN, CVV, mailbox tokens, or the service role. The request hook already rejects those fields. Keep that rejection in front of any future parser.
