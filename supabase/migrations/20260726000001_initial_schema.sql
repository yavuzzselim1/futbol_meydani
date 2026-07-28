-- Futbol MeydanÃ„Â± v1.17.0 - Online Meydan ve tanÃ„Â±lama Ã…Å¸emasÃ„Â±
-- Supabase Dashboard > SQL Editor bÃƒÂ¶lÃƒÂ¼mÃƒÂ¼nde bu dosyanÃ„Â±n tamamÃ„Â±nÃ„Â± bir kez ÃƒÂ§alÃ„Â±Ã…Å¸tÃ„Â±r.

create table if not exists public.online_rooms (
  code text primary key check (code ~ '^[0-9]{6}$'),
  host_id uuid not null references auth.users(id) on delete cascade,
  host_name text not null check (char_length(host_name) between 1 and 18),
  host_ready boolean not null default false,
  host_connected boolean not null default true,
  guest_id uuid references auth.users(id) on delete set null,
  guest_name text check (guest_name is null or char_length(guest_name) between 1 and 18),
  guest_ready boolean not null default false,
  guest_connected boolean not null default false,
  status text not null default 'waiting' check (status in ('waiting', 'ready', 'playing', 'revealing', 'finished', 'closed')),
  revision integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.online_rooms add column if not exists game_setup jsonb;
alter table public.online_rooms add column if not exists host_locked boolean not null default false;
alter table public.online_rooms add column if not exists guest_locked boolean not null default false;
alter table public.online_rooms add column if not exists host_selection_started_at timestamptz;
alter table public.online_rooms add column if not exists guest_selection_started_at timestamptz;
alter table public.online_rooms add column if not exists reveal_fast boolean not null default false;
alter table public.online_rooms add column if not exists host_banned_team_id text;
alter table public.online_rooms add column if not exists guest_banned_team_id text;
alter table public.online_rooms add column if not exists round_id uuid not null default gen_random_uuid();
alter table public.online_rooms add column if not exists matchmaking boolean not null default false;
alter table public.online_rooms add column if not exists host_avatar_id text;
alter table public.online_rooms add column if not exists guest_avatar_id text;

create table if not exists public.online_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 18),
  matches integer not null default 0,
  wins integer not null default 0,
  draws integer not null default 0,
  losses integer not null default 0,
  rating integer not null default 0,
  coins integer not null default 0,
  xp integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.online_profiles add column if not exists friend_code text unique;

create table if not exists public.online_match_history (
  id bigint generated always as identity primary key,
  round_id uuid not null unique,
  room_code text not null,
  host_id uuid not null references auth.users(id) on delete cascade,
  guest_id uuid not null references auth.users(id) on delete cascade,
  host_name text not null,
  guest_name text not null,
  host_total numeric not null,
  guest_total numeric not null,
  target numeric not null,
  winner_id uuid references auth.users(id) on delete set null,
  played_at timestamptz not null default now()
);

create table if not exists public.online_matchmaking_queue (
  user_id uuid primary key references auth.users(id) on delete cascade,
  player_name text not null check (char_length(player_name) between 1 and 18),
  joined_at timestamptz not null default now()
);

create table if not exists public.game_logs (
  id bigint generated always as identity primary key,
  user_id uuid references auth.users(id) on delete set null,
  level text not null check (level in ('info', 'warning', 'error')),
  event text not null check (event ~ '^[a-z0-9_]{3,60}$'),
  error_code text not null default '' check (char_length(error_code) <= 24),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now()
);
create index if not exists game_logs_created_at_idx on public.game_logs(created_at desc);
create index if not exists game_logs_error_code_idx on public.game_logs(error_code) where error_code <> '';

create table if not exists public.online_squads (
  room_code text not null references public.online_rooms(code) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  side text not null check (side in ('host', 'guest')),
  player_ids jsonb not null check (jsonb_typeof(player_ids) = 'array' and jsonb_array_length(player_ids) <= 7),
  submitted_at timestamptz not null default now(),
  primary key (room_code, side)
);

alter table public.online_rooms enable row level security;
alter table public.online_squads enable row level security;
alter table public.online_profiles enable row level security;
alter table public.online_match_history enable row level security;
alter table public.online_matchmaking_queue enable row level security;
alter table public.game_logs enable row level security;

drop policy if exists "Players read own online profile" on public.online_profiles;
create policy "Players read own online profile" on public.online_profiles for select to authenticated using (true);
drop policy if exists "Players insert own online profile" on public.online_profiles;
create policy "Players insert own online profile" on public.online_profiles for insert to authenticated with check (auth.uid() = id);
drop policy if exists "Players update own online profile" on public.online_profiles;
create policy "Players update own online profile" on public.online_profiles for update to authenticated using (auth.uid() = id);
drop policy if exists "Players read own match history" on public.online_match_history;
create policy "Players read own match history" on public.online_match_history for select to authenticated using (host_id = (select auth.uid()) or guest_id = (select auth.uid()));
grant select, insert, update on public.online_profiles to authenticated;
grant select on public.online_match_history to authenticated;
revoke insert, update, delete on public.online_match_history, public.online_matchmaking_queue from anon, authenticated;
revoke all on public.game_logs from anon, authenticated;

