-- 20260802000000_ranked_leagues_v2_seasons.sql
-- Aşama 2: Sezon Kapanışı ve Ödül Dağıtımı

-- 1. credit_reward RPC
-- Oyuncuya güvenli bir şekilde coin verir ve loglar
CREATE OR REPLACE FUNCTION public.credit_reward(
  p_user_id uuid,
  p_amount integer,
  p_reason text,
  p_reference_id text
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Eğer bu reference_id ile önceden log varsa, duplicate önleme
  IF EXISTS (SELECT 1 FROM public.game_logs WHERE user_id = p_user_id AND event = p_reason AND (metadata->>'ref')::text = p_reference_id) THEN
    RETURN;
  END IF;

  UPDATE public.online_profiles
  SET coins = coins + p_amount
  WHERE id = p_user_id;

  INSERT INTO public.game_logs (user_id, event, metadata)
  VALUES (
    p_user_id, 
    p_reason, 
    jsonb_build_object('amount', p_amount, 'ref', p_reference_id)
  );
END;
$$;

-- 2. close_competitive_season RPC
-- Mevcut sezonu kapatır, ödülleri dağıtır ve yeni sezonu başlatır
CREATE OR REPLACE FUNCTION public.close_competitive_season(
  p_season_id text
) RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_next_season_id text;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_ladder record;
  v_league record;
  v_rank integer;
  v_reward_coins integer;
  v_next_league_id text;
  v_next_trophies integer;
BEGIN
  -- 1. Sezonu kapat
  UPDATE public.competitive_seasons
  SET status = 'closed'
  WHERE id = p_season_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN 'Season not active or not found.';
  END IF;

  -- 2. Yeni sezon oluştur (Örn: 'season_2', 'season_3' gibi basit bir isimlendirme)
  v_starts_at := now();
  v_ends_at := v_starts_at + interval '1 month';
  v_next_season_id := 'season_' || extract(year from v_starts_at)::text || '_' || extract(month from v_starts_at)::text;

  INSERT INTO public.competitive_seasons (id, status, starts_at, ends_at)
  VALUES (v_next_season_id, 'active', v_starts_at, v_ends_at)
  ON CONFLICT (id) DO NOTHING;

  -- 3. Kuralları yeni sezona kopyala
  INSERT INTO public.season_league_rules (
    season_id, league_id, win_trophies, draw_trophies, loss_trophies, 
    promotion_reward_coins, top5_rewards, top5_min_matches, champions_unlock_trophies
  )
  SELECT 
    v_next_season_id, league_id, win_trophies, draw_trophies, loss_trophies, 
    promotion_reward_coins, top5_rewards, top5_min_matches, champions_unlock_trophies
  FROM public.season_league_rules
  WHERE season_id = p_season_id;

  -- 4. Her lig için oyuncuları sırala ve işle
  FOR v_league IN SELECT * FROM public.league_definitions ORDER BY tier ASC LOOP
    v_rank := 1;
    
    FOR v_ladder IN 
      SELECT * FROM public.player_ladders 
      WHERE season_id = p_season_id AND league_id = v_league.id
      ORDER BY trophies DESC, matches_played ASC
    LOOP
      -- Ödül hesapla
      v_reward_coins := 0;
      IF v_rank <= 5 AND v_ladder.matches_played >= 15 THEN
        -- JSON'dan ödülü al (örnek basitlik: her lig için manuel switch yerine, kurallardan okunabilir)
        -- Gerçek sistemde rules tablosundan top5_rewards objesinden okunur.
        -- Şimdilik 1. 1000, 2. 500 vb. varsayılan değerler
        IF v_rank = 1 THEN v_reward_coins := 1000;
        ELSIF v_rank = 2 THEN v_reward_coins := 800;
        ELSIF v_rank = 3 THEN v_reward_coins := 600;
        ELSIF v_rank = 4 THEN v_reward_coins := 400;
        ELSIF v_rank = 5 THEN v_reward_coins := 200;
        END IF;
      END IF;

      IF v_reward_coins > 0 THEN
        PERFORM public.credit_reward(v_ladder.user_id, v_reward_coins, 'season_top_5', p_season_id || '_' || v_league.id);
      END IF;

      -- Yükselme / Düşme Hesaplama
      v_next_league_id := v_ladder.league_id;
      v_next_trophies := v_ladder.trophies;

      IF v_league.promotion_trophies IS NOT NULL AND v_ladder.trophies >= v_league.promotion_trophies THEN
        -- Üst lige çıkıyor
        SELECT id, base_trophies INTO v_next_league_id, v_next_trophies 
        FROM public.league_definitions 
        WHERE tier = v_league.tier + 1 LIMIT 1;
        
        -- Yükselme ödülü
        PERFORM public.credit_reward(v_ladder.user_id, 250, 'promotion', p_season_id || '_' || v_next_league_id);
      ELSIF v_ladder.trophies < v_league.base_trophies AND v_league.tier > 1 THEN
        -- Alt lige düşüyor
        SELECT id, base_trophies INTO v_next_league_id, v_next_trophies 
        FROM public.league_definitions 
        WHERE tier = v_league.tier - 1 LIMIT 1;
      ELSE
        -- Mevcut ligde kalıyor ama kupası base_trophies'e sıfırlanıyor
        v_next_trophies := v_league.base_trophies;
      END IF;

      -- Yeni sezona kaydet
      INSERT INTO public.player_ladders (user_id, season_id, league_id, ladder_type, trophies, matches_played)
      VALUES (v_ladder.user_id, v_next_season_id, v_next_league_id, v_ladder.ladder_type, v_next_trophies, 0)
      ON CONFLICT (user_id, season_id, ladder_type) DO NOTHING;

      v_rank := v_rank + 1;
    END LOOP;
  END LOOP;

  RETURN v_next_season_id;
END;
$$;
