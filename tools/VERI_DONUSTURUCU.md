# Futbol Meydanı veri dönüştürücü

Bu araç Transfermarkt veri setinden yalnızca 2023/24 sezonundaki şu ligleri alır:

- Premier League (`GB1`)
- La Liga (`ES1`)
- Serie A (`IT1`)
- Trendyol Süper Lig (`TR1`)

## Gerekli dosyalar

Kaggle arşivini bir klasöre çıkartın. Araç bu klasörde aşağıdaki dosyaları
`.csv` veya `.csv.gz` biçiminde arar:

- `games`
- `appearances`
- `players`
- `clubs`

## Çalıştırma

Proje klasöründe PowerShell açıp aşağıdaki komutu çalıştırın. Son bölümdeki
klasörü veri setini çıkarttığınız konumla değiştirin:

```powershell
python .\tools\build_transfermarkt_game_data.py --input "C:\Users\KULLANICI_ADI\Downloads\transfermarkt"
```

Üretilen dosyalar:

- `assets/data/meydan_2023_24.json`: Uygulamanın kullanacağı küçük veri
- `assets/data/meydan_2023_24_report.json`: Eksik veri ve uygun kura raporu

Kura havuzuna yalnızca seçilen 2–3 takımda diziliş için yeterli mevkisi ve
soru için yeterli istatistiği bulunan kombinasyonlar alınır. Uygun olmayan
kuralar oyuncuya gösterilmeden veri hazırlama aşamasında elenir.
