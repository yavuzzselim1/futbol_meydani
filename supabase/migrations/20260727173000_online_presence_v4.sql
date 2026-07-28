-- Futbol Meydani - Faster presence detection v4
-- v3 daha önce çalıştırılmış olsa da bu dosya ayrıca bir kez çalıştırılmalıdır.

begin;

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

revoke all on function public.cleanup_online_recovery() from public, anon;
grant execute on function public.cleanup_online_recovery() to authenticated;

commit;
