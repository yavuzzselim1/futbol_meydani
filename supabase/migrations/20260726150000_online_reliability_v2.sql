-- Futbol Meydani - Online reliability v2
-- Eski migration dosyasini degistirmeyin.

begin;

-- Avatar destegi eklenirken geride kalan eski fonksiyonlar.
drop function if exists public.create_online_room(text);
drop function if exists public.join_online_room(text, text);

-- Eski ve gereğinden geniş politikaları temizle.
drop policy if exists "kullanicilar_ekleyebilir"
  on public.online_profiles;

drop policy if exists "kullanicilar_profilleri_okuyabilir"
  on public.online_profiles;

drop policy if exists "Users can view own friends"
  on public.friends;

drop policy if exists "Users can insert friends"
  on public.friends;

drop policy if exists "Users can update friends"
  on public.friends;

drop policy if exists "Users can delete friends"
  on public.friends;

drop policy if exists "Users can view own invites"
  on public.game_invites;

drop policy if exists "Users can insert invites"
  on public.game_invites;

drop policy if exists "Users can update invites"
  on public.game_invites;

drop policy if exists "Users can delete invites"
  on public.game_invites;


-- Yeni tur başladığında sayaç henüz başlamaz.
create or replace function public.start_online_squad_match(
  room_code text,
  setup jsonb
)
returns setof public.online_rooms
language plpgsql
security definer
set search_path = public
as $$
declare
  changed integer;
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli';
  end if;

  if $2 is null or jsonb_typeof($2) <> 'object' then
    raise exception 'Geçerli kura bilgisi gerekli';
  end if;

  update public.online_rooms r
  set status = 'playing',
      game_setup = $2,
      host_locked = false,
      guest_locked = false,
      host_selection_started_at = null,
      guest_selection_started_at = null,
      reveal_fast = false,
      host_banned_team_id = null,
      guest_banned_team_id = null,
      round_id = gen_random_uuid(),
      end_time = null,
      reveal_step = 0,
      revision = r.revision + 1,
      updated_at = now()
  where r.code = $1
    and r.host_id = auth.uid()
    and r.status in ('waiting', 'revealing', 'finished')
    and r.guest_id is not null
    and r.host_ready
    and r.guest_ready;

  get diagnostics changed = row_count;

  if changed = 0 then
    raise exception
      'İki oyuncu hazır değil, oda uygun değil veya oda kurucusu değilsin';
  end if;

  delete from public.online_squads s
  where s.room_code = $1;

  return query
  select r.*
  from public.online_rooms r
  where r.code = $1;
end;
$$;


-- İkinci ban geldiğinde ortak sunucu sayacı başlar.
create or replace function public.submit_online_ban(
  room_code text,
  team_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli';
  end if;

  select *
  into current_room
  from public.online_rooms r
  where r.code = $1
  for update;

  if not found or current_room.status <> 'playing' then
    raise exception 'Oda takım banı kabul etmiyor';
  end if;

  if current_room.host_id <> auth.uid()
     and current_room.guest_id <> auth.uid() then
    raise exception 'Bu odanın oyuncusu değilsin';
  end if;

  if current_room.game_setup is null
     or jsonb_typeof(
       current_room.game_setup -> 'team_ids'
     ) <> 'array'
     or not exists (
       select 1
       from jsonb_array_elements_text(
         current_room.game_setup -> 'team_ids'
       ) value
       where value = $2
     ) then
    raise exception 'Bu takım kurada bulunmuyor';
  end if;

  if current_room.host_id = auth.uid() then
    if current_room.host_banned_team_id is not null then
      raise exception 'Takım banın zaten kilitlendi';
    end if;

    update public.online_rooms r
    set host_banned_team_id = $2,
        revision = r.revision + 1,
        updated_at = now()
    where r.code = $1;
  else
    if current_room.guest_banned_team_id is not null then
      raise exception 'Takım banın zaten kilitlendi';
    end if;

    update public.online_rooms r
    set guest_banned_team_id = $2,
        revision = r.revision + 1,
        updated_at = now()
    where r.code = $1;
  end if;

  update public.online_rooms r
  set end_time =
        coalesce(r.end_time, now() + interval '120 seconds'),
      host_selection_started_at =
        coalesce(r.host_selection_started_at, now()),
      guest_selection_started_at =
        coalesce(r.guest_selection_started_at, now()),
      revision = r.revision + 1,
      updated_at = now()
  where r.code = $1
    and r.status = 'playing'
    and r.host_banned_team_id is not null
    and r.guest_banned_team_id is not null;
end;
$$;


-- Eski istemcilerle uyumlu, tekrar çağrılabilir seçim başlangıcı.
create or replace function public.begin_online_selection(
  room_code text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  current_room public.online_rooms%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Oturum gerekli';
  end if;

  select *
  into current_room
  from public.online_rooms r
  where r.code = $1
  for update;

  if not found
     or current_room.status <> 'playing'
     or (
       current_room.host_id <> auth.uid()
       and current_room.guest_id <> auth.uid()
     ) then
    raise exception 'Kadro seçimi bu oda için başlatılamadı';
  end if;

  if current_room.host_banned_team_id is null
     or current_room.guest_banned_team_id is null then
    raise exception 'İki takım banı da tamamlanmalı';
  end if;

  update public.online_rooms r
  set end_time =
        coalesce(r.end_time, now() + interval '120 seconds'),
      host_selection_started_at =
        coalesce(r.host_selection_started_at, now()),
      guest_selection_started_at =
        coalesce(r.guest_selection_started_at, now()),
      revision = r.revision + 1,
      updated_at = now()
  where r.code = $1;
end;
$$;


-- RPC izinlerini yalnız giriş yapmış kullanıcılara ver.
revoke all
on function public.create_online_room(text, text)
from public, anon;

revoke all
on function public.join_online_room(text, text, text)
from public, anon;

revoke all
on function public.start_online_squad_match(text, jsonb)
from public, anon;

revoke all
on function public.submit_online_ban(text, text)
from public, anon;

revoke all
on function public.begin_online_selection(text)
from public, anon;


grant execute
on function public.create_online_room(text, text)
to authenticated;

grant execute
on function public.join_online_room(text, text, text)
to authenticated;

grant execute
on function public.start_online_squad_match(text, jsonb)
to authenticated;

grant execute
on function public.submit_online_ban(text, text)
to authenticated;

grant execute
on function public.begin_online_selection(text)
to authenticated;


-- Temizlik işlemi normal oyuncular tarafından çalıştırılmamalı.
revoke all
on function public.cleanup_stale_rooms()
from public, anon, authenticated;

commit;