drop policy if exists "Room participants can read" on public.online_rooms;
create policy "Room participants can read"
on public.online_rooms for select
to authenticated
using ((select auth.uid()) = host_id or (select auth.uid()) = guest_id);

grant select on public.online_rooms to authenticated;
revoke insert, update, delete on public.online_rooms from anon, authenticated;

drop policy if exists "Players see own squad until reveal" on public.online_squads;
create policy "Players see own squad until reveal"
on public.online_squads for select
to authenticated
using (
  owner_id = (select auth.uid()) or exists (
    select 1 from public.online_rooms r
    where r.code = room_code and r.status in ('revealing', 'finished')
      and ((select auth.uid()) = r.host_id or (select auth.uid()) = r.guest_id)
  )
);

grant select on public.online_squads to authenticated;
revoke insert, update, delete on public.online_squads from anon, authenticated;


create or replace function public.create_online_room(player_name text)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  attempt integer := 0;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if char_length(trim(player_name)) not between 1 and 18 then raise exception 'Oyuncu adÃ„Â± 1-18 karakter olmalÃ„Â±'; end if;

  insert into public.online_profiles(id, display_name) values (auth.uid(), trim(player_name))
  on conflict (id) do update set display_name = excluded.display_name, updated_at = now();

  loop
    new_code := (100000 + floor(random() * 900000))::integer::text;
    begin
      insert into public.online_rooms(code, host_id, host_name)
      values (new_code, auth.uid(), trim(player_name));
      exit;
    exception when unique_violation then
      attempt := attempt + 1;
      if attempt >= 100 then raise exception 'Oda kodu ÃƒÂ¼retilemedi'; end if;
    end;
  end loop;
  return query select r.* from public.online_rooms r where r.code = new_code;
end;
$$;

create or replace function public.join_online_room(room_code text, player_name text)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if $1 !~ '^[0-9]{6}$' then raise exception 'Oda kodu 6 haneli olmalÃ„Â±'; end if;
  if char_length(trim(player_name)) not between 1 and 18 then raise exception 'Oyuncu adÃ„Â± 1-18 karakter olmalÃ„Â±'; end if;

  insert into public.online_profiles(id, display_name) values (auth.uid(), trim(player_name))
  on conflict (id) do update set display_name = excluded.display_name, updated_at = now();

  update public.online_rooms r
  set guest_id = auth.uid(), guest_name = trim(player_name), guest_ready = false,
      guest_connected = true, revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.status = 'waiting' and r.guest_id is null and r.host_id <> auth.uid();
  get diagnostics changed = row_count;
  if changed = 0 then raise exception 'Oda bulunamadÃ„Â±, dolu veya kendi odana katÃ„Â±lmaya ÃƒÂ§alÃ„Â±Ã…Å¸Ã„Â±yorsun'; end if;
  return query select r.* from public.online_rooms r where r.code = $1;
end;
$$;

create or replace function public.set_online_ready(room_code text, is_ready boolean)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  update public.online_rooms r
  set host_ready = case when r.host_id = auth.uid() then is_ready else r.host_ready end,
      guest_ready = case when r.guest_id = auth.uid() then is_ready else r.guest_ready end,
      revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.status = 'waiting'
    and (r.host_id = auth.uid() or r.guest_id = auth.uid());
  get diagnostics changed = row_count;
  if changed = 0 then raise exception 'HazÃ„Â±r durumu deÃ„Å¸iÃ…Å¸tirilemedi'; end if;
  return query select r.* from public.online_rooms r where r.code = $1;
end;
$$;

create or replace function public.start_online_room(room_code text)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  update public.online_rooms r
  set status = 'ready', revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.host_id = auth.uid() and r.status = 'waiting'
    and r.guest_id is not null and r.host_ready and r.guest_ready;
  get diagnostics changed = row_count;
  if changed = 0 then raise exception 'Ã„Â°ki oyuncu hazÃ„Â±r deÃ„Å¸il veya oda kurucusu deÃ„Å¸ilsin'; end if;
  return query select r.* from public.online_rooms r where r.code = $1;
end;
$$;

