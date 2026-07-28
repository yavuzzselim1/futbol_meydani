#!/usr/bin/env python3
"""Transfermarkt CSV dosyalarından Futbol Meydanı oyun verisi üretir.

Yalnızca Python standart kütüphanesini kullanır. Girdi dosyaları .csv veya
.csv.gz olabilir. Çıktı, uygulamaya konacak küçük bir JSON ile veri kalite
raporundan oluşur.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import itertools
import json
import math
import re
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path


SEASON = 2023
SEASON_LABEL = "2023/24"
LEAGUES = {
    "GB1": "Premier League",
    "ES1": "La Liga",
    "IT1": "Serie A",
    "TR1": "Trendyol Süper Lig",
}

FORMATIONS = {
    "goals": {"GK": 1, "DF": 2, "MF": 2, "FW": 2},
    "assists": {"GK": 1, "DF": 2, "MF": 3, "FW": 1},
    "appearances": {"GK": 1, "DF": 3, "MF": 2, "FW": 1},
    "minutes": {"GK": 1, "DF": 3, "MF": 2, "FW": 1},
    "yellow_cards": {"GK": 1, "DF": 3, "MF": 2, "FW": 1},
    "goal_contributions": {"GK": 1, "DF": 2, "MF": 2, "FW": 2},
}

QUESTION_DEFINITIONS = {
    "goals": ("Gol Hedefi", "gol", "Bu sezonda en çok gol atan futbolculardan 7 kişilik kadronu kur."),
    "assists": ("Asist Hedefi", "asist", "Bu sezonda en çok asist yapan futbolculardan 7 kişilik kadronu kur."),
    "appearances": ("Maç Hedefi", "maç", "Bu sezonda en çok maça çıkan futbolculardan 7 kişilik kadronu kur."),
    "minutes": ("Dakika Hedefi", "dakika", "Bu sezonda en fazla süre alan futbolculardan 7 kişilik kadronu kur."),
    "yellow_cards": ("Sarı Kart Hedefi", "sarı kart", "Bu sezonda en çok sarı kart gören futbolculardan 7 kişilik kadronu kur."),
    "goal_contributions": ("Gol Katkısı Hedefi", "gol katkısı", "Bu sezonda en çok gol katkısı yapan futbolculardan 7 kişilik kadronu kur."),
}


def open_csv(path: Path):
    if path.suffix == ".gz":
        return gzip.open(path, "rt", encoding="utf-8-sig", newline="")
    return path.open("r", encoding="utf-8-sig", newline="")


def locate(data_dir: Path, name: str) -> Path:
    for candidate in (data_dir / f"{name}.csv", data_dir / f"{name}.csv.gz"):
        if candidate.exists():
            return candidate
    raise FileNotFoundError(f"{name}.csv veya {name}.csv.gz bulunamadı: {data_dir}")


def rows(data_dir: Path, name: str):
    path = locate(data_dir, name)
    with open_csv(path) as handle:
        yield from csv.DictReader(handle)


def integer(value) -> int:
    try:
        return int(float(value or 0))
    except (TypeError, ValueError):
        return 0


def text(row: dict, *names: str) -> str:
    for name in names:
        value = row.get(name)
        if value not in (None, ""):
            return str(value).strip()
    return ""


def ascii_alias(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value)
    return "".join(char for char in normalized if not unicodedata.combining(char))


def slug(value: str) -> str:
    value = ascii_alias(value).lower()
    return re.sub(r"[^a-z0-9]+", "_", value).strip("_")


def map_position(position: str, sub_position: str = "") -> str | None:
    value = f"{position} {sub_position}".lower()
    if "goalkeeper" in value:
        return "GK"
    if "defender" in value or "back" in value:
        return "DF"
    if "midfield" in value or "midfielder" in value:
        return "MF"
    if "attack" in value or "forward" in value or "winger" in value or "striker" in value:
        return "FW"
    return None


def percentile(values: list[int], ratio: float) -> int:
    if not values:
        return 0
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round((len(ordered) - 1) * ratio)))
    return ordered[index]


def build(data_dir: Path) -> tuple[dict, dict]:
    clubs = {}
    for row in rows(data_dir, "clubs"):
        club_id = text(row, "club_id")
        if club_id:
            clubs[club_id] = text(row, "name", "club_name") or club_id

    players = {}
    for row in rows(data_dir, "players"):
        player_id = text(row, "player_id")
        name = text(row, "name", "player_name")
        position = map_position(text(row, "position"), text(row, "sub_position"))
        if player_id and name and position:
            players[player_id] = {"id": player_id, "name": name, "position": position}

    selected_games = {}
    for row in rows(data_dir, "games"):
        competition_id = text(row, "competition_id")
        if competition_id not in LEAGUES or integer(row.get("season")) != SEASON:
            continue
        game_id = text(row, "game_id")
        if game_id:
            selected_games[game_id] = competition_id

    stats = defaultdict(lambda: Counter({
        "goals": 0, "assists": 0, "appearances": 0, "minutes": 0,
        "yellow_cards": 0, "red_cards": 0,
    }))
    team_frequency = defaultdict(Counter)
    appearance_rows = 0
    for row in rows(data_dir, "appearances"):
        game_id = text(row, "game_id")
        league_id = selected_games.get(game_id)
        if not league_id:
            continue
        player_id = text(row, "player_id")
        if player_id not in players:
            continue
        key = (league_id, player_id)
        stats[key]["goals"] += integer(row.get("goals"))
        stats[key]["assists"] += integer(row.get("assists"))
        stats[key]["appearances"] += 1
        stats[key]["minutes"] += integer(row.get("minutes_played"))
        stats[key]["yellow_cards"] += integer(row.get("yellow_cards"))
        stats[key]["red_cards"] += integer(row.get("red_cards"))
        club_id = text(row, "player_club_id", "club_id", "current_club_id")
        if club_id:
            team_frequency[key][club_id] += 1
        appearance_rows += 1

    output_players = []
    player_by_league = defaultdict(list)
    missing_team = 0
    for (league_id, player_id), values in stats.items():
        if not team_frequency[(league_id, player_id)]:
            missing_team += 1
            continue
        club_id = team_frequency[(league_id, player_id)].most_common(1)[0][0]
        base = players[player_id]
        item_id = f"{league_id.lower()}_{player_id}"
        aliases = list(dict.fromkeys([base["name"], ascii_alias(base["name"]), base["name"].split()[-1]]))
        item = {
            "id": item_id,
            "source_player_id": player_id,
            "name": base["name"],
            "aliases": aliases,
            "league_id": league_id,
            "team_id": club_id,
            "team": clubs.get(club_id, club_id),
            "position": base["position"],
            "stats": {
                **dict(values),
                "goal_contributions": values["goals"] + values["assists"],
            },
        }
        output_players.append(item)
        player_by_league[league_id].append(item)

    questions = []
    for metric, (title, unit, prompt) in QUESTION_DEFINITIONS.items():
        questions.append({
            "id": metric,
            "title": title,
            "unit": unit,
            "prompt_template": prompt,
            "formation": FORMATIONS[metric],
        })

    valid_draws = []
    rejected = Counter()
    draws_per_league_metric = Counter()
    for league_id, league_players in player_by_league.items():
        team_ids = sorted({player["team_id"] for player in league_players})
        for metric, formation in FORMATIONS.items():
            for team_count in (2, 3):
                for selected_teams in itertools.combinations(team_ids, team_count):
                    pool = [player for player in league_players if player["team_id"] in selected_teams]
                    position_counts = Counter(player["position"] for player in pool)
                    if any(position_counts[position] < quota for position, quota in formation.items()):
                        rejected["insufficient_positions"] += 1
                        continue
                    non_zero = [player for player in pool if player["stats"][metric] > 0]
                    if metric not in ("appearances", "minutes") and len(non_zero) < 7:
                        rejected["insufficient_metric_values"] += 1
                        continue
                    # Hedefler yalnızca diziliş kurallarına uyan gerçek kadro
                    # toplamlarından üretilir. Böylece teorik olarak ulaşılamayan
                    # bir hedef hiçbir zaman kuraya giremez.
                    values_by_position = {
                        position: sorted(
                            (player["stats"][metric] for player in pool if player["position"] == position),
                            reverse=True,
                        )
                        for position in formation
                    }
                    achievable_targets = set()
                    for ratio in (0, .12, .25, .40, .58):
                        total = 0
                        for position, quota in formation.items():
                            values = values_by_position[position]
                            start = round(max(0, len(values) - quota) * ratio)
                            total += sum(values[start:start + quota])
                        if total > 0:
                            achievable_targets.add(total)
                    if achievable_targets:
                        competitive_floor = math.ceil(max(achievable_targets) * .30)
                        achievable_targets = {value for value in achievable_targets if value >= competitive_floor}
                    targets = sorted(achievable_targets)
                    if not targets:
                        rejected["zero_target"] += 1
                        continue
                    draw = {
                        "league_id": league_id,
                        "question_id": metric,
                        "team_ids": list(selected_teams),
                        "target_min": targets[0],
                        "target_max": targets[-1],
                        "targets": targets,
                    }
                    valid_draws.append(draw)
                    draws_per_league_metric[f"{league_id}:{metric}"] += 1

    output_players.sort(key=lambda item: (item["league_id"], item["team"], item["name"]))
    valid_draws.sort(key=lambda item: (item["league_id"], item["question_id"], item["team_ids"]))
    output = {
        "schema_version": 2,
        "dataset_version": "2.0.0",
        "season": SEASON_LABEL,
        "leagues": [{"id": key, "name": value} for key, value in LEAGUES.items()],
        "teams": [
            {"id": team_id, "name": clubs.get(team_id, team_id)}
            for team_id in sorted({player["team_id"] for player in output_players})
        ],
        "players": output_players,
        "questions": questions,
        "eligible_draws": valid_draws,
    }
    report = {
        "status": "ok" if valid_draws else "failed",
        "season": SEASON_LABEL,
        "selected_games": len(selected_games),
        "appearance_rows": appearance_rows,
        "players": len(output_players),
        "teams": len(output["teams"]),
        "eligible_draws": len(valid_draws),
        "players_without_historical_team": missing_team,
        "draws_per_league_metric": dict(sorted(draws_per_league_metric.items())),
        "rejected_draws": dict(rejected),
        "league_summary": {
            league_id: {
                "name": LEAGUES[league_id],
                "players": len(player_by_league.get(league_id, [])),
                "teams": len({p["team_id"] for p in player_by_league.get(league_id, [])}),
            }
            for league_id in LEAGUES
        },
    }
    return output, report


def main() -> None:
    parser = argparse.ArgumentParser(description="Futbol Meydanı çok ligli veri dönüştürücü")
    parser.add_argument("--input", required=True, type=Path, help="Transfermarkt CSV klasörü")
    parser.add_argument("--output", type=Path, default=Path("assets/data/meydan_2023_24.json"))
    parser.add_argument("--report", type=Path, default=Path("assets/data/meydan_2023_24_report.json"))
    args = parser.parse_args()
    game_data, report = build(args.input)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(game_data, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if report["status"] != "ok":
        raise SystemExit("Uygun kura üretilemedi; raporu kontrol edin.")


if __name__ == "__main__":
    main()
