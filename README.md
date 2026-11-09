# Billo

Billo is a demo ledger for **Thai credit-card bills**: see what is due, review a statement, and pay several bills together. It is not a loan, a balance transfer, or debt refinancing.

Amounts are integer **satang** (1 baht = 100 satang). Dates are civil dates in **Asia/Bangkok**. The interface is ready in English and Thai. Nothing in this build moves money, reads a mailbox, or stores a full card number.

The demo runs with no accounts and no API keys. Supabase is a schema for later, not a runtime dependency.

## Layout

- `apps/mobile` — Flutter app for Android and iOS
- `apps/api` — TypeScript Fastify API with an in-memory ledger
- `packages/contracts` — OpenAPI document and the synthetic fixtures
- `supabase/migrations` — Postgres schema, unused by the demo
- `docs/deployment.md` — how the Node API should be hosted later

PDF reading lives in `apps/api/src/pdf.ts`. It is called in-process. A separate worker is not running, because only one marked sample layout is accepted.

## Prerequisites

- Node.js 22 or newer
- Flutter 3.47.9 and Dart 3.13 (the Android/iOS projects are the 3.47 template: AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0)

## Run the demo

From the project root:

```bash
npm ci
npm run dev:api
```

The API listens on `http://127.0.0.1:4317`. `DEMO_MODE=false` exits, because Supabase is not connected. Copy `.env.example` to `.env` only if you want to change the port or the demo date. Leave every secret blank.

In another terminal:

```bash
cd apps/mobile
flutter pub get
flutter run --dart-define=API_BASE=http://127.0.0.1:4317
```

On an Android emulator use `http://10.0.2.2:4317`. The Android manifest allows cleartext HTTP so the local demo can reach the API. Remove that before any production build. iOS allows local networking only.

## What to try

The ledger is frozen on **8 November 2026** (Bangkok). Five cards are already open. One older Kasikorn bill is settled, so Activity is not empty.

1. Home shows the open balance, the minimum, and what is due within 7 days. Bangkok Bank (9 Nov) and Kasikorn (12 Nov) are due soon. KTC still needs review, so it cannot be selected.
2. Select Kasikorn, Bangkok Bank, and Krungsri, then review the payment. The legend comes from the API. Simulate it. Kasikorn settles, Bangkok Bank declines, Krungsri stays pending. The pending row says Billo will not retry it. Declined bills can be simulated again with a new payment. Pending bills cannot.
3. Import the ttb sample or the marked sample PDF, edit the amounts, and confirm. Importing the same period again is rejected as a duplicate. An ordinary PDF stops with no guessed amount.
4. Reset demo data on the About screen.

| Issuer | Demo result |
| --- | --- |
| Kasikorn, SCB, KTC, ttb | Succeeds in the ledger |
| Bangkok Bank | Declines |
| Krungsri | Stays pending, and is not retried |

## Checks

```bash
npm run typecheck
npm test
cd apps/mobile
dart format --output=none .
flutter analyze
flutter test
```

Run these on your machine. This source package does not record that they passed.

`npm test` uses the Node test runner through `tsx`. It does not need Supabase. `apps/mobile/pubspec.lock` is included so `flutter pub get` can resolve the same graph; the API `package-lock.json` is included for `npm ci`.

## Money and dates

Persist satang integers and `YYYY-MM-DD` Gregorian dates. Do not send floats. The Thai UI shows the Buddhist year (Gregorian + 543) for display only.

## Fake in this demo, real later

| Piece | This build | Later |
| --- | --- | --- |
| Statements | Synthetic seed and samples | Reviewed import, or a licensed issuer feed |
| PDF | One uncompressed marked sample. Everything else is unavailable | A checked parser per issuer. Never guess an amount |
| Pay | Scripted result per issuer. `autoRetry` is always false | A licensed bill-pay partner with a definitive result |
| Auth and database | None. Memory resets | Supabase Auth and the migration, behind the Node API |
| Gmail | Not connected | Only after Google verification for the restricted scope |
| Card data | Last 4 digits, issuer, network | Still no raw PAN or CVV |

## Gmail

This app does not connect to Gmail. If a later version reads statements from mail, `https://www.googleapis.com/auth/gmail.readonly` is a **restricted** scope. Google requires OAuth verification and, for restricted scopes, a security assessment before ordinary users can grant it. An unverified app is limited to test users and shows a warning screen. Do not request send or modify scopes. Do not store the raw message; keep the fields the person confirmed.

## Paying the card

A generic PromptPay transfer does **not** guarantee that a credit-card bill is settled. The issuer posts the payment only when the instruction carries the right biller or comp code and the billing reference. Production needs a **licensed Thai partner** (or a bank API) that can pay that biller, return a result, and reconcile it. If the partner says the outcome is still unknown, do not send the payment again until that one is reconciled. A second debit can pay the same bill twice. This demo never calls PromptPay.

## PDF status

Extraction is an in-process reader in `apps/api/src/pdf.ts`. It is not a worker and it does not use pdf.js. It accepts only an uncompressed PDF whose text layer contains `BILLO-SAMPLE-STATEMENT-V1` and a complete valid draft. The committed `verified-sample.pdf` is that ttb statement, so importing it and the ttb sample detects a duplicate. `unsupported-letter.pdf` has no marker and no amounts. Anything else — compressed, encrypted, not a PDF, no text, invalid fields, or a secret — returns HTTP 422 `pdf_extraction_unavailable` and the JSON contains no guessed amount.

## Privacy

Before any real household data:

- Say, in Thai and English, what is collected and why: issuer, last 4, statement amounts, due dates.
- Ask before import, and again before any mailbox or issuer link.
- Keep a retention window. Offer export and deletion of statements, imports, and tokens.
- Do not store PAN, CVV, or mailbox passwords. That keeps the product out of the worst of PCI scope.
- Encrypt the database, log access, and record a lawful basis under Thailand’s PDPA, including the right to access and erase.

## Supabase

Apply `supabase/migrations/0001_billo.sql` when you create a project. Row Level Security is on and there are no policies, so the anon key cannot read the tables. The mobile app must not receive the service role. The Node process would use it server-side. See `docs/deployment.md`.
