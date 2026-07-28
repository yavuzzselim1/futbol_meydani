# Futbol Meydanı v1.20.3 — Çevrimiçi Kurtarma Kurulumu

Bu paket kısa internet kesintilerinde çevrimiçi maçı korur, uygulama yeniden
açıldığında aktif maçı geri getirir ve rakibin bağlantı durumunu gösterir.

## 1. Dosyaları projeye kopyala

Yama ZIP dosyasını açıp içindeki dosyaları şu klasörün üzerine kopyala:

`C:\Users\ydursun\Desktop\futbol_meydani`

Windows sorarsa **Hedefteki dosyaları değiştir** seçeneğini kullan.

## 2. Supabase SQL dosyasını çalıştır

Supabase projesinde **SQL Editor > New query** ekranını aç.

Şu dosyanın tamamını kopyalayıp çalıştır:

`supabase/migrations/20260727160000_online_recovery_v3.sql`

Ekranda `Success. No rows returned` görülmesi normaldir.

v3 dosyasını daha önce çalıştırdıysan ayrıca şu küçük güncellemeyi çalıştır:

`supabase/migrations/20260727173000_online_presence_v4.sql`

## 3. Projeyi kontrol et

PowerShell'i proje klasöründe açıp sırayla çalıştır:

```powershell
dart format lib
flutter analyze
flutter test
```

`flutter analyze` sonucunun hata vermemesi, testlerin de `All tests passed`
mesajıyla bitmesi gerekir.

## 4. İki cihazla yapılacak kısa test

1. İki farklı hesapla aynı odaya girip maçı başlat.
2. Kadro kurarken ikinci cihazın internetini 15–20 saniye kapat.
3. İlk cihazda rakibin bağlantısının kesildiği bilgisi görünmeli.
4. İkinci cihazda interneti açıp uygulamaya dön; maç aynı aşamadan sürmeli.
5. İkinci cihazda uygulamayı tamamen kapatıp yeniden aç.
6. Online Meydan'da **Maça Devam Et** kartı görünmeli.
7. Rakip 60 saniyeden uzun süre dönmezse **Hükmen Bitir** seçeneği açılmalı.
8. Normal sonuç, rövanş ve açıkça odadan ayrılma akışlarını da birer kez dene.

## Pakette gelen başlıca değişiklikler

- 5 saniyelik çevrimiçi oyuncu nabzı ve yaklaşık 15–20 saniyede kopma algılama
- Kopan gerçek zamanlı oda akışında otomatik yeniden bağlanma
- Sunucudan aktif oda bulma ve maça kaldığı yerden dönme
- Rakibin bağlantı durumu ve 60 saniyelik geri dönüş süresi
- Sunucu doğrulamalı hükmen galibiyet
- Süresi dolan davet, kuyruk ve eski oda temizliği
- Bir hesabın aynı anda birden fazla aktif odada kalmasının engellenmesi
- Sürüm: `1.20.3+44`
