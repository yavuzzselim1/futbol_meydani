-- Çevrimdışı ilerlemeyi çevrimiçi profile güvenli ve tekrar çalıştırılabilir
-- biçimde birleştirir. Rekabetçi rating/maç istatistiklerine dokunmaz.

alter table public.online_profiles
  add column if not exists last_minute_best integer not null default 0,
  add column if not exists last_minute_furthest integer not null default 0,
  add column if not exists last_minute_goals integer not null default 0,
  add column if not exists last_minute_best_streak integer not null default 0,
  add column if not exists last_minute_career_stars jsonb
    not null default '[0,0,0,0,0,0,0,0,0,0,0,0]'::jsonb,
  add column if not exists unlocked_avatars text[]
    not null default array['default']::text[],
  add column if not exists unlocked_themes text[]
    not null default array['default']::text[],
  add column if not exists unlocked_badges text[]
    not null default array[]::text[],
  add column if not exists offline_merge_version integer not null default 0,
  add column if not exists offline_merged_at timestamptz;

create or replace function public.merge_offline_progress(p_progress jsonb)
returns setof public.online_profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  account_id uuid := auth.uid();
  safe_name text;
begin
  if account_id is null then
    raise exception 'Oturum gerekli';
  end if;

  if p_progress is null or jsonb_typeof(p_progress) <> 'object' then
    raise exception 'Geçerli ilerleme verisi gerekli';
  end if;

  safe_name := left(
    coalesce(nullif(trim(p_progress->>'display_name'), ''), 'Oyuncu'),
    18
  );

  insert into public.online_profiles(id, display_name)
  values (account_id, safe_name)
  on conflict (id) do nothing;

  update public.online_profiles profile
  set
    coins = greatest(
      profile.coins,
      greatest(0, coalesce((p_progress->>'coins')::integer, 0))
    ),
    xp = greatest(
      profile.xp,
      greatest(0, coalesce((p_progress->>'xp')::integer, 0))
    ),
    last_minute_best = greatest(
      profile.last_minute_best,
      greatest(0, coalesce((p_progress->>'last_minute_best')::integer, 0))
    ),
    last_minute_furthest = greatest(
      profile.last_minute_furthest,
      greatest(
        0,
        coalesce((p_progress->>'last_minute_furthest')::integer, 0)
      )
    ),
    last_minute_goals = greatest(
      profile.last_minute_goals,
      greatest(0, coalesce((p_progress->>'last_minute_goals')::integer, 0))
    ),
    last_minute_best_streak = greatest(
      profile.last_minute_best_streak,
      greatest(
        0,
        coalesce((p_progress->>'last_minute_best_streak')::integer, 0)
      )
    ),
    last_minute_stage = greatest(
      profile.last_minute_stage,
      greatest(0, coalesce((p_progress->>'last_minute_stage')::integer, 0))
    ),
    last_minute_career_stars = (
      select jsonb_agg(
        greatest(
          0,
          least(
            3,
            greatest(
              coalesce(
                (profile.last_minute_career_stars->>stage_index)::integer,
                0
              ),
              coalesce(
                (p_progress->'last_minute_career_stars'->>stage_index)::integer,
                0
              )
            )
          )
        )
        order by stage_index
      )
      from generate_series(0, 11) as stages(stage_index)
    ),
    unlocked_avatars = (
      select coalesce(
        array_agg(distinct item order by item),
        array['default']::text[]
      )
      from unnest(
        coalesce(profile.unlocked_avatars, array['default']::text[]) ||
        array(
          select value
          from jsonb_array_elements_text(
            coalesce(p_progress->'unlocked_avatars', '[]'::jsonb)
          ) as values(value)
          where value in (
            'default',
            'avatar_pro',
            'avatar_captain',
            'avatar_legend',
            'avatar_ghost'
          )
        )
      ) as merged(item)
    ),
    unlocked_themes = (
      select coalesce(
        array_agg(distinct item order by item),
        array['default']::text[]
      )
      from unnest(
        coalesce(profile.unlocked_themes, array['default']::text[]) ||
        array(
          select value
          from jsonb_array_elements_text(
            coalesce(p_progress->'unlocked_themes', '[]'::jsonb)
          ) as values(value)
          where value in (
            'default',
            'theme_neon',
            'theme_gold',
            'theme_fire',
            'theme_ice'
          )
        )
      ) as merged(item)
    ),
    unlocked_badges = (
      select coalesce(
        array_agg(distinct item order by item),
        array[]::text[]
      )
      from unnest(
        coalesce(profile.unlocked_badges, array[]::text[]) ||
        array(
          select value
          from jsonb_array_elements_text(
            coalesce(p_progress->'unlocked_badges', '[]'::jsonb)
          ) as values(value)
          where value in (
            'first_match',
            'ten_matches',
            'twenty_matches',
            'perfect_score',
            'five_wins',
            'daily_warrior',
            'coin_collector',
            'last_minute_goal',
            'social_butterfly',
            'level_10',
            'level_50',
            'trophy_500',
            'trophy_2000'
          )
        )
      ) as merged(item)
    ),
    offline_merge_version = greatest(profile.offline_merge_version, 1),
    offline_merged_at = now(),
    updated_at = now()
  where profile.id = account_id;

  return query
  select profile.*
  from public.online_profiles profile
  where profile.id = account_id;
end;
$$;

revoke all on function public.merge_offline_progress(jsonb) from public;
grant execute on function public.merge_offline_progress(jsonb) to authenticated;
