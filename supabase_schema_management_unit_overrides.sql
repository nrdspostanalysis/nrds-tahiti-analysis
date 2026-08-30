-- Run this once in the Supabase SQL editor (Project -> SQL Editor -> New query) for the
-- nrds-tahiti-analysis project. Backs the "Edit Management Unit" header button in index.html,
-- which lets any user edit the embedded historical (Butaud survey) data for a management unit
-- and have those edits shared with everyone using the app.
--
-- Same no-auth, open-anon-key pattern already used by every other table this app writes to
-- (habitat_restoration, new_elements, pepinieres, activity_types, activity_entries,
-- pff_symbol_map, ...) — there is no login system, so RLS just needs to allow the anon key to
-- read/insert/update.

create table if not exists management_unit_overrides (
  id bigint generated always as identity primary key,
  valley text not null,
  nom text not null,
  site text,
  surface2d numeric,
  surface3d numeric,
  veg2023 text,
  veg2024 text,
  veg2025 text,
  sb2023 text,
  sb2024 text,
  sb2025 text,
  plant2023 text,
  plant2024 text,
  plant2025 text,
  dominance_override text,
  updated_at timestamptz not null default now(),
  unique (valley, nom)
);

alter table management_unit_overrides enable row level security;

create policy "Allow public read (management_unit_overrides)"
  on management_unit_overrides for select
  using (true);

create policy "Allow public insert (management_unit_overrides)"
  on management_unit_overrides for insert
  with check (true);

create policy "Allow public update (management_unit_overrides)"
  on management_unit_overrides for update
  using (true) with check (true);

-- Realtime: the app subscribes to postgres_changes on this table (same as every other table it
-- reads live) so an edit saved on one device shows up for everyone else without a reload. Make
-- sure this table is added to the "supabase_realtime" publication (Database -> Replication in the
-- dashboard, or the statement below).
alter publication supabase_realtime add table management_unit_overrides;

-- 2026-08-27 migration: if you already created this table before today, the "create table if not
-- exists" above was a no-op for you and dominance_override wasn't added — run this one line by
-- itself (safe to run even if the table was just freshly created above, "if not exists" no-ops).
alter table management_unit_overrides add column if not exists dominance_override text;

-- 2026-08-30 migration: adds row deletion ("Delete row" in Edit Management Unit) as a soft-delete
-- flag rather than a real SQL DELETE, so a zone's data isn't destroyed if it's ever needed again —
-- deleteZoneRow() in index.html upserts { deleted: true } instead of deleting the row. A tombstoned
-- zone disappears from the table (see applyPastDataOverrides()) unless a live polygon for it still
-- exists on the map, in which case it reappears blank next load, by design (deleting a row here only
-- ever removes historical data, never a drawn polygon).
alter table management_unit_overrides add column if not exists deleted boolean not null default false;

-- 2026-08-30: dynamic (user-addable/removable) extra columns for Edit Management Unit, beyond the
-- fixed Veg/SB/Plant 2023/2024/2025 triplet above. Two tables in classic long/tidy form so a new
-- column ("new SB or Plantation session for a later year") never requires another SQL migration:
--   management_unit_periods       -- the *columns* themselves, one row per extra column
--   management_unit_period_values -- the *cell values*, one row per (column, zone)
-- These are purely additive — the fixed 2023/2024/2025 columns and everything they feed (map layers,
-- combinedCleaningEstimate, priority ranking, the tau-check tool) are untouched and keep working
-- exactly as before. Dynamic columns are not yet read by any of that analysis code.

create table if not exists management_unit_periods (
  id bigint generated always as identity primary key,
  type text not null check (type in ('veg','sb','plant')),
  label text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

alter table management_unit_periods enable row level security;

create policy "Allow public read (management_unit_periods)"
  on management_unit_periods for select using (true);
create policy "Allow public insert (management_unit_periods)"
  on management_unit_periods for insert with check (true);
create policy "Allow public update (management_unit_periods)"
  on management_unit_periods for update using (true) with check (true);
create policy "Allow public delete (management_unit_periods)"
  on management_unit_periods for delete using (true);

alter publication supabase_realtime add table management_unit_periods;

create table if not exists management_unit_period_values (
  id bigint generated always as identity primary key,
  period_id bigint not null references management_unit_periods(id) on delete cascade,
  valley text not null,
  nom text not null,
  value text,
  updated_at timestamptz not null default now(),
  unique (period_id, valley, nom)
);

alter table management_unit_period_values enable row level security;

create policy "Allow public read (management_unit_period_values)"
  on management_unit_period_values for select using (true);
create policy "Allow public insert (management_unit_period_values)"
  on management_unit_period_values for insert with check (true);
create policy "Allow public update (management_unit_period_values)"
  on management_unit_period_values for update using (true) with check (true);
create policy "Allow public delete (management_unit_period_values)"
  on management_unit_period_values for delete using (true);

alter publication supabase_realtime add table management_unit_period_values;
