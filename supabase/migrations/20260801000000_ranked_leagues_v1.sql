-- Migration: Online Ranked Leagues v1
-- Date: 2026-08-01

BEGIN;

-- 1. Tablolar ve Seed Verileri

-- 1.1 league_definitions
CREATE TABLE IF NOT EXISTS public.league_definitions (
  id text PRIMARY KEY,
  display_name text NOT NULL,
  tier smallint NOT NULL UNIQUE,
  base_trophies integer NOT NULL DEFAULT 0,
  promotion_trophies integer,
  promotion_min_matches integer,
  is_champions boolean NOT NULL DEFAULT false,
  color_hex text
);

ALTER TABLE public.league_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "league_def_read" ON public.league_definitions FOR SELECT TO authenticated USING (true);
-- No insert/update/delete for authenticated

INSERT INTO public.league_definitions (id, display_name, tier, base_trophies, promotion_trophies, promotion_min_matches, is_champions, color_hex) VALUES
  ('kirmizi',     'Kırmızı Meydan',       1,    0,  200, 10, false, '#FF453A'),
  ('beyaz',       'Beyaz Meydan',         2,  200,  450, 10, false, '#FFFFFF'),
  ('ikinci',      'İkinci Meydan',        3,  450,  750, 10, false, '#5EC8FF'),
  ('birinci',     'Birinci Meydan',       4,  750, 1200, 10, false, '#FFD166'),
  ('super',       'Süper Meydan',         5, 1200, NULL, NULL, false, '#B388FF'),
  ('sampiyonlar', 'Şampiyonlar Meydanı',  6,    0, NULL, NULL, true,  '#FF9F0A')
ON CONFLICT (id) DO UPDATE SET 
  display_name = EXCLUDED.display_name,
  tier = EXCLUDED.tier,
  base_trophies = EXCLUDED.base_trophies,
  promotion_trophies = EXCLUDED.promotion_trophies,
  promotion_min_matches = EXCLUDED.promotion_min_matches,
  is_champions = EXCLUDED.is_champions,
  color_hex = EXCLUDED.color_hex;

-- 1.2 competitive_seasons
CREATE TABLE IF NOT EXISTS public.competitive_seasons (
  id text PRIMARY KEY,
  status text NOT NULL CHECK (status IN ('active','closing','closed')),
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  queue_locked_at timestamptz,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_cs_starts_at ON public.competitive_seasons(starts_at);

ALTER TABLE public.competitive_seasons ENABLE ROW LEVEL SECURITY;
CREATE POLICY "seasons_read" ON public.competitive_seasons FOR SELECT TO authenticated USING (true);

-- 1.3 season_league_rules
CREATE TABLE IF NOT EXISTS public.season_league_rules (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  season_id text NOT NULL REFERENCES public.competitive_seasons(id) ON DELETE CASCADE,
  league_id text NOT NULL REFERENCES public.league_definitions(id) ON DELETE CASCADE,
  win_trophies integer NOT NULL,
  draw_trophies integer NOT NULL,
  loss_trophies integer NOT NULL,
  promotion_reward_coins integer NOT NULL DEFAULT 0,
  top5_rewards jsonb NOT NULL,
  top5_min_matches integer NOT NULL DEFAULT 15,
  champions_unlock_trophies integer,
  champions_unlock_matches integer,
  anti_farm_full_count integer NOT NULL DEFAULT 2,
  anti_farm_half_count integer NOT NULL DEFAULT 2,
  UNIQUE(season_id, league_id)
);

ALTER TABLE public.season_league_rules ENABLE ROW LEVEL SECURITY;
CREATE POLICY "slr_read" ON public.season_league_rules FOR SELECT TO authenticated USING (true);

-- 1.4 player_ladders
CREATE TABLE IF NOT EXISTS public.player_ladders (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  season_id text NOT NULL REFERENCES public.competitive_seasons(id) ON DELETE CASCADE,
  league_id text NOT NULL REFERENCES public.league_definitions(id) ON DELETE RESTRICT,
  ladder_type text NOT NULL CHECK (ladder_type IN ('normal','champions')),
  trophies integer NOT NULL DEFAULT 0 CHECK (trophies >= 0),
  matches_played integer NOT NULL DEFAULT 0,
  wins integer NOT NULL DEFAULT 0,
  draws integer NOT NULL DEFAULT 0,
  losses integer NOT NULL DEFAULT 0,
  peak_trophies integer NOT NULL DEFAULT 0,
  peak_reached_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, season_id, ladder_type)
);

