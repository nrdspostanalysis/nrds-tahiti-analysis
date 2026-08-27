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
