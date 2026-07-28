import 'package:flutter_test/flutter_test.dart';
import 'package:futbol_meydani/utils/helpers.dart';
import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/constants.dart';

void main() {
  // ─── normalize() ────────────────────────────────────────────────
  group('normalize()', () {
    test('Türkçe karakterleri dönüştürür', () {
      expect(normalize('İlkay Gündoğan'), 'ilkay gundogan');
      expect(normalize('Çağlar Söyüncü'), 'caglar soyuncu');
      expect(normalize('Hakan Şükür'), 'hakan sukur');
    });

    test('Büyük-küçük harf duyarsız', () {
      expect(normalize('SALAH'), normalize('salah'));
    });

    test('Fazla boşlukları temizler', () {
      expect(normalize('  Erling   Haaland  '), 'erling haaland');
    });

    test('Özel karakterleri çıkarır', () {
      expect(normalize("De Bruyne (Man City)"), 'de bruyne man city');
    });
  });

  // ─── formatTime() ───────────────────────────────────────────────
  group('formatTime()', () {
    test('00:00 için sıfır', () => expect(formatTime(0), '00:00'));
    test('90 saniye = 01:30', () => expect(formatTime(90), '01:30'));
    test('65 saniye = 01:05', () => expect(formatTime(65), '01:05'));
    test('3600 saniye = 60:00', () => expect(formatTime(3600), '60:00'));
  });

  // ─── positionName() ─────────────────────────────────────────────
  group('positionName()', () {
    test('GK → Kaleci', () => expect(positionName('GK'), 'Kaleci'));
    test('DF → Defans', () => expect(positionName('DF'), 'Defans'));
    test('MF → Orta Saha', () => expect(positionName('MF'), 'Orta Saha'));
    test('FW → Forvet', () => expect(positionName('FW'), 'Forvet'));
    test('Bilinmeyen pozisyon olduğu gibi döner', () {
      expect(positionName('ST'), 'ST');
    });
  });

  // ─── joinTurkish() ──────────────────────────────────────────────
  group('joinTurkish()', () {
    test('Tek eleman', () => expect(joinTurkish(['Arsenal']), 'Arsenal'));
    test('İki eleman "ve" ile birleşir', () {
      expect(joinTurkish(['Arsenal', 'Chelsea']), 'Arsenal ve Chelsea');
    });
    test('Üç eleman virgülle + "ve"', () {
      expect(
        joinTurkish(['Arsenal', 'Chelsea', 'Liverpool']),
        'Arsenal, Chelsea ve Liverpool',
      );
    });
    test('Boş liste boş string döner', () {
      expect(joinTurkish([]), '');
    });
  });

  // ─── Formation.forMetric() ──────────────────────────────────────
  group('Formation.forMetric()', () {
    test('goals → 1-2-2-2 Hücum', () {
      final f = Formation.forMetric('goals');
      expect(f.label, '1-2-2-2 Hücum');
      expect(f.quota('FW'), 2);
    });

    test('assists → 1-2-3-1 Oyun Kurucu', () {
      final f = Formation.forMetric('assists');
      expect(f.label, '1-2-3-1 Oyun Kurucu');
      expect(f.quota('MF'), 3);
    });

    test('tackles → 1-3-2-1 Savunma', () {
      final f = Formation.forMetric('tackles');
      expect(f.label, '1-3-2-1 Savunma');
      expect(f.quota('DF'), 3);
    });

    test('bilinmeyen metrik → Dengeli', () {
      final f = Formation.forMetric('pass_accuracy');
      expect(f.label, '1-3-2-1 Dengeli');
    });

    test('Toplam oyuncu sayısı her zaman 7', () {
      for (final metric in ['goals', 'assists', 'tackles', 'interceptions']) {
        final f = Formation.forMetric(metric);
        final total =
            f.quota('GK') + f.quota('DF') + f.quota('MF') + f.quota('FW');
        expect(total, 7, reason: 'metric=$metric');
      }
    });
  });

  // ─── emptyPick() ────────────────────────────────────────────────
  group('emptyPick()', () {
    test('Değer 0 döner', () => expect(emptyPick().value, 0));
    test('Varsayılan pozisyon —', () {
      expect(emptyPick().player.position, '—');
    });
    test('Özel pozisyon', () {
      expect(emptyPick('GK').player.position, 'GK');
    });
    test('Oyuncu adı "Seçilmedi"', () {
      expect(emptyPick().player.name, 'Seçilmedi');
    });
  });

  // ─── GameSound enum ─────────────────────────────────────────────
  group('GameSound enum', () {
    test('Tüm sesler enum değeri olarak var', () {
      expect(GameSound.values.length, greaterThan(5));
      expect(GameSound.values.map((e) => e.name), contains('tap'));
      expect(GameSound.values.map((e) => e.name), contains('win'));
      expect(GameSound.values.map((e) => e.name), contains('perfect'));
    });
  });
}
