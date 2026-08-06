-- 1. Önce eski hatalı sezonları temizle (eğer varsa)
DELETE FROM public.competitive_seasons;
DELETE FROM public.season_league_rules;
DELETE FROM public.league_definitions;

-- 2. Lig tanımlarını baştan ekle
INSERT INTO public.league_definitions (id, display_name, tier, base_trophies, promotion_trophies, promotion_min_matches, is_champions, color_hex) VALUES
  ('kirmizi',     'Kırmızı Meydan',       1,    0,  200, 10, false, '#FF453A'),
  ('beyaz',       'Beyaz Meydan',         2,  200,  450, 10, false, '#FFFFFF'),
  ('ikinci',      'İkinci Meydan',        3,  450,  750, 10, false, '#5EC8FF'),
  ('birinci',     'Birinci Meydan',       4,  750, 1200, 10, false, '#FFD166'),
  ('super',       'Süper Meydan',         5, 1200, NULL, NULL, false, '#B388FF'),
  ('sampiyonlar', 'Şampiyonlar Meydanı',  6,    0, NULL, NULL, true,  '#FF9F0A')
ON CONFLICT (id) DO NOTHING;

-- 3. Aktif Sezonu ve Kuralları Oluştur
DO $$
DECLARE
  v_season_id text;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_queue_locked_at timestamptz;
BEGIN
  v_starts_at := date_trunc('month', now());
  v_ends_at := v_starts_at + interval '1 month';
  v_queue_locked_at := v_ends_at - interval '5 minutes';
  
  v_season_id := 'season_' || extract(year from v_starts_at)::text || '_' || extract(month from v_starts_at)::text;

  INSERT INTO public.competitive_seasons (id, status, starts_at, ends_at, queue_locked_at)
  VALUES (v_season_id, 'active', v_starts_at, v_ends_at, v_queue_locked_at)
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'kirmizi', 25, 7, -5, 150, '[500,400,300,250,200]') ON CONFLICT DO NOTHING;

  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'beyaz', 23, 6, -8, 250, '[600,475,375,300,250]') ON CONFLICT DO NOTHING;

  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'ikinci', 21, 4, -11, 400, '[700,550,450,350,300]') ON CONFLICT DO NOTHING;

  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'birinci', 19, 2, -14, 750, '[1000,800,650,500,400]') ON CONFLICT DO NOTHING;

  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards, champions_unlock_trophies, champions_unlock_matches)
  VALUES (v_season_id, 'super', 17, 0, -16, 0, '[1500,1200,1000,800,650]', 1300, 20) ON CONFLICT DO NOTHING;

  INSERT INTO public.season_league_rules (season_id, league_id, win_trophies, draw_trophies, loss_trophies, promotion_reward_coins, top5_rewards)
  VALUES (v_season_id, 'sampiyonlar', 15, 0, -18, 0, '[3000,2400,1900,1500,1200]') ON CONFLICT DO NOTHING;
END $$;
