-- Billo Postgres schema for a future Supabase project.
-- The demo API does not connect to Supabase.
-- Run the Node server as its own process. Do not port it onto Supabase Edge
-- Functions: idempotency and the payment simulator need a normal Node host,
-- and Edge is the wrong place for a long-running ledger. See docs/deployment.md.
--
-- There is intentionally no PAN, expiry, or CVV column.

create table public.cards (
  id text primary key,
  issuer text not null check (issuer in ('kbank', 'scb', 'bbl', 'krungsri', 'ktc', 'ttb')),
  network text not null check (network in ('visa', 'mastercard')),
  last4 text not null check (last4 ~ '^[0-9]{4}$'),
  created_at timestamptz not null default now()
);

create table public.statements (
  id text primary key,
  card_id text not null references public.cards (id),
  fingerprint text not null unique,
  period_start date not null,
  period_end date not null,
  statement_date date not null,
  due_date date not null,
  full_due_satang bigint not null check (full_due_satang >= 0),
  min_due_satang bigint not null check (min_due_satang >= 0),
  currency text not null default 'THB' check (currency = 'THB'),
  review_state text not null check (review_state in ('needs_review', 'confirmed')),
  settlement_state text not null check (
    settlement_state in ('open', 'payment_pending', 'settled', 'payment_failed')
  ),
  source text not null check (source in ('seed', 'sample_import', 'pdf_import')),
  created_at timestamptz not null default now(),
  check (min_due_satang <= full_due_satang),
  check (period_start <= period_end),
  check (statement_date <= due_date)
);

create table public.payments (
  id text primary key,
  idempotency_key text not null unique,
  request_hash text not null,
  batch_status text not null check (
    batch_status in ('succeeded', 'failed', 'partial', 'action_required')
  ),
  auto_retry boolean not null default false check (auto_retry = false),
  created_at timestamptz not null default now()
);

create table public.payment_items (
  id text primary key,
  payment_id text not null references public.payments (id),
  statement_id text not null references public.statements (id),
  issuer text not null,
  last4 text not null check (last4 ~ '^[0-9]{4}$'),
  amount_satang bigint not null check (amount_satang >= 0),
  status text not null check (status in ('succeeded', 'failed', 'pending')),
  simulator_code text not null
);

create table public.idempotency_keys (
  key text primary key,
  request_hash text not null,
  status_code integer not null,
  response jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.cards enable row level security;
alter table public.statements enable row level security;
alter table public.payments enable row level security;
alter table public.payment_items enable row level security;
alter table public.idempotency_keys enable row level security;

-- No policies yet: anon and authenticated are denied.
-- Add a user_id owner column and policies before any real household data.
-- The future Node API would use the service role on the server only.