CREATE INDEX idx_pl_season_league ON public.player_ladders(season_id, league_id, trophies DESC);
CREATE INDEX idx_pl_user_season ON public.player_ladders(user_id, season_id);
CREATE INDEX idx_pl_ranking ON public.player_ladders(season_id, ladder_type, league_id, trophies DESC, wins DESC, losses ASC, peak_reached_at ASC);

ALTER TABLE public.player_ladders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pl_read" ON public.player_ladders FOR SELECT TO authenticated USING (true);

-- 1.5 champions_qualifications
CREATE TABLE IF NOT EXISTS public.champions_qualifications (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  season_id text NOT NULL REFERENCES public.competitive_seasons(id) ON DELETE CASCADE,
  qualified_at timestamptz NOT NULL DEFAULT now(),
  trophies_at_qualification integer NOT NULL,
  matches_at_qualification integer NOT NULL,
  UNIQUE(user_id, season_id)
);

ALTER TABLE public.champions_qualifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "cq_read_own" ON public.champions_qualifications FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 1.6 ranked_matches
CREATE TABLE IF NOT EXISTS public.ranked_matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  season_id text NOT NULL REFERENCES public.competitive_seasons(id),
  league_id text NOT NULL REFERENCES public.league_definitions(id),
  ladder_type text NOT NULL CHECK (ladder_type IN ('normal','champions')),
  room_code text NOT NULL,
  host_id uuid NOT NULL REFERENCES auth.users(id),
  guest_id uuid NOT NULL REFERENCES auth.users(id),
  host_name text NOT NULL,
  guest_name text NOT NULL,
  status text NOT NULL DEFAULT 'in_progress' CHECK (status IN ('in_progress','finalized','cancelled','no_contest')),
  winner_id uuid REFERENCES auth.users(id),
  host_total numeric,
  guest_total numeric,
  target numeric,
  result_type text CHECK (result_type IN ('normal','forfeit','disconnect','timeout')),
  host_trophy_delta integer,
  guest_trophy_delta integer,
  anti_farm_factor real NOT NULL DEFAULT 1.0,
  finalized_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_rm_room ON public.ranked_matches(room_code) WHERE status = 'in_progress';
CREATE INDEX idx_rm_pair_day ON public.ranked_matches(
  LEAST(host_id, guest_id), GREATEST(host_id, guest_id), 
  league_id, CAST(created_at AT TIME ZONE 'UTC' AS DATE)
) WHERE status = 'finalized';
CREATE INDEX idx_rm_season ON public.ranked_matches(season_id, league_id, status);

ALTER TABLE public.ranked_matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rm_read" ON public.ranked_matches FOR SELECT TO authenticated USING (host_id = auth.uid() OR guest_id = auth.uid());

-- 1.7 match_submissions
CREATE TABLE IF NOT EXISTS public.match_submissions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id uuid NOT NULL REFERENCES public.ranked_matches(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  side text NOT NULL CHECK (side IN ('host','guest')),
  squad_payload jsonb NOT NULL,
  idempotency_key text NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(match_id, side),
  UNIQUE(idempotency_key)
);

ALTER TABLE public.match_submissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ms_read_own" ON public.match_submissions FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 1.8 trophy_transactions
CREATE TABLE IF NOT EXISTS public.trophy_transactions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  season_id text NOT NULL,
  league_id text NOT NULL,
  ladder_type text NOT NULL,
  match_id uuid NOT NULL REFERENCES public.ranked_matches(id),
  delta integer NOT NULL,
  base_delta integer NOT NULL,
  opponent_modifier integer NOT NULL DEFAULT 0,
  anti_farm_factor real NOT NULL DEFAULT 1.0,
  old_trophies integer NOT NULL,
  new_trophies integer NOT NULL,
  result text NOT NULL CHECK (result IN ('win','draw','loss')),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_tt_user_season ON public.trophy_transactions(user_id, season_id, created_at DESC);

