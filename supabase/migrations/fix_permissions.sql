-- 1. Tablolara anon ve authenticated rolleri için genel erişim yetkisi (GRANT) veriyoruz:
GRANT SELECT ON public.competitive_seasons TO anon, authenticated;
GRANT SELECT ON public.season_league_rules TO anon, authenticated;
GRANT SELECT ON public.league_definitions TO anon, authenticated;
GRANT SELECT ON public.player_ladders TO anon, authenticated;

-- 2. Eğer anon kullanıcılar için RLS (Row Level Security) eksikse ekliyoruz:
DROP POLICY IF EXISTS "seasons_read_anon" ON public.competitive_seasons;
CREATE POLICY "seasons_read_anon" ON public.competitive_seasons FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "league_def_read_anon" ON public.league_definitions;
CREATE POLICY "league_def_read_anon" ON public.league_definitions FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "slr_read_anon" ON public.season_league_rules;
CREATE POLICY "slr_read_anon" ON public.season_league_rules FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS "pl_read_anon" ON public.player_ladders;
CREATE POLICY "pl_read_anon" ON public.player_ladders FOR SELECT TO anon USING (true);
