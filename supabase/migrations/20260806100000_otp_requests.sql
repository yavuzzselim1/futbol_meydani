-- 20260806100000_otp_requests.sql
-- Kendi SMTP sunucumuz uzerinden gonderilen e-posta OTP kodlari icin
-- kisa omurlu kayit tablosu. Yalnizca Edge Function'lar (service_role)
-- erisebilir; anon/authenticated icin hicbir yetki verilmez.

create table if not exists public.otp_requests (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  code_hash text not null,
  attempts integer not null default 0,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  consumed_at timestamptz
);

create index if not exists otp_requests_email_idx on public.otp_requests (email);
create index if not exists otp_requests_email_active_idx
  on public.otp_requests (email, created_at desc)
  where consumed_at is null;

alter table public.otp_requests enable row level security;
revoke all on public.otp_requests from anon, authenticated;
-- Bu projede service_role icin varsayilan tablo yetkileri otomatik
-- gelmiyor (diger tablolar hep SECURITY DEFINER fonksiyonlar uzerinden
-- yazildigi icin bu simdiye kadar fark edilmemis); Edge Function'lar
-- servis anahtariyla dogrudan bu tabloya erisecegi icin acikca gerekli.
grant select, insert, update, delete on public.otp_requests to service_role;

-- Eski/kullanilmis kayitlari temizlemek icin yardimci fonksiyon
-- (Edge Function'lar her cagriyi yaptiginda cagirilir, ayrica cron gerektirmez).
create or replace function public.cleanup_expired_otp_requests()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.otp_requests
  where expires_at < now() - interval '1 day';
$$;

revoke all on function public.cleanup_expired_otp_requests() from public, anon, authenticated;