ALTER TABLE public.trophy_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "tt_read_own" ON public.trophy_transactions FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 1.9 season_rankings
CREATE TABLE IF NOT EXISTS public.season_rankings (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  season_id text NOT NULL REFERENCES public.competitive_seasons(id) ON DELETE CASCADE,
  league_id text NOT NULL REFERENCES public.league_definitions(id),
  ladder_type text NOT NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  rank integer NOT NULL,
  trophies integer NOT NULL,
  wins integer NOT NULL,
  draws integer NOT NULL,
  losses integer NOT NULL,
  matches_played integer NOT NULL,
  display_name text NOT NULL,
  avatar_id text,
  promotion_status text NOT NULL CHECK (promotion_status IN ('promoted','stayed','relegated')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(season_id, league_id, ladder_type, user_id)
);

ALTER TABLE public.season_rankings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "sr_read" ON public.season_rankings FOR SELECT TO authenticated USING (true);

-- 1.10 reward_transactions
CREATE TABLE IF NOT EXISTS public.reward_transactions (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_key text NOT NULL UNIQUE,
  reward_type text NOT NULL CHECK (reward_type IN ('top5','promotion','champions_access','badge','cosmetic')),
  coins integer NOT NULL DEFAULT 0,
  badge_id text,
  metadata jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.reward_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "rt_read_own" ON public.reward_transactions FOR SELECT TO authenticated USING (user_id = auth.uid());

-- 1.11 ranked_matchmaking_queue
CREATE TABLE IF NOT EXISTS public.ranked_matchmaking_queue (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  player_name text NOT NULL,
  avatar_id text,
  league_id text NOT NULL REFERENCES public.league_definitions(id),
  ladder_type text NOT NULL CHECK (ladder_type IN ('normal','champions')),
  season_id text NOT NULL REFERENCES public.competitive_seasons(id),
  trophies integer NOT NULL,
  joined_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_rmq_league ON public.ranked_matchmaking_queue(league_id, ladder_type, joined_at);

-- RLS: Only accessible via RPC
ALTER TABLE public.ranked_matchmaking_queue ENABLE ROW LEVEL SECURITY;

-- 1.12 online_rooms güncellemeleri
ALTER TABLE public.online_rooms ADD COLUMN IF NOT EXISTS is_ranked boolean NOT NULL DEFAULT false;
ALTER TABLE public.online_rooms ADD COLUMN IF NOT EXISTS ranked_match_id uuid REFERENCES public.ranked_matches(id);


-- 2. Görünümler (Views)

-- champions_top10_view
CREATE MATERIALIZED VIEW IF NOT EXISTS public.champions_top10_view AS
SELECT 
  pl.user_id,
  op.display_name,
  op.friend_code,
  pl.trophies,
  pl.wins,
  pl.losses,
  pl.matches_played,
  pl.season_id,
  ROW_NUMBER() OVER (ORDER BY pl.trophies DESC, pl.wins DESC, pl.losses ASC, pl.peak_reached_at ASC) AS rank
FROM public.player_ladders pl
JOIN public.online_profiles op ON op.id = pl.user_id
JOIN public.competitive_seasons cs ON cs.id = pl.season_id AND cs.status = 'active'
WHERE pl.ladder_type = 'champions' AND pl.league_id = 'sampiyonlar'
ORDER BY rank
LIMIT 10;

CREATE UNIQUE INDEX IF NOT EXISTS idx_ct10_user ON public.champions_top10_view(user_id);


-- 3. RPC Fonksiyonları

-- 3.1 join_ranked_queue
CREATE OR REPLACE FUNCTION public.join_ranked_queue(p_ladder_type text, p_player_name text, p_avatar_id text DEFAULT NULL)
RETURNS SETOF public.online_rooms
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_active_season public.competitive_seasons%rowtype;
  v_ladder public.player_ladders%rowtype;
  v_opponent public.ranked_matchmaking_queue%rowtype;
  v_new_code text;
  v_match_id uuid;
  v_attempt integer := 0;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
  IF p_ladder_type NOT IN ('normal', 'champions') THEN RAISE EXCEPTION 'Geçersiz ladder_type'; END IF;
  IF char_length(trim(p_player_name)) NOT BETWEEN 1 AND 18 THEN RAISE EXCEPTION 'Oyuncu adı 1-18 karakter olmalı'; END IF;

  -- Profil güncelle/oluştur
  INSERT INTO public.online_profiles(id, display_name) VALUES (v_user_id, trim(p_player_name))
  ON CONFLICT (id) DO UPDATE SET display_name = EXCLUDED.display_name, updated_at = now();

  -- Aktif sezon kontrolü
  SELECT * INTO v_active_season FROM public.competitive_seasons WHERE status = 'active' LIMIT 1;
  IF NOT FOUND THEN RAISE EXCEPTION 'Aktif sezon bulunamadı'; END IF;
  
  -- Sezon kapanışına çok az kaldıysa kuyruğa alım durdurulur
  IF v_active_season.queue_locked_at IS NOT NULL AND v_active_season.queue_locked_at <= now() THEN
    RAISE EXCEPTION 'Sezon kapanışı nedeniyle dereceli eşleşme geçici olarak kapalıdır.';
  END IF;

  -- Oyuncunun lig kaydını al
  SELECT * INTO v_ladder FROM public.player_ladders 
  WHERE user_id = v_user_id AND season_id = v_active_season.id AND ladder_type = p_ladder_type LIMIT 1;

  -- Eğer normal ise ve kaydı yoksa Kırmızı Meydan'dan başlat
  IF NOT FOUND THEN
    IF p_ladder_type = 'normal' THEN
      INSERT INTO public.player_ladders (user_id, season_id, league_id, ladder_type, trophies)
      VALUES (v_user_id, v_active_season.id, 'kirmizi', 'normal', 0)
      RETURNING * INTO v_ladder;
    ELSE
      RAISE EXCEPTION 'Şampiyonlar Meydanı erişiminiz yok.';
    END IF;
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('ranked_matchmaking'));

  -- Temizlik (5 dakikadan eski kuyruk kayıtları)
  DELETE FROM public.ranked_matchmaking_queue WHERE joined_at < now() - interval '5 minutes';

  -- Önce bizim daha önceden eşleştiğimiz ve bizi bekleyen bir oda var mı kontrol et
  RETURN QUERY
  SELECT r.* FROM public.online_rooms r
  JOIN public.ranked_matches rm ON rm.room_code = r.code
  WHERE r.status = 'waiting' AND r.matchmaking AND r.is_ranked 
    AND rm.status = 'in_progress'
    AND r.guest_id IS NOT NULL
    AND (r.host_id = v_user_id OR r.guest_id = v_user_id)
  ORDER BY r.created_at DESC LIMIT 1;
  IF FOUND THEN
    DELETE FROM public.ranked_matchmaking_queue WHERE user_id = v_user_id;
    RETURN;
  END IF;

  -- Kuyrukta rakip ara (Aynı lig ve ladder type)
  SELECT q.* INTO v_opponent
  FROM public.ranked_matchmaking_queue q
  WHERE q.user_id <> v_user_id
    AND q.season_id = v_active_season.id
    AND q.league_id = v_ladder.league_id
    AND q.ladder_type = p_ladder_type
    -- Kupa farkı 150 (Genişletilebilir)
    AND abs(q.trophies - v_ladder.trophies) <= 150
  ORDER BY q.joined_at
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF v_opponent.user_id IS NULL THEN
    -- Rakip yoksa kuyruğa ekle
    INSERT INTO public.ranked_matchmaking_queue(user_id, player_name, avatar_id, league_id, ladder_type, season_id, trophies, joined_at)
    VALUES (v_user_id, trim(p_player_name), p_avatar_id, v_ladder.league_id, p_ladder_type, v_active_season.id, v_ladder.trophies, now())
    ON CONFLICT (user_id) DO UPDATE SET 
      player_name = EXCLUDED.player_name, 
      avatar_id = EXCLUDED.avatar_id,
      league_id = EXCLUDED.league_id,
      ladder_type = EXCLUDED.ladder_type,
      season_id = EXCLUDED.season_id,
      trophies = EXCLUDED.trophies,
      joined_at = now();
    RETURN;
  END IF;

  -- Rakip bulundu, kuyruktan çıkar
  DELETE FROM public.ranked_matchmaking_queue WHERE user_id IN (v_opponent.user_id, v_user_id);

  -- Oda ve match kaydı oluştur
  LOOP
    v_new_code := (100000 + floor(random() * 900000))::integer::text;
    BEGIN
      -- Önce ranked match oluştur, match id al
      INSERT INTO public.ranked_matches (
        season_id, league_id, ladder_type, room_code, host_id, guest_id, host_name, guest_name
      ) VALUES (
        v_active_season.id, v_ladder.league_id, p_ladder_type, v_new_code, 
        v_opponent.user_id, v_user_id, v_opponent.player_name, trim(p_player_name)
      ) RETURNING id INTO v_match_id;

      INSERT INTO public.online_rooms(
        code, host_id, host_name, host_avatar_id, host_ready, guest_id, guest_name, guest_avatar_id, guest_ready,
        host_connected, guest_connected, matchmaking, is_ranked, ranked_match_id
      ) VALUES (
        v_new_code, v_opponent.user_id, v_opponent.player_name, v_opponent.avatar_id, true,
        v_user_id, trim(p_player_name), p_avatar_id, true, true, true, true, true, v_match_id
      );
      EXIT;
    EXCEPTION WHEN unique_violation THEN
      v_attempt := v_attempt + 1;
      IF v_attempt > 10 THEN RAISE EXCEPTION 'Dereceli oda kodu bulunamadi'; END IF;
    END;
  END LOOP;

  RETURN QUERY SELECT * FROM public.online_rooms WHERE code = v_new_code;
END;
$$;


-- 3.2 cancel_ranked_queue
CREATE OR REPLACE FUNCTION public.cancel_ranked_queue()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.ranked_matchmaking_queue WHERE user_id = auth.uid();
$$;


-- 3.3 submit_ranked_squad
CREATE OR REPLACE FUNCTION public.submit_ranked_squad(p_match_id uuid, p_payload jsonb, p_idempotency_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_match public.ranked_matches%rowtype;
  v_room public.online_rooms%rowtype;
  v_side text;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Oturum gerekli'; END IF;
  
  -- İdempotency kontrolü
  IF EXISTS (SELECT 1 FROM public.match_submissions WHERE idempotency_key = p_idempotency_key) THEN
    RETURN; -- Sessizce dön
  END IF;

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Maç bulunamadı'; END IF;
  IF v_match.status <> 'in_progress' THEN RAISE EXCEPTION 'Maç devam etmiyor'; END IF;

  IF v_match.host_id = v_user_id THEN v_side := 'host';
  ELSIF v_match.guest_id = v_user_id THEN v_side := 'guest';
  ELSE RAISE EXCEPTION 'Bu maçın oyuncusu değilsiniz'; END IF;

  SELECT * INTO v_room FROM public.online_rooms WHERE code = v_match.room_code FOR UPDATE;
  IF v_side = 'host' AND v_room.host_locked THEN RAISE EXCEPTION 'Kadro zaten kilitli'; END IF;
  IF v_side = 'guest' AND v_room.guest_locked THEN RAISE EXCEPTION 'Kadro zaten kilitli'; END IF;

  INSERT INTO public.match_submissions(match_id, user_id, side, squad_payload, idempotency_key)
  VALUES (p_match_id, v_user_id, v_side, p_payload, p_idempotency_key);

  -- online_squads'a da kaydet (mevcut reveal mekanizmasının çalışması için)
  INSERT INTO public.online_squads(room_code, owner_id, side, player_ids)
  VALUES (
    v_match.room_code, 
    v_user_id, 
    v_side, 
    -- payload formatı: [{"id": "...", "stat": 123}, ...] olduğunu varsayıyoruz
    (SELECT jsonb_agg(v->>'id') FROM jsonb_array_elements(p_payload) v)
  )
  ON CONFLICT ON CONSTRAINT online_squads_pkey DO UPDATE
    SET owner_id = EXCLUDED.owner_id, player_ids = EXCLUDED.player_ids, submitted_at = now();

  -- online_rooms'u güncelle
  UPDATE public.online_rooms r
  SET host_locked = CASE WHEN v_side = 'host' THEN true ELSE r.host_locked END,
      guest_locked = CASE WHEN v_side = 'guest' THEN true ELSE r.guest_locked END,
      end_time = CASE
        WHEN v_side = 'host' AND NOT r.guest_locked THEN least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        WHEN v_side = 'guest' AND NOT r.host_locked THEN least(coalesce(r.end_time, now() + interval '15 seconds'), now() + interval '15 seconds')
        ELSE r.end_time END,
      revision = r.revision + 1, updated_at = now()
  WHERE r.code = v_match.room_code;

  -- Eğer ikisi de kilitlediyse hazır hale getir
  UPDATE public.online_rooms r
  SET status = 'ready', revision = r.revision + 1, updated_at = now()
  WHERE r.code = v_match.room_code AND r.host_locked AND r.guest_locked AND r.status = 'playing';

END;
$$;


-- 3.4 finalize_ranked_match
CREATE OR REPLACE FUNCTION public.finalize_ranked_match(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_match public.ranked_matches%rowtype;
  v_room public.online_rooms%rowtype;
  v_host_sub public.match_submissions%rowtype;
  v_guest_sub public.match_submissions%rowtype;
  v_rules public.season_league_rules%rowtype;
  v_host_ladder public.player_ladders%rowtype;
  v_guest_ladder public.player_ladders%rowtype;
  v_host_total numeric := 0;
  v_guest_total numeric := 0;
  v_target numeric;
  v_host_diff numeric;
  v_guest_diff numeric;
  v_winner_id uuid;
  v_host_delta integer;
  v_guest_delta integer;
  v_host_base_delta integer;
  v_guest_base_delta integer;
  v_farm_count integer;
  v_anti_farm_factor real := 1.0;
  v_item record;
BEGIN
  PERFORM pg_advisory_xact_lock(hashtext('finalize_match_' || p_match_id::text));

  SELECT * INTO v_match FROM public.ranked_matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Maç bulunamadı'; END IF;
  IF v_match.status = 'finalized' THEN RETURN; END IF; -- Idempotent
  IF v_match.status <> 'in_progress' THEN RETURN; END IF;

  SELECT * INTO v_room FROM public.online_rooms WHERE code = v_match.room_code;
  IF NOT FOUND THEN RAISE EXCEPTION 'Oda bulunamadı'; END IF;

  SELECT * INTO v_rules FROM public.season_league_rules WHERE season_id = v_match.season_id AND league_id = v_match.league_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Lig kuralları bulunamadı'; END IF;

  SELECT * INTO v_host_sub FROM public.match_submissions WHERE match_id = p_match_id AND side = 'host';
  SELECT * INTO v_guest_sub FROM public.match_submissions WHERE match_id = p_match_id AND side = 'guest';

  IF v_host_sub IS NULL OR v_guest_sub IS NULL THEN
    RAISE EXCEPTION 'İki tarafın da kadrosu henüz gönderilmedi';
  END IF;

  v_target := coalesce(nullif(v_room.game_setup->>'target', '')::numeric, 0);

  -- Host toplamını hesapla (Payload formatı {"id": "...", "stat": num})
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_host_sub.squad_payload) LOOP
    v_host_total := v_host_total + coalesce((v_item.value->>'stat')::numeric, 0);
  END LOOP;

  -- Guest toplamını hesapla
  FOR v_item IN SELECT * FROM jsonb_array_elements(v_guest_sub.squad_payload) LOOP
    v_guest_total := v_guest_total + coalesce((v_item.value->>'stat')::numeric, 0);
  END LOOP;

  v_host_diff := abs(v_target - v_host_total);
  v_guest_diff := abs(v_target - v_guest_total);

  IF v_host_diff < v_guest_diff THEN
    v_winner_id := v_match.host_id;
    v_host_base_delta := v_rules.win_trophies;
    v_guest_base_delta := v_rules.loss_trophies;
  ELSIF v_guest_diff < v_host_diff THEN
    v_winner_id := v_match.guest_id;
    v_host_base_delta := v_rules.loss_trophies;
    v_guest_base_delta := v_rules.win_trophies;
  ELSE
    v_winner_id := NULL; -- Berabere
    v_host_base_delta := v_rules.draw_trophies;
    v_guest_base_delta := v_rules.draw_trophies;
  END IF;

  -- Anti-farm hesapla
  SELECT COUNT(*) INTO v_farm_count FROM public.ranked_matches
  WHERE LEAST(host_id, guest_id) = LEAST(v_match.host_id, v_match.guest_id)
    AND GREATEST(host_id, guest_id) = GREATEST(v_match.host_id, v_match.guest_id)
    AND league_id = v_match.league_id
    AND DATE(created_at) = CURRENT_DATE
    AND status = 'finalized';

  IF v_farm_count >= v_rules.anti_farm_full_count + v_rules.anti_farm_half_count THEN
    v_anti_farm_factor := 0.0;
  ELSIF v_farm_count >= v_rules.anti_farm_full_count THEN
    v_anti_farm_factor := 0.5;
  END IF;

  v_host_delta := ROUND(v_host_base_delta * v_anti_farm_factor);
  v_guest_delta := ROUND(v_guest_base_delta * v_anti_farm_factor);

  -- Ladders güncelle ve transaction yaz
  SELECT * INTO v_host_ladder FROM public.player_ladders WHERE user_id = v_match.host_id AND season_id = v_match.season_id AND ladder_type = v_match.ladder_type FOR UPDATE;
  SELECT * INTO v_guest_ladder FROM public.player_ladders WHERE user_id = v_match.guest_id AND season_id = v_match.season_id AND ladder_type = v_match.ladder_type FOR UPDATE;

  -- Host güncelleme
  IF v_host_ladder IS NOT NULL THEN
    INSERT INTO public.trophy_transactions(user_id, season_id, league_id, ladder_type, match_id, delta, base_delta, anti_farm_factor, old_trophies, new_trophies, result)
    VALUES (v_match.host_id, v_match.season_id, v_match.league_id, v_match.ladder_type, p_match_id, v_host_delta, v_host_base_delta, v_anti_farm_factor, v_host_ladder.trophies, greatest(0, v_host_ladder.trophies + v_host_delta), CASE WHEN v_winner_id = v_match.host_id THEN 'win' WHEN v_winner_id IS NULL THEN 'draw' ELSE 'loss' END);

    UPDATE public.player_ladders SET
      trophies = greatest(0, trophies + v_host_delta),
      matches_played = matches_played + 1,
      wins = wins + CASE WHEN v_winner_id = v_match.host_id THEN 1 ELSE 0 END,
      draws = draws + CASE WHEN v_winner_id IS NULL THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN v_winner_id = v_match.guest_id THEN 1 ELSE 0 END,
      peak_trophies = greatest(peak_trophies, greatest(0, trophies + v_host_delta)),
      peak_reached_at = CASE WHEN greatest(0, trophies + v_host_delta) > peak_trophies THEN now() ELSE peak_reached_at END,
      updated_at = now()
    WHERE id = v_host_ladder.id;
  END IF;

  -- Guest güncelleme
  IF v_guest_ladder IS NOT NULL THEN
    INSERT INTO public.trophy_transactions(user_id, season_id, league_id, ladder_type, match_id, delta, base_delta, anti_farm_factor, old_trophies, new_trophies, result)
    VALUES (v_match.guest_id, v_match.season_id, v_match.league_id, v_match.ladder_type, p_match_id, v_guest_delta, v_guest_base_delta, v_anti_farm_factor, v_guest_ladder.trophies, greatest(0, v_guest_ladder.trophies + v_guest_delta), CASE WHEN v_winner_id = v_match.guest_id THEN 'win' WHEN v_winner_id IS NULL THEN 'draw' ELSE 'loss' END);

    UPDATE public.player_ladders SET
      trophies = greatest(0, trophies + v_guest_delta),
      matches_played = matches_played + 1,
      wins = wins + CASE WHEN v_winner_id = v_match.guest_id THEN 1 ELSE 0 END,
      draws = draws + CASE WHEN v_winner_id IS NULL THEN 1 ELSE 0 END,
      losses = losses + CASE WHEN v_winner_id = v_match.host_id THEN 1 ELSE 0 END,
      peak_trophies = greatest(peak_trophies, greatest(0, trophies + v_guest_delta)),
      peak_reached_at = CASE WHEN greatest(0, trophies + v_guest_delta) > peak_trophies THEN now() ELSE peak_reached_at END,
      updated_at = now()
    WHERE id = v_guest_ladder.id;
  END IF;

  -- Match güncelle
  UPDATE public.ranked_matches SET
    status = 'finalized',
    winner_id = v_winner_id,
    host_total = v_host_total,
    guest_total = v_guest_total,
    target = v_target,
    result_type = 'normal',
    host_trophy_delta = v_host_delta,
    guest_trophy_delta = v_guest_delta,
    anti_farm_factor = v_anti_farm_factor,
    finalized_at = now()
  WHERE id = p_match_id;

  -- Oda kapat
  UPDATE public.online_rooms SET status = 'finished', updated_at = now() WHERE code = v_match.room_code;
  
  -- Şampiyonlar kontrolü (Eğer Süper Meydan ise)
  IF v_match.league_id = 'super' AND v_match.ladder_type = 'normal' THEN
    PERFORM public.qualify_champions_if_eligible(v_match.host_id, v_match.season_id);
    PERFORM public.qualify_champions_if_eligible(v_match.guest_id, v_match.season_id);
  END IF;

END;
$$;


-- 3.5 qualify_champions_if_eligible
CREATE OR REPLACE FUNCTION public.qualify_champions_if_eligible(p_user_id uuid, p_season_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ladder public.player_ladders%rowtype;
  v_rules public.season_league_rules%rowtype;
BEGIN
  SELECT * INTO v_ladder FROM public.player_ladders WHERE user_id = p_user_id AND season_id = p_season_id AND ladder_type = 'normal' AND league_id = 'super';
  IF NOT FOUND THEN RETURN; END IF;

  SELECT * INTO v_rules FROM public.season_league_rules WHERE season_id = p_season_id AND league_id = 'super';
  IF NOT FOUND OR v_rules.champions_unlock_trophies IS NULL OR v_rules.champions_unlock_matches IS NULL THEN RETURN; END IF;

  IF v_ladder.trophies >= v_rules.champions_unlock_trophies AND v_ladder.matches_played >= v_rules.champions_unlock_matches THEN
    -- Zaten hak kazanmış mı?
    IF EXISTS (SELECT 1 FROM public.champions_qualifications WHERE user_id = p_user_id AND season_id = p_season_id) THEN RETURN; END IF;

    -- Kaydet
    INSERT INTO public.champions_qualifications(user_id, season_id, trophies_at_qualification, matches_at_qualification)
    VALUES (p_user_id, p_season_id, v_ladder.trophies, v_ladder.matches_played);

    -- Şampiyonlar ladder'ını oluştur
    INSERT INTO public.player_ladders(user_id, season_id, league_id, ladder_type, trophies)
    VALUES (p_user_id, p_season_id, 'sampiyonlar', 'champions', 0);

    -- Ödül ver
    INSERT INTO public.reward_transactions(user_id, reward_key, reward_type, coins, metadata)
    VALUES (p_user_id, p_season_id || ':champions_access', 'champions_access', 1200, '{"unlocked": true}');
    
    UPDATE public.online_profiles SET coins = coins + 1200 WHERE id = p_user_id;
  END IF;
END;
$$;


-- 4. Yetkilendirme (Grants)
GRANT EXECUTE ON FUNCTION public.join_ranked_queue(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_ranked_queue() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_ranked_squad(uuid, jsonb, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_ranked_match(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.qualify_champions_if_eligible(uuid, text) TO authenticated;


-- 5. Başlangıç Verisi (İlk Sezon)
DO $$
DECLARE
  v_season_id text := to_char(now() AT TIME ZONE 'UTC', 'YYYY-MM');
  v_starts_at timestamptz := date_trunc('month', now() AT TIME ZONE 'UTC');
  v_ends_at timestamptz := v_starts_at + interval '1 month' - interval '1 second';
  v_queue_locked_at timestamptz := v_ends_at - interval '5 minutes';
BEGIN
  -- Sezonu oluştur
  INSERT INTO public.competitive_seasons (id, status, starts_at, ends_at, queue_locked_at)
  VALUES (v_season_id, 'active', v_starts_at, v_ends_at, v_queue_locked_at)
  ON CONFLICT (id) DO NOTHING;

  -- Kuralları oluştur (Kırmızı)
  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'kirmizi', 25, 7, -5, 150, '[500,400,300,250,200]')
  ON CONFLICT DO NOTHING;

  -- Beyaz
  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'beyaz', 23, 6, -8, 250, '[600,475,375,300,250]')
  ON CONFLICT DO NOTHING;

  -- İkinci
  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'ikinci', 21, 4, -11, 400, '[700,550,450,350,300]')
  ON CONFLICT DO NOTHING;

  -- Birinci
  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'birinci', 19, 2, -14, 750, '[1000,800,650,500,400]')
  ON CONFLICT DO NOTHING;

  -- Süper
  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards, champions_unlock_trophies, champions_unlock_matches)
  VALUES (v_season_id, 'super', 17, 0, -16, 0, '[1500,1200,1000,800,650]', 1300, 20)
  ON CONFLICT DO NOTHING;

  -- Şampiyonlar
  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'sampiyonlar', 15, 0, -18, 0, '[3000,2400,1900,1500,1200]')
  ON CONFLICT DO NOTHING;
END $$;

COMMIT;
