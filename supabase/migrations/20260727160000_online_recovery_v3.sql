-- Futbol Meydani - Online recovery and presence v3
-- Supabase Dashboard > SQL Editor ekraninda bu dosyanin tamamini bir kez calistirin.

begin;

alter table public.online_rooms
  add column if not exists host_last_seen_at timestamptz not null default now(),
  add column if not exists guest_last_seen_at timestamptz,
  add column if not exists closed_by uuid references auth.users(id) on delete set null,
  add column if not exists close_reason text,
  add column if not exists closed_from_status text,
  add column if not exists closed_at timestamptz,
  add column if not exists forfeit_winner_id uuid references auth.users(id) on delete set null;

create index if not exists online_rooms_host_active_idx
  on public.online_rooms(host_id, updated_at desc)
  where status not in ('closed', 'finished');

create index if not exists online_rooms_guest_active_idx
  on public.online_rooms(guest_id, updated_at desc)
  where guest_id is not null and status not in ('closed', 'finished');


create or replace function public.cleanup_online_recovery()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.online_rooms r
  set host_connected = false,
      revision = r.revision + 1,
      updated_at = now()
  where r.host_connected
    and r.host_last_seen_at < now() - interval '15 seconds';

  update public.online_rooms r
  set guest_connected = false,
      revision = r.revision + 1,
      updated_at = now()
  where r.guest_connected
    and coalesce(r.guest_last_seen_at, r.created_at)
        < now() - interval '15 seconds';

  update public.game_invites i
  set status = 'expired'
  where i.status = 'pending'
    and i.expires_at <= now();

  delete from public.online_matchmaking_queue q
  where q.joined_at < now() - interval '5 minutes';

  update public.online_rooms r
  set status = 'closed',
      close_reason = 'stale_room',
      closed_from_status = r.status,
      closed_at = now(),
      revision = r.revision + 1,
      updated_at = now()
  where r.status not in ('closed', 'finished')
    and not r.host_connected
    and (r.guest_id is null or not r.guest_connected)
    and greatest(
      r.host_last_seen_at,
      coalesce(r.guest_last_seen_at, r.created_at)
    ) < now() - interval '5 minutes';

  delete from public.online_rooms r
  where r.status in ('closed', 'finished')
    and r.updated_at < now() - interval '7 days';
end;
$$;


