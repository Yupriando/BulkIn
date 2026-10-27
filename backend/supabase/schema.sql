-- BulkIn — skema database Supabase
-- Jalankan sekali di Supabase Dashboard → SQL Editor → New query → Run.

-- ───────────────────────── Tabel ─────────────────────────

create table if not exists public.profiles (
  id                   uuid primary key references auth.users (id) on delete cascade,
  display_name         text,
  daily_kcal_target    integer not null default 3000,
  daily_protein_target integer not null default 120,
  target_weight_kg     numeric(5, 2),
  created_at           timestamptz not null default now()
);

-- Database makanan. user_id null = makanan bawaan (dipakai semua user).
-- Kalori bisa per 100 gram, per satuan (bungkus/porsi/butir), atau keduanya.
create table if not exists public.foods (
  id                bigint generated always as identity primary key,
  user_id           uuid references auth.users (id) on delete cascade,
  name              text not null,
  aliases           text[] not null default '{}',
  kcal_per_100g     numeric(7, 2),
  protein_per_100g  numeric(6, 2),
  unit_name         text,
  kcal_per_unit     numeric(7, 2),
  protein_per_unit  numeric(6, 2),
  created_at        timestamptz not null default now(),
  constraint foods_has_kcal check (kcal_per_100g is not null or kcal_per_unit is not null),
  constraint foods_unit_complete check ((unit_name is null) = (kcal_per_unit is null))
);

create unique index if not exists foods_name_per_owner
  on public.foods (coalesce(user_id, '00000000-0000-0000-0000-000000000000'::uuid), lower(name));

create table if not exists public.meal_entries (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
  eaten_on    date not null,
  meal_type   text not null check (meal_type in ('sarapan', 'siang', 'sore', 'malam', 'camilan')),
  food_id     bigint references public.foods (id) on delete set null,
  food_name   text not null,          -- disalin supaya riwayat aman walau makanan dihapus
  grams       numeric(7, 1),
  quantity    numeric(6, 2),
  kcal        numeric(7, 1) not null default 0,
  protein     numeric(6, 1) not null default 0,
  created_at  timestamptz not null default now()
);

create index if not exists meal_entries_user_day on public.meal_entries (user_id, eaten_on);

create table if not exists public.weight_logs (
  id           bigint generated always as identity primary key,
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  weight_kg    numeric(5, 2) not null check (weight_kg > 20 and weight_kg < 400),
  measured_at  timestamptz not null default now(),
  condition    text check (condition in ('belum_makan', 'sedang_makan', 'sudah_makan')),
  note         text,
  created_at   timestamptz not null default now()
);

create index if not exists weight_logs_user_time on public.weight_logs (user_id, measured_at);

-- Profil otomatis dibuat saat user daftar.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────── Hak akses ─────────────────────────
-- Project Supabase baru tidak otomatis memberi akses tabel ke role API.
-- authenticated = user yang login lewat app, service_role = script seed & import.

grant usage on schema public to authenticated, service_role;
grant select, insert, update, delete
  on public.profiles, public.foods, public.meal_entries, public.weight_logs
  to authenticated, service_role;
grant usage, select on all sequences in schema public to authenticated, service_role;

-- ───────────────────────── Row Level Security ─────────────────────────
-- Backend memakai token login user, jadi setiap user hanya bisa melihat datanya sendiri.

alter table public.profiles     enable row level security;
alter table public.foods        enable row level security;
alter table public.meal_entries enable row level security;
alter table public.weight_logs  enable row level security;

drop policy if exists "profil sendiri" on public.profiles;
create policy "profil sendiri" on public.profiles
  for all using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "lihat makanan bawaan & milik sendiri" on public.foods;
create policy "lihat makanan bawaan & milik sendiri" on public.foods
  for select using (user_id is null or user_id = auth.uid());

drop policy if exists "kelola makanan sendiri" on public.foods;
create policy "kelola makanan sendiri" on public.foods
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "makan sendiri" on public.meal_entries;
create policy "makan sendiri" on public.meal_entries
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "berat sendiri" on public.weight_logs;
create policy "berat sendiri" on public.weight_logs
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
