create or replace function public.touch_online_presence(active_code text, is_connected boolean default true)
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
      host_last_seen_at = now(),
      updated_at = case when $2 then r.updated_at else now() end
  where r.code = $1
    and r.host_id = v_user_id
    and r.status not in ('closed', 'finished');

  if found then return; end if;

  update public.online_rooms r
  set guest_connected = $2,
      guest_last_seen_at = now(),
      updated_at = case when $2 then r.updated_at else now() end
  where r.code = $1
    and r.guest_id = v_user_id
    and r.status not in ('closed', 'finished');
end;
$$;