create or replace function public.touch_online_presence(
  room_code text,
  is_connected boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'Oturum gerekli';
  end if;

  perform public.cleanup_online_recovery();

  update public.online_rooms r
  set host_connected = $2,
      revision = r.revision + 1,
      host_last_seen_at = now(),
      updated_at = case when $2 then r.updated_at else now() end
  where r.code = $1
    and r.host_id = v_user_id
    and r.status not in ('closed', 'finished');

  if found then return; end if;

  update public.online_rooms r
  set guest_connected = $2,
      revision = r.revision + 1,
      guest_last_seen_at = now(),
      updated_at = case when $2 then r.updated_at else now() end
  where r.code = $1
    and r.guest_id = v_user_id
    and r.status not in ('closed', 'finished');
end;
$$;


create or replace function public.resume_online_room()
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  active_code text;
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli';
  end if;

  perform public.cleanup_online_recovery();

  select r.code
  into active_code
  from public.online_rooms r
  where (r.host_id = auth.uid() or r.guest_id = auth.uid())
    and r.status not in ('closed', 'finished')
  order by
    case r.status
      when 'revealing' then 1
      when 'ready' then 2
      when 'playing' then 3
      else 4
    end,
    r.updated_at desc
  limit 1;

  if active_code is null then return; end if;

  perform public.touch_online_presence(active_code, true);

  return query
  select r.*
  from public.online_rooms r
  where r.code = active_code;
end;
$$;


drop function if exists public.create_online_room(text, text);
create or replace function public.create_online_room(
  player_name text,
  p_avatar_id text default null
)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  active_code text;
  new_code text;
  attempt integer := 0;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if char_length(trim(player_name)) not between 1 and 18 then
    raise exception 'Oyuncu adi 1-18 karakter olmali';
  end if;

  perform public.cleanup_online_recovery();

  select r.code into active_code
  from public.online_rooms r
  where (r.host_id = auth.uid() or r.guest_id = auth.uid())
    and r.status not in ('closed', 'finished')
  order by r.updated_at desc
  limit 1;

  if active_code is not null then
    perform public.touch_online_presence(active_code, true);
    return query select r.* from public.online_rooms r where r.code = active_code;
    return;
  end if;

  insert into public.online_profiles(id, display_name)
  values (auth.uid(), trim(player_name))
  on conflict (id) do update
    set display_name = excluded.display_name, updated_at = now();

  loop
    new_code := (100000 + floor(random() * 900000))::integer::text;
    begin
      insert into public.online_rooms(
        code, host_id, host_name, host_avatar_id,
        host_connected, host_last_seen_at
      )
      values (
        new_code, auth.uid(), trim(player_name), p_avatar_id, true, now()
      );
      exit;
    exception when unique_violation then
      attempt := attempt + 1;
      if attempt >= 100 then raise exception 'Oda kodu uretilemedi'; end if;
    end;
  end loop;

  return query
  select r.* from public.online_rooms r where r.code = new_code;
end;
$$;


drop function if exists public.join_online_room(text, text, text);
create or replace function public.join_online_room(
  room_code text,
  player_name text,
  p_avatar_id text default null
)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  active_code text;
  changed integer;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli'; end if;
  if $1 !~ '^[0-9]{6}$' then raise exception 'Oda kodu 6 haneli olmali'; end if;
  if char_length(trim(player_name)) not between 1 and 18 then
    raise exception 'Oyuncu adi 1-18 karakter olmali';
  end if;

  perform public.cleanup_online_recovery();

  select r.code into active_code
  from public.online_rooms r
  where (r.host_id = auth.uid() or r.guest_id = auth.uid())
    and r.status not in ('closed', 'finished')
  order by r.updated_at desc
  limit 1;

  if active_code is not null then
    if active_code <> $1 then
      raise exception 'Devam eden baska bir odan var';
    end if;
    perform public.touch_online_presence(active_code, true);
    return query select r.* from public.online_rooms r where r.code = active_code;
    return;
  end if;

  insert into public.online_profiles(id, display_name)
  values (auth.uid(), trim(player_name))
  on conflict (id) do update
    set display_name = excluded.display_name, updated_at = now();

  update public.online_rooms r
  set guest_id = auth.uid(),
      guest_name = trim(player_name),
      guest_avatar_id = p_avatar_id,
      guest_ready = false,
      guest_connected = true,
      guest_last_seen_at = now(),
      revision = r.revision + 1,
      updated_at = now()
  where r.code = $1
    and r.guest_id is null
    and r.status = 'waiting'
    and r.host_id <> auth.uid();

  get diagnostics changed = row_count;
  if changed = 0 then
    raise exception 'Oda dolu, bulunamadi veya kendinle oynayamazsin';
  end if;

  return query select r.* from public.online_rooms r where r.code = $1;
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
  leaving_user uuid := auth.uid();
  winning_user uuid;
  target_value numeric;
begin
  if leaving_user is null then return; end if;

  select *
  into current_room
  from public.online_rooms r
  where r.code = $1
  for update;

  if not found then return; end if;

  if current_room.status = 'waiting'
     and current_room.host_id = leaving_user
     and current_room.guest_id is not null then
    update public.online_rooms r
    set host_id = current_room.guest_id,
        host_name = current_room.guest_name,
        host_avatar_id = current_room.guest_avatar_id,
        host_ready = current_room.guest_ready,
        host_connected = current_room.guest_connected,
        host_last_seen_at = coalesce(current_room.guest_last_seen_at, now()),
        guest_id = null,
        guest_name = null,
        guest_avatar_id = null,
        guest_ready = false,
        guest_connected = false,
        guest_last_seen_at = null,
        revision = r.revision + 1,
        updated_at = now()
    where r.code = $1;
    return;
  end if;

  if current_room.status = 'waiting'
     and current_room.guest_id = leaving_user then
    update public.online_rooms r
    set guest_id = null,
        guest_name = null,
        guest_avatar_id = null,
        guest_ready = false,
        guest_connected = false,
        guest_last_seen_at = null,
        revision = r.revision + 1,
        updated_at = now()
    where r.code = $1;
    return;
  end if;

  if current_room.host_id <> leaving_user
     and current_room.guest_id <> leaving_user then
    return;
  end if;

  winning_user := case
    when current_room.host_id = leaving_user then current_room.guest_id
    else current_room.host_id
  end;

  if current_room.status in ('playing', 'ready', 'revealing')
     and current_room.guest_id is not null
     and winning_user is not null then
    target_value := coalesce(
      nullif(current_room.game_setup ->> 'target', '')::numeric,
      0
    );

    insert into public.online_match_history(
      round_id, room_code, host_id, guest_id, host_name, guest_name,
      host_total, guest_total, target, winner_id
    )
    values (
      current_room.round_id,
      current_room.code,
      current_room.host_id,
      current_room.guest_id,
      current_room.host_name,
      current_room.guest_name,
      case when winning_user = current_room.host_id then target_value else 0 end,
      case when winning_user = current_room.guest_id then target_value else 0 end,
      target_value,
      winning_user
    )
    on conflict (round_id) do nothing;

    if found then
      update public.online_profiles p
      set matches = p.matches + 1,
          wins = p.wins + case when p.id = winning_user then 1 else 0 end,
          losses = p.losses + case when p.id = leaving_user then 1 else 0 end,
          rating = greatest(
            100,
            p.rating + case when p.id = winning_user then 15 else -15 end
          ),
          updated_at = now()
      where p.id in (current_room.host_id, current_room.guest_id);
    end if;
  end if;

  update public.online_rooms r
  set status = 'closed',
      closed_by = leaving_user,
      close_reason = 'player_left',
      closed_from_status = current_room.status,
      closed_at = now(),
      forfeit_winner_id = winning_user,
      host_connected = case
        when current_room.host_id = leaving_user then false
        else r.host_connected
      end,
      guest_connected = case
        when current_room.guest_id = leaving_user then false
        else r.guest_connected
      end,
      revision = r.revision + 1,
      updated_at = now()
  where r.code = $1;
end;
$$;


create or replace function public.claim_online_disconnect_win(room_code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
  winner uuid := auth.uid();
  disconnected_user uuid;
  disconnected_at timestamptz;
  target_value numeric;
begin
  if winner is null then raise exception 'Oturum gerekli'; end if;

  select *
  into current_room
  from public.online_rooms r
  where r.code = $1
  for update;

  if not found
     or current_room.status not in ('playing', 'ready', 'revealing')
     or current_room.guest_id is null then
    raise exception 'Bu mac icin hukmen galibiyet kullanilamaz';
  end if;

  if current_room.host_id = winner then
    disconnected_user := current_room.guest_id;
    disconnected_at := coalesce(
      current_room.guest_last_seen_at,
      current_room.created_at
    );
    if current_room.guest_connected then
      raise exception 'Rakip halen bagli';
    end if;
  elsif current_room.guest_id = winner then
    disconnected_user := current_room.host_id;
    disconnected_at := current_room.host_last_seen_at;
    if current_room.host_connected then
      raise exception 'Rakip halen bagli';
    end if;
  else
    raise exception 'Bu odanin oyuncusu degilsin';
  end if;

  if disconnected_at > now() - interval '60 seconds' then
    raise exception 'Rakibin yeniden baglanma suresi henuz dolmadi';
  end if;

  target_value := coalesce(
    nullif(current_room.game_setup ->> 'target', '')::numeric,
    0
  );

  insert into public.online_match_history(
    round_id, room_code, host_id, guest_id, host_name, guest_name,
    host_total, guest_total, target, winner_id
  )
  values (
    current_room.round_id,
    current_room.code,
    current_room.host_id,
    current_room.guest_id,
    current_room.host_name,
    current_room.guest_name,
    case when winner = current_room.host_id then target_value else 0 end,
    case when winner = current_room.guest_id then target_value else 0 end,
    target_value,
    winner
  )
  on conflict (round_id) do nothing;

  if found then
    update public.online_profiles p
    set matches = p.matches + 1,
        wins = p.wins + case when p.id = winner then 1 else 0 end,
        losses = p.losses + case when p.id = disconnected_user then 1 else 0 end,
        rating = greatest(
          100,
          p.rating + case when p.id = winner then 15 else -15 end
        ),
        updated_at = now()
    where p.id in (current_room.host_id, current_room.guest_id);
  end if;

  update public.online_rooms r
  set status = 'closed',
      closed_by = disconnected_user,
      close_reason = 'disconnect_timeout',
      closed_from_status = current_room.status,
      closed_at = now(),
      forfeit_winner_id = winner,
      revision = r.revision + 1,
      updated_at = now()
  where r.code = $1;
end;
$$;


revoke all on function public.cleanup_online_recovery() from public, anon;
revoke all on function public.touch_online_presence(text, boolean) from public, anon;
revoke all on function public.resume_online_room() from public, anon;
revoke all on function public.create_online_room(text, text) from public, anon;
revoke all on function public.join_online_room(text, text, text) from public, anon;
revoke all on function public.leave_online_room(text) from public, anon;
revoke all on function public.claim_online_disconnect_win(text) from public, anon;

grant execute on function public.cleanup_online_recovery() to authenticated;
grant execute on function public.touch_online_presence(text, boolean) to authenticated;
grant execute on function public.resume_online_room() to authenticated;
grant execute on function public.create_online_room(text, text) to authenticated;
grant execute on function public.join_online_room(text, text, text) to authenticated;
grant execute on function public.leave_online_room(text) to authenticated;
grant execute on function public.claim_online_disconnect_win(text) to authenticated;

commit;