create or replace function public.start_online_squad_match(room_code text, setup jsonb)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  if $2 is null or jsonb_typeof($2) <> 'object' then raise exception 'GeÃƒÂ§erli kura bilgisi gerekli'; end if;
  update public.online_rooms r
  set status = 'playing', game_setup = $2, host_locked = false, guest_locked = false,
      host_selection_started_at = null, guest_selection_started_at = null, reveal_fast = false,
      host_banned_team_id = null, guest_banned_team_id = null,
      round_id = gen_random_uuid(),
      revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.host_id = auth.uid() and r.status in ('waiting', 'revealing', 'finished')
    and r.guest_id is not null and r.host_ready and r.guest_ready;
  get diagnostics changed = row_count;
  if changed = 0 then raise exception 'Ã„Â°ki oyuncu hazÃ„Â±r deÃ„Å¸il veya oda kurucusu deÃ„Å¸ilsin'; end if;
  delete from public.online_squads s where s.room_code = $1;
  return query select r.* from public.online_rooms r where r.code = $1;
end;
$$;

create or replace function public.submit_online_ban(room_code text, team_id text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
begin
  select * into current_room from public.online_rooms r where r.code = $1 for update;
  if not found or current_room.status <> 'playing' then raise exception 'Oda takÃ„Â±m banÃ„Â± kabul etmiyor'; end if;
  if current_room.host_id <> auth.uid() and current_room.guest_id <> auth.uid() then raise exception 'Bu odanÃ„Â±n oyuncusu deÃ„Å¸ilsin'; end if;
  if not exists (select 1 from jsonb_array_elements_text(current_room.game_setup->'team_ids') value where value = $2) then
    raise exception 'Bu takÃ„Â±m kurada bulunmuyor';
  end if;

  update public.online_rooms r
  set host_banned_team_id = case when r.host_id = auth.uid() and r.host_banned_team_id is null then $2 else r.host_banned_team_id end,
      guest_banned_team_id = case when r.guest_id = auth.uid() and r.guest_banned_team_id is null then $2 else r.guest_banned_team_id end,
      revision = r.revision + 1, updated_at = now()
  where r.code = $1;
end;
$$;

create or replace function public.begin_online_selection(room_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.online_rooms r
  set end_time = coalesce(r.end_time, now() + interval '120 seconds'),
      revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.status = 'playing'
    and (r.host_id = auth.uid() or r.guest_id = auth.uid());
end;
$$;

create or replace function public.submit_online_squad(room_code text, selected_players jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
  player_side text;
begin
  if jsonb_typeof($2) <> 'array' or jsonb_array_length($2) > 7 then
    raise exception 'Kadro en fazla 7 futbolcu iÃƒÂ§erebilir';
  end if;
  select * into current_room from public.online_rooms r where r.code = $1 for update;
  if not found or current_room.status <> 'playing' then raise exception 'Oda seÃƒÂ§im kabul etmiyor'; end if;
  if current_room.host_id = auth.uid() then player_side := 'host';
  elsif current_room.guest_id = auth.uid() then player_side := 'guest';
  else raise exception 'Bu odanÃ„Â±n oyuncusu deÃ„Å¸ilsin';
  end if;

  insert into public.online_squads(room_code, owner_id, side, player_ids)
  values ($1, auth.uid(), player_side, $2)
  on conflict on constraint online_squads_pkey do update
    set owner_id = excluded.owner_id, player_ids = excluded.player_ids, submitted_at = now();

  update public.online_rooms r
  set host_locked = case when player_side = 'host' then true else r.host_locked end,
      guest_locked = case when player_side = 'guest' then true else r.guest_locked end,
      end_time = case
        when player_side = 'host' and not r.guest_locked then least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        when player_side = 'guest' and not r.host_locked then least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        else r.end_time end,
      revision = r.revision + 1, updated_at = now()
  where r.code = $1;

  update public.online_rooms r
  set status = 'ready', revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.host_locked and r.guest_locked;
end;
$$;

create or replace function public.begin_online_reveal(room_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.online_rooms r
  set status = 'revealing', end_time = now() + interval '2 seconds', revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.host_id = auth.uid() and r.status = 'ready'
    and r.host_locked and r.guest_locked;
  if not found then raise exception 'SonuÃƒÂ§larÃ„Â± yalnÃ„Â±zca oda kurucusu aÃƒÂ§abilir'; end if;
end;
$$;

create or replace function public.speed_up_online_reveal(room_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.online_rooms r
  set reveal_fast = true, revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.host_id = auth.uid() and r.status = 'revealing';
end;
$$;

create or replace function public.leave_online_room(room_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
begin
  select * into current_room from public.online_rooms r where r.code = $1 for update;
  if not found then return; end if;

  if current_room.status = 'waiting' and current_room.host_id = auth.uid() and current_room.guest_id is not null then
    update public.online_rooms r
    set host_id = current_room.guest_id, host_name = current_room.guest_name,
        host_ready = current_room.guest_ready, host_connected = true,
        guest_id = null, guest_name = null, guest_ready = false, guest_connected = false,
        revision = r.revision + 1, updated_at = now()
    where r.code = $1;
  elsif current_room.status = 'waiting' and current_room.guest_id = auth.uid() then
    update public.online_rooms r
    set guest_id = null, guest_name = null, guest_ready = false, guest_connected = false,
        revision = r.revision + 1, updated_at = now()
    where r.code = $1;
  elsif current_room.host_id = auth.uid() or current_room.guest_id = auth.uid() then
    update public.online_rooms r
    set status = 'closed', revision = r.revision + 1, updated_at = now()
    where r.code = $1;
  end if;
end;
$$;

create or replace function public.find_online_match(player_name text)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  opponent public.online_matchmaking_queue%rowtype;
  new_code text;
  attempt integer := 0;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if char_length(trim($1)) not between 1 and 18 then raise exception 'Oyuncu adÃ„Â± 1-18 karakter olmalÃ„Â±'; end if;

  insert into public.online_profiles(id, display_name) values (auth.uid(), trim($1))
  on conflict (id) do update set display_name = excluded.display_name, updated_at = now();

  perform pg_advisory_xact_lock(hashtext('futbol_meydani_matchmaking'));

  delete from public.online_matchmaking_queue q where q.joined_at < now() - interval '2 minutes';

  return query
  select r.* from public.online_rooms r
  where r.status = 'waiting' and r.matchmaking and r.guest_id is not null
    and (r.host_id = auth.uid() or r.guest_id = auth.uid())
  order by r.created_at desc limit 1;
  if found then
    delete from public.online_matchmaking_queue q where q.user_id = auth.uid();
    return;
  end if;

  select q.* into opponent
  from public.online_matchmaking_queue q
  where q.user_id <> auth.uid()
  order by q.joined_at
  for update skip locked
  limit 1;

  if opponent.user_id is null then
    insert into public.online_matchmaking_queue(user_id, player_name, joined_at)
    values (auth.uid(), trim($1), now())
    on conflict (user_id) do update set player_name = excluded.player_name;
    return;
  end if;

  delete from public.online_matchmaking_queue q where q.user_id in (opponent.user_id, auth.uid());
  loop
    new_code := (100000 + floor(random() * 900000))::integer::text;
    begin
      insert into public.online_rooms(
        code, host_id, host_name, host_ready, guest_id, guest_name, guest_ready,
        host_connected, guest_connected, matchmaking
      ) values (
        new_code, opponent.user_id, opponent.player_name, true,
        auth.uid(), trim($1), true, true, true, true

      );
      exit;
    exception when unique_violation then
      attempt := attempt + 1;
      if attempt >= 100 then raise exception 'EÃ…Å¸leÃ…Å¸me odasÃ„Â± ÃƒÂ¼retilemedi'; end if;
    end;
  end loop;
  return query select r.* from public.online_rooms r where r.code = new_code;
end;
$$;

create or replace function public.cancel_online_matchmaking()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.online_matchmaking_queue q where q.user_id = auth.uid();
$$;

create or replace function public.finish_online_match(room_code text, host_total numeric, guest_total numeric, target_value numeric)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
  winning_user uuid;
begin
  select r.* into current_room from public.online_rooms r where r.code = $1 for update;
  if not found then raise exception 'Oda bulunamadÃ„Â±'; end if;
  if current_room.host_id <> auth.uid() then raise exception 'Sonucu yalnÃ„Â±zca oda kurucusu kaydedebilir'; end if;
  if current_room.guest_id is null then raise exception 'Rakip bulunamadÃ„Â±'; end if;
  if current_room.status not in ('revealing', 'finished') then raise exception 'MaÃƒÂ§ henÃƒÂ¼z sonuÃƒÂ§ aÃ…Å¸amasÃ„Â±nda deÃ„Å¸il'; end if;

  if exists (select 1 from public.online_match_history h where h.round_id = current_room.round_id) then
    update public.online_rooms r set status = 'finished', revision = r.revision + 1, updated_at = now() where r.code = $1;
    return;
  end if;

  winning_user := case
    when abs($4 - $2) < abs($4 - $3) then current_room.host_id
    when abs($4 - $3) < abs($4 - $2) then current_room.guest_id
    else null
  end;

  insert into public.online_match_history(
    round_id, room_code, host_id, guest_id, host_name, guest_name,
    host_total, guest_total, target, winner_id
  ) values (
    current_room.round_id, current_room.code, current_room.host_id, current_room.guest_id,
    current_room.host_name, current_room.guest_name, $2, $3, $4, winning_user
  );

  insert into public.online_profiles(id, display_name) values
    (current_room.host_id, current_room.host_name),
    (current_room.guest_id, current_room.guest_name)
  on conflict (id) do update set display_name = excluded.display_name, updated_at = now();

  -- GerÃƒÂ§ek ELO formÃƒÂ¼lÃƒÂ¼
  -- K faktÃƒÂ¶rÃƒÂ¼: yeni oyuncu (< 10 maÃƒÂ§) = 32, orta (< 30) = 24, uzman = 16
  update public.online_profiles p
  set matches = p.matches + 1,
      wins = p.wins + case when winning_user = p.id then 1 else 0 end,
      draws = p.draws + case when winning_user is null then 1 else 0 end,
      losses = p.losses + case when winning_user is not null and winning_user <> p.id then 1 else 0 end,
      rating = greatest(100, p.rating + (
        -- K faktÃƒÂ¶rÃƒÂ¼
        case when p.matches < 10 then 32 when p.matches < 30 then 24 else 16 end
        *
        -- GerÃƒÂ§ek sonuÃƒÂ§ - Beklenen skor
        (case
          when winning_user = p.id then 1.0
          when winning_user is null then 0.5
          else 0.0
        end
        -
        1.0 / (1.0 + power(10.0,
          -- Rakibin puanÃ„Â± - kendi puanÃ„Â±mÃ„Â±z (karÃ…Å¸Ã„Â± tarafÃ„Â±n ID'sini bul)
          ((select q.rating from public.online_profiles q
            where q.id = case when p.id = current_room.host_id
                              then current_room.guest_id
                              else current_room.host_id end
            limit 1) - p.rating) / 400.0
        )))
      )::integer),
      updated_at = now()
  where p.id in (current_room.host_id, current_room.guest_id);

  update public.online_rooms r
  set status = 'finished', revision = r.revision + 1, updated_at = now()
  where r.code = $1;
end;
$$;

create or replace function public.write_game_log(log_level text, event_name text, error_code text, metadata jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  clean_metadata jsonb := coalesce($4, '{}'::jsonb);
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if $1 not in ('info', 'warning', 'error') then raise exception 'GeÃƒÂ§ersiz log seviyesi'; end if;
  if $2 !~ '^[a-z0-9_]{3,60}$' then raise exception 'GeÃƒÂ§ersiz olay adÃ„Â±'; end if;
  if char_length(coalesce($3, '')) > 24 then raise exception 'Hata kodu ÃƒÂ§ok uzun'; end if;
  if jsonb_typeof(clean_metadata) <> 'object' or octet_length(clean_metadata::text) > 2000 then
    raise exception 'GeÃƒÂ§ersiz log ayrÃ„Â±ntÃ„Â±sÃ„Â±';
  end if;

  clean_metadata := clean_metadata - 'key' - 'token' - 'secret' - 'password'
    - 'player_name' - 'player_ids' - 'squad' - 'supabase_url';
  insert into public.game_logs(user_id, level, event, error_code, metadata)
  values (auth.uid(), $1, $2, coalesce($3, ''), clean_metadata);

  delete from public.game_logs g where g.created_at < now() - interval '30 days';
end;
$$;

revoke all on function public.create_online_room(text) from public, anon;
revoke all on function public.join_online_room(text, text) from public, anon;
revoke all on function public.set_online_ready(text, boolean) from public, anon;
revoke all on function public.start_online_room(text) from public, anon;
revoke all on function public.leave_online_room(text) from public, anon;
revoke all on function public.start_online_squad_match(text, jsonb) from public, anon;
revoke all on function public.submit_online_squad(text, jsonb) from public, anon;
revoke all on function public.begin_online_selection(text) from public, anon;
revoke all on function public.submit_online_ban(text, text) from public, anon;
revoke all on function public.begin_online_reveal(text) from public, anon;
revoke all on function public.speed_up_online_reveal(text) from public, anon;
revoke all on function public.find_online_match(text) from public, anon;
revoke all on function public.cancel_online_matchmaking() from public, anon;
revoke all on function public.finish_online_match(text, numeric, numeric, numeric) from public, anon;
revoke all on function public.write_game_log(text, text, text, jsonb) from public, anon;
grant execute on function public.create_online_room(text) to authenticated;
grant execute on function public.join_online_room(text, text) to authenticated;
grant execute on function public.set_online_ready(text, boolean) to authenticated;
grant execute on function public.start_online_room(text) to authenticated;
grant execute on function public.leave_online_room(text) to authenticated;
grant execute on function public.start_online_squad_match(text, jsonb) to authenticated;
grant execute on function public.submit_online_squad(text, jsonb) to authenticated;
grant execute on function public.begin_online_selection(text) to authenticated;
grant execute on function public.submit_online_ban(text, text) to authenticated;
grant execute on function public.begin_online_reveal(text) to authenticated;
grant execute on function public.speed_up_online_reveal(text) to authenticated;
grant execute on function public.find_online_match(text) to authenticated;
grant execute on function public.cancel_online_matchmaking() to authenticated;
grant execute on function public.finish_online_match(text, numeric, numeric, numeric) to authenticated;
grant execute on function public.write_game_log(text, text, text, jsonb) to authenticated;

-- Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Liderlik Tablosu Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
create or replace function public.get_leaderboard(limit_count integer default 50)
returns table(rank bigint, display_name text, rating integer, wins integer, matches integer)
language sql
security definer
set search_path = public
as $$
  select
    row_number() over (order by rating desc) as rank,
    display_name,
    rating,
    wins,
    matches
  from public.online_profiles
  order by rating desc
  limit least(limit_count, 100);
$$;
grant execute on function public.get_leaderboard(integer) to authenticated;

-- Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Eski Oda / Kuyruk Temizleme Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
create or replace function public.cleanup_stale_rooms()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.online_rooms
  where status in ('closed', 'finished')
    and updated_at < now() - interval '7 days';
  delete from public.online_matchmaking_queue
  where joined_at < now() - interval '5 minutes';
$$;
grant execute on function public.cleanup_stale_rooms() to authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'online_rooms'
  ) then
    alter publication supabase_realtime add table public.online_rooms;
  end if;
end $$;

-- Phase 2, 3 & 4 additions
alter table public.online_rooms add column if not exists end_time timestamptz;
alter table public.online_rooms add column if not exists reveal_step integer not null default 0;

alter table public.online_profiles add column if not exists level integer not null default 1;
alter table public.online_profiles add column if not exists xp integer not null default 0;
alter table public.online_profiles add column if not exists daily_streak integer not null default 0;
alter table public.online_profiles add column if not exists last_login_date date;
alter table public.online_profiles add column if not exists best_diff integer;
alter table public.online_profiles add column if not exists match_history jsonb not null default '[]'::jsonb;

create or replace function public.start_online_squad_match(room_code text, setup jsonb)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  if $2 is null or jsonb_typeof($2) <> 'object' then raise exception 'Geçerli kura bilgisi gerekli'; end if;
  update public.online_rooms r
  set status = 'playing', game_setup = $2, host_locked = false, guest_locked = false,
      host_selection_started_at = null, guest_selection_started_at = null, reveal_fast = false,
      host_banned_team_id = null, guest_banned_team_id = null,
      round_id = gen_random_uuid(), end_time = now() + interval '90 seconds', reveal_step = 0,
      revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.host_id = auth.uid() and r.status in ('waiting', 'revealing', 'finished')
    and r.guest_id is not null and r.host_ready and r.guest_ready;
  get diagnostics changed = row_count;
  if changed = 0 then raise exception 'İki oyuncu hazır değil veya oda kurucusu değilsin'; end if;
  delete from public.online_squads s where s.room_code = $1;
  return query select r.* from public.online_rooms r where r.code = $1;
end;
$$;

create or replace function public.submit_online_squad(room_code text, selected_players jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
  player_side text;
begin
  if jsonb_typeof($2) <> 'array' or jsonb_array_length($2) > 7 then
    raise exception 'Kadro en fazla 7 futbolcu içerebilir';
  end if;
  select * into current_room from public.online_rooms r where r.code = $1 for update;
  if not found or current_room.status <> 'playing' then raise exception 'Oda seçim kabul etmiyor'; end if;
  if current_room.host_id = auth.uid() then player_side := 'host';
  elsif current_room.guest_id = auth.uid() then player_side := 'guest';
  else raise exception 'Bu odanın oyuncusu değilsin';
  end if;

  if player_side = 'host' and current_room.host_locked then raise exception 'Kadro zaten kilitli'; end if;
  if player_side = 'guest' and current_room.guest_locked then raise exception 'Kadro zaten kilitli'; end if;

  insert into public.online_squads(room_code, owner_id, side, player_ids)
  values ($1, auth.uid(), player_side, $2)
  on conflict on constraint online_squads_pkey do update
    set owner_id = excluded.owner_id, player_ids = excluded.player_ids, submitted_at = now();

  update public.online_rooms r
  set host_locked = case when player_side = 'host' then true else r.host_locked end,
      guest_locked = case when player_side = 'guest' then true else r.guest_locked end,
      end_time = case
        when player_side = 'host' and not r.guest_locked then least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        when player_side = 'guest' and not r.host_locked then least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        else r.end_time end,
      revision = r.revision + 1, updated_at = now()
  where r.code = $1;
end;
$$;

create or replace function public.advance_reveal(room_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  update public.online_rooms r
  set reveal_step = r.reveal_step + 1, revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.status = 'revealing' and r.host_id = auth.uid();
  get diagnostics changed = row_count;
  if changed = 0 then raise exception 'Yetkiniz yok veya oda uygun değil'; end if;
end;
$$;
grant execute on function public.advance_reveal(text) to authenticated;

create or replace function public.submit_online_squad(room_code text, selected_players jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
  player_side text;
  opponent_ban text;
  p record;
begin
  if jsonb_typeof($2) <> 'array' or jsonb_array_length($2) > 7 then
    raise exception 'Kadro en fazla 7 futbolcu içerebilir';
  end if;
  select * into current_room from public.online_rooms r where r.code = $1 for update;
  if not found or current_room.status <> 'playing' then raise exception 'Oda seçim kabul etmiyor'; end if;
  if current_room.host_id = auth.uid() then 
    player_side := 'host';
    opponent_ban := current_room.guest_banned_team_id;
  elsif current_room.guest_id = auth.uid() then 
    player_side := 'guest';
    opponent_ban := current_room.host_banned_team_id;
  else raise exception 'Bu odanın oyuncusu değilsin';
  end if;

  if player_side = 'host' and current_room.host_locked then raise exception 'Kadro zaten kilitli'; end if;
  if player_side = 'guest' and current_room.guest_locked then raise exception 'Kadro zaten kilitli'; end if;

  if opponent_ban is not null then
    for p in select * from jsonb_array_elements($2) loop
      if p.value->>'team_id' = opponent_ban then
        raise exception 'Banlı takımdan futbolcu seçemezsiniz';
      end if;
    end loop;
  end if;

  insert into public.online_squads(room_code, owner_id, side, player_ids)
  values ($1, auth.uid(), player_side, (select jsonb_agg(v->>'id') from jsonb_array_elements($2) v))
  on conflict on constraint online_squads_pkey do update
    set owner_id = excluded.owner_id, player_ids = excluded.player_ids, submitted_at = now();

  update public.online_rooms r
  set host_locked = case when player_side = 'host' then true else r.host_locked end,
      guest_locked = case when player_side = 'guest' then true else r.guest_locked end,
      end_time = case
        when player_side = 'host' and not r.guest_locked then least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        when player_side = 'guest' and not r.host_locked then least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        else r.end_time end,
      revision = r.revision + 1, updated_at = now()
  where r.code = $1;

  update public.online_rooms r
  set status = 'ready', revision = r.revision + 1, updated_at = now()
  where r.code = $1 and r.host_locked and r.guest_locked and r.status = 'playing';
end;
$$;
alter table public.online_profiles add column if not exists last_minute_stage integer not null default 0;
alter table public.online_rooms add column if not exists host_avatar_id text; alter table public.online_rooms add column if not exists guest_avatar_id text;
create or replace function public.create_online_room(player_name text, p_avatar_id text default null)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  new_code text;
  attempt integer := 0;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if char_length(trim(player_name)) not between 1 and 18 then raise exception 'Oyuncu adı 1-18 karakter olmalı'; end if;

  insert into public.online_profiles(id, display_name) values (auth.uid(), trim(player_name))
  on conflict (id) do update set display_name = excluded.display_name, updated_at = now();

  loop
    new_code := (100000 + floor(random() * 900000))::integer::text;
    begin
      insert into public.online_rooms(code, host_id, host_name, host_avatar_id)
      values (new_code, auth.uid(), trim(player_name), p_avatar_id);
      exit;
    exception when unique_violation then
      attempt := attempt + 1;
      if attempt >= 100 then raise exception 'Oda kodu üretilemedi'; end if;
    end;
  end loop;
  return query select r.* from public.online_rooms r where r.code = new_code;
end;
$$;

create or replace function public.join_online_room(room_code text, player_name text, p_avatar_id text default null)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if $1 !~ '^[0-9]{6}$' then raise exception 'Oda kodu 6 haneli olmalı'; end if;
  if char_length(trim(player_name)) not between 1 and 18 then raise exception 'Oyuncu adı 1-18 karakter olmalı'; end if;

  insert into public.online_profiles(id, display_name) values (auth.uid(), trim(player_name))
  on conflict (id) do update set display_name = excluded.display_name, updated_at = now();

  update public.online_rooms
  set guest_id = auth.uid(),
      guest_name = trim(player_name),
      guest_avatar_id = p_avatar_id,
      guest_ready = false,
      guest_connected = true,
      revision = revision + 1
  where code = $1 and guest_id is null and status = 'waiting' and host_id != auth.uid();
  
  get diagnostics changed = row_count;
  if changed = 0 then raise exception 'Oda dolu, bulunamadı veya kendinizle oynayamazsınız'; end if;

  return query select r.* from public.online_rooms r where r.code = $1;
end;
$$;
-- Add trigger to auto-generate friend_code if it is null
create or replace function public.auto_generate_friend_code()
returns trigger
language plpgsql
as $$
declare
  new_code text;
  is_unique boolean;
begin
  if NEW.friend_code is null or NEW.friend_code = '' then
    loop
      -- Generate a random 6-character uppercase alphanumeric string
      new_code := upper(substring(md5(random()::text), 1, 6));
      
      -- Check if it is unique
      select not exists(select 1 from public.online_profiles where friend_code = new_code) into is_unique;
      
      if is_unique then
        NEW.friend_code := new_code;
        exit;
      end if;
    end loop;
  end if;
  return NEW;
end;
$$;

drop trigger if exists ensure_friend_code on public.online_profiles;
create trigger ensure_friend_code
before insert on public.online_profiles
for each row
execute function public.auto_generate_friend_code();
alter table public.online_matchmaking_queue add column if not exists avatar_id text;

drop function if exists public.find_online_match(text);
create or replace function public.find_online_match(player_name text, p_avatar_id text default null)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  opponent public.online_matchmaking_queue%rowtype;
  new_code text;
  attempt integer := 0;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if char_length(trim($1)) not between 1 and 18 then raise exception 'Oyuncu adı 1-18 karakter olmalı'; end if;

  insert into public.online_profiles(id, display_name) values (auth.uid(), trim($1))
  on conflict (id) do update set display_name = excluded.display_name, updated_at = now();

  perform pg_advisory_xact_lock(hashtext('futbol_meydani_matchmaking'));

  delete from public.online_matchmaking_queue q where q.joined_at < now() - interval '2 minutes';

  return query
  select r.* from public.online_rooms r
  where r.status = 'waiting' and r.matchmaking and r.guest_id is not null
    and (r.host_id = auth.uid() or r.guest_id = auth.uid())
  order by r.created_at desc limit 1;
  if found then
    delete from public.online_matchmaking_queue q where q.user_id = auth.uid();
    return;
  end if;

  select q.* into opponent
  from public.online_matchmaking_queue q
  where q.user_id <> auth.uid()
  order by q.joined_at
  for update skip locked
  limit 1;


  if opponent.user_id is null then
    insert into public.online_matchmaking_queue(user_id, player_name, avatar_id, joined_at)
    values (auth.uid(), trim($1), p_avatar_id, now())
    on conflict (user_id) do update set player_name = excluded.player_name, avatar_id = excluded.avatar_id;
    return;
  end if;

  delete from public.online_matchmaking_queue q where q.user_id in (opponent.user_id, auth.uid());
  loop
    new_code := (100000 + floor(random() * 900000))::integer::text;
    begin
      insert into public.online_rooms(
        code, host_id, host_name, host_avatar_id, host_ready, guest_id, guest_name, guest_avatar_id, guest_ready,
        host_connected, guest_connected, matchmaking
      ) values (
        new_code, opponent.user_id, opponent.player_name, opponent.avatar_id, true,
        auth.uid(), trim($1), p_avatar_id, true, true, true, true
      );
      exit;
    exception when unique_violation then
      attempt := attempt + 1;
      if attempt > 10 then raise exception 'Oda kodu bulunamadi'; end if;
    end;
  end loop;

  return query select * from public.online_rooms where code = new_code;
end;
$$;
grant execute on function public.find_online_match(text, text) to authenticated;


-- Arkadaşlık Sistemi
create table if not exists public.friends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  friend_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  unique(user_id, friend_id)
);

alter table public.friends enable row level security;
drop policy if exists "Friends select" on public.friends;
create policy "Friends select" on public.friends for select to authenticated using (auth.uid() = user_id or auth.uid() = friend_id);
drop policy if exists "Friends insert" on public.friends;
create policy "Friends insert" on public.friends for insert to authenticated with check (auth.uid() = user_id);
drop policy if exists "Friends update" on public.friends;
create policy "Friends update" on public.friends for update to authenticated using (auth.uid() = friend_id or auth.uid() = user_id);
drop policy if exists "Friends delete" on public.friends;
create policy "Friends delete" on public.friends for delete to authenticated using (auth.uid() = user_id or auth.uid() = friend_id);


-- Oyun Davetleri Sistemi
create table if not exists public.game_invites (
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null references auth.users(id) on delete cascade,
  to_id uuid not null references auth.users(id) on delete cascade,
  room_code text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'expired')),
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

alter table public.game_invites enable row level security;
drop policy if exists "Game invites select" on public.game_invites;
create policy "Game invites select" on public.game_invites for select to authenticated using (auth.uid() = from_id or auth.uid() = to_id);
drop policy if exists "Game invites insert" on public.game_invites;
create policy "Game invites insert" on public.game_invites for insert to authenticated with check (auth.uid() = from_id);
drop policy if exists "Game invites update" on public.game_invites;
create policy "Game invites update" on public.game_invites for update to authenticated using (auth.uid() = from_id or auth.uid() = to_id);


-- Realtime izinleri (game_invites ve friends tabloları için)
begin;
  do $$ 
  begin
    if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
      execute 'alter publication supabase_realtime add table public.friends';
      execute 'alter publication supabase_realtime add table public.game_invites';
    end if;
  exception when others then
    -- Table might already be in publication
  end $$;
commit;

