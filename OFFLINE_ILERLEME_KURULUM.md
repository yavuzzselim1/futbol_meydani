# Çevrimdışı İlerleme Birleştirme

Bu sürüm, çevrimdışı oynanan ilerlemeyi giriş yapıldıktan sonra Supabase
profiliyle güvenli biçimde birleştirir.

## 1. Supabase güncellemesi

Supabase Dashboard içinde **SQL Editor > New query** bölümünü açın.
Ardından aşağıdaki dosyanın tamamını çalıştırın:

`supabase/migrations/20260727140000_offline_progress_merge.sql`

İşlem başarılı olmadan bu özelliği APK üzerinde test etmeyin.

## 2. Yerel kontrol

```powershell
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
```

## 3. Test senaryosu

1. Hesaptan çıkış yapın ve çevrimdışı devam edin.
2. Son Dakika modunda ilerleyin; XP veya MP kazanın.
3. Ana ekrandaki profil alanına dokunup giriş yapın.
4. Cihaz ve bulut karşılaştırma penceresinin açıldığını doğrulayın.
5. **İlerlemeyi Birleştir** seçeneğini kullanın.
6. Uygulamayı yeniden açın ve aynı ilerlemenin ikinci kez eklenmediğini
   doğrulayın.

## Birleştirme kuralları

- XP, MP ve Son Dakika rekorlarında yüksek değer korunur.
- Kariyer yıldızları etap bazında karşılaştırılır.
- Avatar, tema ve rozetler birleştirilir.
- Kupa ile çevrimiçi maç/galibiyet/mağlubiyet istatistikleri yalnızca
  sunucudan alınır.
- Değerler birbirine eklenmediği için aynı veri tekrar aktarılsa bile ödül
  iki kez verilmez.
