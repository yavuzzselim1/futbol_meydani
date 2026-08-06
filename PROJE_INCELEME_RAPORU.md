# Futbol Meydanı — Proje İnceleme Raporu

**Tarih:** 2026-08-06
**Kapsam:** Flutter mobil uygulama + Supabase backend, tüm `lib/`, `supabase/migrations/`, kök dizin dosyaları ve dokümantasyon.

---

## Yönetim Özeti

Futbol Meydanı, Türkçe bir futbol bilgi/tahmin oyunu; çevrimdışı oynanabilen bir kariyer modu ile Supabase üzerinden çalışan çevrimiçi çok oyunculu, ranked lig, arkadaşlık/sohbet ve mağaza sistemlerini birleştiren, ~19-29K satırlık orta-büyük ölçekli bir Flutter projesi. Ürün fikri ve genel mimari (repository pattern, sunucu tarafı RPC'ler, offline/online progress merge) sağlam temellere sahip; ancak inceleme sırasında **kritik seviyede güvenlik açıkları**, **sürüm kontrolünün tamamen eksikliği** ve **neredeyse sıfır otomatik test kapsamı** tespit edildi. Bu üçü, projenin production'a güvenle taşınabilmesi için en acil giderilmesi gereken alanlar.

**En kritik 5 bulgu:**
1. Tüm e-posta/şifre hesapları aynı sabit şifreyi (`'AutoLoginPass123!'`) kullanıyor — herhangi biri bir kullanıcının e-postasını bilerek o hesabı ele geçirebilir.
2. `online_profiles` tablosunda `WITH CHECK` eksik — istemci, `rating`/`coins`/`wins` gibi alanları doğrudan REST çağrısıyla değiştirebiliyor, tüm sunucu taraflı doğrulamayı by-pass ediyor.
3. `credit_reward` fonksiyonunda hem yetki kontrolü hem GRANT/REVOKE kısıtlaması yok — herhangi bir kullanıcı sınırsız coin basabilir.
4. Ranked lig maç sonuçları (`finalize_ranked_match`) istemcinin gönderdiği "stat" değerlerine güveniyor — sahte veriyle garantili galibiyet mümkün.
5. Proje hiç git deposu değil (`.git` klasörü yok) — geçmiş, geri alma, CI/CD ve güvenli işbirliği imkânı sıfır.

---

## 1. Güvenlik Bulguları (Supabase Backend)

Bu bölüm, ciddiyeti nedeniyle raporun en öncelikli kısmıdır.

### 1.1 KRİTİK — Tüm hesaplar aynı sabit şifreyi kullanıyor

`lib/screens/auth/email_auth_screen.dart:103-116` içinde giriş/kayıt akışı kullanıcıdan hiç şifre almıyor; sabit bir sabit kullanıyor:

```dart
const dummyPassword = 'AutoLoginPass123!';
await client.auth.signInWithPassword(email: email, password: dummyPassword);
// veya
await client.auth.signUp(email: email, password: dummyPassword);
```

Google ve Apple ile giriş şu an devre dışı/stub durumda (`auth_screen.dart`), yani bu e-posta akışı fiilen **tek gerçek hesap sistemi**. Uygulamada gömülü olan public anon anahtarla, bir kullanıcının e-posta adresini bilen herkes doğrudan Supabase Auth REST uç noktasına `signInWithPassword(email: kurban@x.com, password: 'AutoLoginPass123!')` çağrısı yaparak **o hesabı tamamen ele geçirebilir** (sohbet geçmişi, arkadaşlarına karşı taklit, profil/coin/rating manipülasyonu). Bu, saldırgan için hiçbir reverse-engineering gerektirmiyor — en yüksek öncelikli düzeltme.

**Öneri:** Gerçek şifre alanı ekleyin veya (daha uygun) magic-link/OTP tabanlı e-posta doğrulamasına geçin; sabit şifre deseni tamamen kaldırılmalı.

### 1.2 KRİTİK — `online_profiles` tablosunda eksik `WITH CHECK`

`supabase/migrations/20260726000001_initial_schema.sql:100-101`:

```sql
create policy "Players update own online profile" on public.online_profiles
  for update to authenticated using (auth.uid() = id);
```

`WITH CHECK` olmadan bu politika sadece **hangi satırın** güncellenebileceğini kontrol ediyor, **hangi sütunların** hangi değerlere değişebileceğini değil. Nitekim uygulamanın kendisi de `lib/services/game_store.dart:801-824`'te `coins` alanını doğrudan `client.from('online_profiles').update({'coins': coins})` ile yazıyor — aynı yöntemle herhangi bir istemci `rating`, `wins`, `matches`, `xp` gibi alanları da doğrudan değiştirebilir, tüm maç/ELO doğrulama mantığını atlayarak. Bu tek eksiklik, projede başka yerlerde özenle kurulmuş anti-hile mekanizmalarının çoğunu geçersiz kılıyor.

**Öneri:** `WITH CHECK` ekleyin ve hassas alanları (rating, wins, losses, matches, coins) doğrudan `UPDATE` yetkisinden çıkarıp yalnızca `SECURITY DEFINER` RPC'ler üzerinden değiştirilebilir hale getirin (ranked tablolarda zaten yapıldığı gibi).

Aynı `WITH CHECK` eksikliği `friends` (satır 985-986) ve `game_invites` (satır 1007-1008) UPDATE politikalarında da var — kullanıcılar `user_id`/`from_id`/`to_id` gibi FK sütunlarını rastgele UUID'lere çevirebilir (orta öncelik).

### 1.3 KRİTİK — `credit_reward` fonksiyonunda yetki ve GRANT/REVOKE eksik

`supabase/migrations/20260802000000_ranked_leagues_v2_seasons.sql` içindeki `credit_reward` ve `close_competitive_season` fonksiyonları, projedeki diğer tüm `SECURITY DEFINER` fonksiyonlarının aksine **hiçbir** `REVOKE ALL ... FROM public, anon` / `GRANT EXECUTE ... TO authenticated` içermiyor. PostgreSQL varsayılan olarak yeni fonksiyonlara `PUBLIC` çalıştırma izni verir. Üstelik `credit_reward` fonksiyon gövdesinde çağıranın kimliğini (`auth.uid() = p_user_id`) doğrulayan **hiçbir kontrol yok**:

```sql
CREATE OR REPLACE FUNCTION public.credit_reward(p_user_id uuid, p_amount integer, p_reason text, p_reference_id text)
...
  UPDATE public.online_profiles SET coins = coins + p_amount WHERE id = p_user_id;
```

Eğer bu izin canlı veritabanında da açıksa, herhangi bir kimliği doğrulanmış kullanıcı `.rpc('credit_reward', {p_user_id: herhangi_biri, p_amount: 999999999, ...})` çağrısıyla sınırsız coin üretebilir; `close_competitive_season` da benzer şekilde herhangi biri tarafından erken tetiklenebilir.

**Öneri:** Acilen production veritabanındaki gerçek GRANT/REVOKE durumunu (migration dosyaları değil, canlı DB) doğrulayın; eksikse hemen kapatın ve fonksiyon içine `auth.uid() = p_user_id` kontrolü ekleyin.

### 1.4 KRİTİK — Ranked lig maç sonuçları istemci verisine güveniyor

`lib/widgets/online/online_squad_screen.dart:444-451`'de her oyuncu kartının "stat" değeri, tamamen istemci tarafında bundle edilmiş statik JSON verisinden (`assets/data/*.json`) hesaplanıyor — sunucuda bu istatistiklerin bir kopyası yok. Sunucu fonksiyonu `finalize_ranked_match` (`supabase/migrations/20260801000000_ranked_leagues_v1.sql:417-480, 534-542`) gönderilen "stat" değerlerini olduğu gibi toplayıp kazananı belirliyor ve kupa/trophy dağıtıyor:

```sql
FOR v_item IN SELECT * FROM jsonb_array_elements(v_host_sub.squad_payload) LOOP
  v_host_total := v_host_total + coalesce((v_item.value->>'stat')::numeric, 0);
END LOOP;
```

Değiştirilmiş bir istemci, hedefe (`target`) tam eşit sahte "stat" toplamları göndererek **her maçı garantili kazanabilir** ve en üst rekabetçi katmana kadar ilerleyebilir. Bu, ranked/lig sisteminin temel anti-hile açığı.

**Öneri:** Oyuncu istatistiklerini sunucu tarafında (bir tablo/fonksiyon olarak) tutun ve `finalize_ranked_match` içinde gönderilen `id` listesine karşılık gelen gerçek stat değerlerini sunucuda hesaplayın; istemciden gelen `stat` alanına asla güvenmeyin.

Benzer, daha düşük şiddette bir sorun casual maçlarda da var: `finish_online_match` (satır 472-505) host'un gönderdiği `host_total`/`guest_total`/`target_value` değerlerini doğrudan ELO/geçmiş için kullanıyor, sunucu tarafında yeniden hesaplama yapmıyor (orta öncelik).

### 1.5 YÜKSEK — Offline progress merge'de üst sınır ve doğrulama yok

`merge_offline_progress` RPC'si (`supabase/migrations/20260727140000_offline_progress_merge.sql:47-182`), istemcinin gönderdiği `coins`/`xp` gibi değerleri `greatest(server, client)` ile birleştiriyor — **üst sınır yok**. Kozmetik kilit açma (avatar/tema/rozet) kontrolü de yalnızca gönderilen ID'nin bilinen bir enum'a ait olup olmadığını kontrol ediyor, oyuncunun bunu gerçekten hak edip etmediğini değil. Bir istemci yerel `coins`/`xp` değerini keyfi büyük bir sayıya ayarlayıp giriş sırasında merge tetikleyerek kalıcı, geri alınamaz bir şekilde tüm premium kozmetikleri "kazanabilir".

**Öneri:** Coins/xp için makul bir üst sınır (ör. son bilinen oturumdan bu yana geçen süreye göre maksimum kazanılabilir miktar) ekleyin; kozmetik unlock'ları sunucu tarafında gerçek koşullara (ör. seviye, başarı tablosu) göre doğrulayın.

### 1.6 YÜKSEK — `messages` (sohbet) tablosu hiçbir migration'da yok

`supabase/` altındaki hiçbir SQL dosyasında `messages` tablosunun `CREATE TABLE`'ı bulunmuyor, ancak `lib/screens/chat_screen.dart` ve `lib/services/social_store.dart` bu tabloyu aktif olarak sorguluyor/yazıyor. Bu, tablonun production'da migration sistemi dışında (muhtemelen Dashboard SQL editöründen) oluşturulduğu anlamına geliyor. Sonuç: **bu tablonun RLS politikaları bu kod tabanından doğrulanamıyor.** `chat_screen.dart:196`'daki `delete` çağrısı `sender_id` filtresi içermiyor — eğer RLS politikası projedeki genel `WITH CHECK` eksikliği paternini tekrarlıyorsa, taraflardan biri karşı tarafın mesajını da silebilir; benzer şekilde RLS eksikse `receiver_id` filtresi sahtelenerek başka kullanıcıların mesajları realtime kanaldan dinlenebilir.

**Öneri:** `supabase db pull` ile gerçek `messages` tablosu ve politikalarını çekip gerçek bir migration dosyası olarak repoya ekleyin; RLS'yi (özellikle DELETE ve realtime SELECT) doğrulayın.

### 1.7 ORTA — Migration hijyeni: takip dışı "fix" dosyaları

`supabase/fix_presence.sql`, `supabase/migrations/fix_permissions.sql`, `supabase/migrations/fix_missing_season.sql` numaralandırılmamış, ad hoc hotfix dosyaları. `fix_presence.sql` özellikle `migrations/` klasörünün dışında duruyor, yani Supabase CLI migration araçları bunu asla göremez — production'a yalnızca Dashboard'dan elle uygulanmış olmalı. Karşılaştırıldığında, `fix_presence.sql`'deki `touch_online_presence` fonksiyonu, `20260727160000_online_recovery_v3.sql`'deki versiyondan farklı olarak `revision = r.revision + 1` satırını **içermiyor** — sessiz bir davranış regresyonu riski. `fix_permissions.sql` da `anon` rolüne SELECT yetkisi ekliyor, bu da ranked lig özelliğinin production'da RLS nedeniyle en az bir kez bozulup canlıda yamalandığını gösteriyor.

**Öneri:** Tüm "fix_*.sql" dosyalarını numaralı migration'lara dönüştürün; production veritabanının gerçek şemasını periyodik olarak `supabase db diff` ile migration dosyalarıyla karşılaştırın.

### 1.8 DÜŞÜK-ORTA — Secrets / gizli anahtar yönetimi

- `lib/online/supabase_online_game.dart:33-35`'te `.env` yüklenemezse kullanılan bir fallback Supabase URL + publishable key **kaynak koduna gömülü**. Bu anahtar "publishable" (anon) tipte olduğu için tek başına kritik değil, ancak `SUPABASE_KURULUM.txt`'nin "anahtarlar asla kaynak dosyalara yazılmaz" iddiasıyla çelişiyor ve yukarıdaki tüm RLS açıklarının APK'yı indiren herkes tarafından sıfır reverse-engineering ile kullanılabilir olduğu anlamına geliyor.
- Aynı anahtar `check_db_http.dart` betiğinde bir kez daha hardcoded.
- `.gitignore` içinde `.env` için bir kural yok — proje git'e alınırsa dolu bir `.env` yanlışlıkla commit'lenebilir.
- `.env` aynı zamanda `pubspec.yaml`'da bundle edilen bir asset olarak tanımlı — içine gerçek bir secret konursa derlenen uygulama paketine de gömülür.

**Öneri:** `.env`'i `.gitignore`'a ekleyin; hardcoded fallback anahtarı kaldırıp yapılandırmayı zorunlu hale getirin (uygulama `.env`/`--dart-define` olmadan online özellikleri devre dışı bırakmalı, sessizce production'a fallback etmemeli).

### 1.9 DÜŞÜK — PostgREST filtre string'leri interpolasyonla kuruluyor

`lib/online/supabase_online_game.dart:444` ve `lib/services/social_store.dart:97,143`'te `.or('host_id.eq.$userId,...')` gibi ham filtre string'leri doğrudan interpolasyonla oluşturuluyor. Şu an bu değerler her zaman `auth.users.id` UUID'lerinden geldiği için pratik risk düşük, ancak SDK'nın yapısal filtre builder'larına (`.or([...])`) geçilmesi daha sağlam ve gelecekte serbest metin girişi eklenirse oluşabilecek filtre-enjeksiyonu riskini tamamen ortadan kaldırır.

### 1.10 Olumlu güvenlik gözlemleri

Dengeli bir değerlendirme için: proje genelinde çoğu yazma işlemi doğru şekilde `SECURITY DEFINER` fonksiyonlar + açık `REVOKE`/`GRANT` çiftleriyle korunuyor; `player_ladders`/`ranked_matches`/`trophy_transactions` gibi hassas tablolarda yalnızca SELECT politikaları var, yazma yalnızca RPC üzerinden mümkün; `game_logs` tablosu tamamen kilitli ve hassas anahtar/token bilgisi loglardan filtreleniyor (`write_game_log`); oda bazlı tablolarda (`online_rooms`, `online_squads`) katılımcı bazlı SELECT kısıtlaması doğru kurulmuş; service_role anahtarı hiçbir yerde sızdırılmamış. Mimarinin niyeti doğru, uygulamadaki tutarsızlıklar giderilmeli.

---

## 2. Mimari ve Kod Kalitesi

### 2.1 State management: kontrolsüz global singleton'lar

Proje herhangi bir state-management paketi (provider/riverpod/bloc) kullanmıyor; bunun yerine `lib/globals.dart`'ta üst seviyede oluşturulan global singleton'lara (`gameStore`, `socialStore`, `diagnostics`, `inviteService`, `rankedStore`) dayanıyor. `GameStore` ve `SocialStore` `ChangeNotifier`'dan türüyor ama tüketimi tutarsız: ~27 dosya `gameStore.*` alanlarını doğrudan okuyor, bunlardan yalnızca ~14'ü `AnimatedBuilder`/`ListenableBuilder` ile gerçekten dinliyor — geri kalanı `setState` ile yerel state'e güveniyor, bu da global state başka yerde değiştiğinde UI'ın bayatlamasına yol açabilir.

`GameStore` üzerindeki `addCoins`/`deductCoins`/`addXp` gibi metodlar (`lib/services/game_store.dart:801-824`), Supabase'e "fire-and-forget" (`.then(...).catchError((_){})`) yazıyor, herhangi bir sıralama/kilitleme mekanizması yok — hızlı art arda çağrılar (ör. çift dokunmalı satın alma) sırasız yazmalara yol açabilir çünkü her çağrı `coins` alanını doğrudan okuyup yazıyor, sunucu tarafı atomik increment kullanmıyor.

**Öneri:** En azından kritik ekranlarda (satın alma, maç sonucu) global store yerine sunucu tarafı atomik RPC'ler (`increment` fonksiyonu) kullanın; uzun vadede en azından `ChangeNotifierProvider`/`ValueListenableBuilder` gibi hafif bir çözümle tutarlı dinleme paternine geçin.

### 2.2 Ekranlar iş mantığı + veri erişimi + UI'yi karıştırıyor

`lib/screens/friends_screen.dart` gibi dosyalarda anonim giriş, Realtime abonelik kurulumu/kapatma ve ham tablo sorguları doğrudan `State` sınıfı içinde — sosyal/arkadaşlık özelliği için bir repository/servis katmanı yok (buna karşın maç mantığı için `OnlineGameRepository`/`RankedLeagueRepository` arayüzleri temiz bir repository pattern kullanıyor — tutarsızlık).

`home_screen.dart` (2606 satır) ve `settings_screen.dart` (2154 satır) tek dosyada 20-30 sınıf barındıran devasa monolitik dosyalar; bu, diff/review'ı zorlaştırıyor ve merge çakışması riskini artırıyor. `home_screen.dart`'ta zaten var olan `widgets/home/home_widgets.dart`'a taşınabilecek 19 özel widget sınıfı bulunuyor — kısmi ama tutarsız bir bölünme var.

Oyun mantığı ekranları (`match_screen.dart`, `squad_challenge_screen.dart`) Supabase'e doğrudan bağlanmıyor ama zamanlayıcı/simülasyon mantığını (`Timer.periodic`) doğrudan `State` içine gömüyor — kazanma koşulu gibi iş kuralları widget ağacından bağımsız test edilemiyor.

**Öneri:** Büyük ekranları özellik bazlı alt dosyalara bölün; sosyal/arkadaşlık özelliği için de maç mantığındaki gibi bir repository katmanı ekleyin; zamanlayıcı/oyun mantığını `State`'ten ayrı, test edilebilir controller sınıflarına taşıyın.

### 2.3 Offline/online senkronizasyon: OAuth akışı merge kontrolünü atlıyor

Offline progress merge modeli (`lib/models/progress_merge.dart`, `lib/services/progress_merge_service.dart`) iyi tasarlanmış: alan bazlı karşılaştırma yapıp gerçek birleştirmeyi güvenli bir sunucu RPC'sine devrediyor. Ancak bu güvenli akış yalnızca `email_auth_screen.dart:62-75`'ten çağrılıyor. `auth_screen.dart:55-87`'deki Google/Apple OAuth yolları `signInWithOAuth` çağrısından sonra merge-preview akışını **hiç tetiklemiyor** — bir kullanıcı offline ilerleme biriktirip Google ile giriş yaparsa, `GameStore.load()`'daki otomatik `syncProfile()` (`game_store.dart:288-293`) yerel alanları sessizce cloud verisiyle **üzerine yazıyor** (`_applyCloudProfile`, satır 420-489) — somut, tekrarlanabilir bir veri kaybı senaryosu.

Ayrıca `_markOfflineProgressDirty()` yalnızca bazı mutator'lardan çağrılıyor (`addXp`, `addCoins`, `recordLastMinute`, unlock metodları) — `deductCoins` ve `addTrophies` progress'i "dirty" olarak işaretlemiyor, yani offline'da harcanan coin veya kazanılan kupa değişiklikleri merge-preview kontrolünde görünmeyebilir.

**Öneri:** OAuth giriş akışlarına da e-posta akışındaki merge-preview çağrısını ekleyin; `_markOfflineProgressDirty()` çağrısını tüm ilerleme değiştiren mutator'lara genişletin.

### 2.4 Hata yönetimi tutarsız

`DiagnosticLogStore` (`lib/services/diagnostic_store.dart`) iyi tasarlanmış bir global hata/crash yakalama sistemi (hassas veri filtreleme, offline kuyruk, otomatik flush) — ancak kullanımı tutarsız. Kod tabanındaki çoğu `catch` bloğu (`game_store.dart`, `social_store.dart` içinde birçok yer) yalnızca `debugPrint` yapıp hatayı yutuyor, `diagnostics.record(...)` çağırmıyor — yani gerçek dünyadaki çoğu Supabase hatası (başarısız arkadaşlık isteği, başarısız XP senkronu) uygulama içi tanı raporunda görünmez. Ayrıca hiçbir loglama yapmayan 9 adet boş `catch (_) {}` bloğu tespit edildi (`supabase_online_game.dart:261`, `auth_screen.dart:31`, `settings_screen.dart:1004,1007` vb.) — bazıları savunulabilir (best-effort presence ping) ama bazıları (ör. `continueOffline` sırasındaki sign-out hatası) auth durumunun tutarsız kalmasına yol açabilir, hiçbir iz bırakmadan.

**Öneri:** Tüm `catch` bloklarında en azından `diagnostics.record(...)` çağrısını standart hale getiren bir yardımcı fonksiyon/wrapper oluşturun.

### 2.5 Ölü kod ve tekrar

- `lib/widgets/last_minute/last_minute_screen.dart` (496 satır) hiçbir yerden çağrılmıyor — yerini `advanced_last_minute_screen.dart` (1625 satır) almış, eski dosya silinmemiş.
- `lib/main.dart.bak` (5008 satır, ~197KB) — eski monolitik `main.dart`'ın tam bir yedeği, `lib/` içinde duruyor. Sürüm kontrolü olmadığı için geliştirici bunu "yedek" olarak tutmuş; git kullanılsaydı gerek kalmazdı.
- `home_screen.dart` gibi dosyalarda mojibake (bozuk karakter kodlaması) yorum satırları var (`â”€â”€â”€ Palette â”€â”€â”€`) — dosyanın bir noktada yanlış encoding ile kaydedildiğine işaret ediyor; Türkçe karakter içeren string'lerde de benzer bozulma riski taşıyabilir, kontrol edilmeli.

**Öneri:** `last_minute_screen.dart` ve `main.dart.bak`'ı silin (git geçmişi bu işlevi zaten görür); dosya encoding'lerini UTF-8 olarak standardize edin.

### 2.6 Navigasyon

Tamamen imperatif navigasyon (71 adet `Navigator.push`/`MaterialPageRoute` çağrısı), adlandırılmış route yok, router paketi yok — mevcut ölçekte çalışıyor ama navigasyon grafiğini tek bir yerden okumak mümkün değil. Davet sistemi (`InviteService`) tamamen uygulama-içi Supabase Realtime üzerinden çalışıyor; OS seviyesinde derin bağlantı (deep link) desteği yok, yani "arkadaşını davet et" bağlantısı yalnızca her iki taraf da uygulamayı zaten açıkken çalışıyor.

---

## 3. Test, DevOps ve Proje Hijyeni

### 3.1 KRİTİK — Proje bir git deposu değil

`c:\Users\Yavuz Selim\Desktop\futbol_meydani-main` içinde `.git` klasörü **yok**. Bu, aşağıdaki tüm sorunların temelinde yatan en büyük yapısal eksiklik:
- Hiçbir değişiklik geçmişi yok — kim, ne zaman, neden değiştirdi bilgisi yok (tek kayıt `KURULUM.txt`'deki elle tutulan, güncel olmayan bir değişiklik notu).
- Geri alma/bisect imkânı yok — kötü bir değişiklik geri alınamıyor; bunun yerine `main.dart.bak` gibi elle tutulan yedekler kullanılmış.
- Branch/paralel geliştirme yok; `ONLINE_KURTARMA_KURULUM.md` dosyası "yama ZIP'ini üzerine kopyala" talimatı içeriyor — gerçek bir VCS'in yokluğunun somut belirtisi.
- CI/CD kurulamaz çünkü tetikleyecek bir push/PR mekanizması yok (`.github/` klasörü de zaten yok).
- İki kişi aynı anda `home_screen.dart` (2606 satır) üzerinde çalışırsa hiçbir çakışma tespiti olmadan birbirinin değişikliğini ezebilir.

**Öneri:** Projeyi bugün `git init` ile bir depoya çevirin (önce `.gitignore`'a `.env` ekleyin, `main.dart.bak`/`check_db*.dart`/`scripts/*.py` gibi dosyaları temizleyin), ardından GitHub/GitLab gibi bir uzak depoya bağlayıp temel bir CI (en azından `flutter analyze` + `flutter test`) kurun.

### 3.2 Test kapsamı gerçeği

Yalnızca iki test dosyası var: `test/logic_test.dart` (122 satır) ve `test/progress_merge_test.dart` (100 satır) — toplam ~220 satır, yalnızca saf yardımcı fonksiyonları (`normalize`, `formatTime`, `Formation.forMetric`) ve `ProgressSnapshot` modelini test ediyor. **~19.000+ satırlık `lib/` kodunun geri kalanı — tüm 20 ekran dosyası, tüm servisler (`game_store.dart` dahil, 1042 satır), tüm online/realtime katmanı — sıfır otomatik test kapsamına sahip.** Widget testi (`testWidgets`/`pumpWidget`) veya entegrasyon testi hiç yok; mocking için `mocktail`/`mockito` gibi bir paket bile dev dependency olarak eklenmemiş.

**Öneri:** Önce `game_store.dart` ve `progress_merge_service.dart` gibi kritik iş mantığı servislerine birim test ekleyin (mocking için bir paket ekleyerek); ardından en azından ana akış (giriş, maç oynama, satın alma) için birkaç widget/entegrasyon testi ekleyin.

### 3.3 Dokümantasyon kalitesi

- **README.md hâlâ Flutter'ın varsayılan şablonu** — projeye özgü tek bir kelime içermiyor. Yeni bir geliştiricinin okuyacağı ilk dosya hiçbir gerçek bilgi vermiyor.
- `KURULUM.txt` kurulum adımlarıyla elle tutulan bir değişiklik günlüğünü karıştırıyor ve v1.18.0/build36'da duruyor; mevcut sürüm ise 1.20.3+44 — yaklaşık 4 minor sürüm geride.
- `SUPABASE_KURULUM.txt`, "anahtarlar kaynak dosyalara yazılmaz" diyor ama bu, yukarıda (1.8) belirtildiği gibi doğru değil — kod ile doküman çelişiyor.
- `ONLINE_KURTARMA_KURULUM.md` başka bir geliştiricinin makinesine ait sabit bir yol içeriyor (`C:\Users\ydursun\Desktop\futbol_meydani`) — "patch ZIP'i üzerine kopyala" iş akışının, gerçek bir dağıtım sürecinin yerini tuttuğunu doğruluyor.
- `LOG_SISTEMI.txt` ise kodla gerçekten örtüşen, iyi yazılmış tek doküman.
- Ayrı bir `CHANGELOG.md` yok.

**Öneri:** README.md'yi proje açıklaması, kurulum adımları ve mimari özetiyle yeniden yazın; KURULUM.txt'deki değişiklik günlüğünü ayrı bir `CHANGELOG.md`'ye taşıyıp güncel tutun.

### 3.4 Kök dizinde secrets içeren scratch/debug dosyaları

- `check_db_http.dart` — Supabase URL'sini ve publishable key'i doğrudan hardcoded içeriyor, ham HTTP çağrısı yapıyor.
- `check_db.dart`, `test_parse.dart` — tek seferlik debug betikleri, uygulamanın parçası değil.
- `lib/scratch_auth.dart` — `lib/` içinde duran, hiçbir yerden çağrılmayan 5 satırlık test betiği (derlenebilir ama ölü kod).
- `scripts/extract_home.py`, `find_extracted.py`, `find_remaining.py`, `fix_all.py` — geçmiş bir refactor'a ait, başka bir geliştirici makinesine ait sabit yollar içeren tek kullanımlık betikler.
- `lib/main.dart.bak` — 5008 satırlık eski monolitik `main.dart` yedeği.

**Öneri:** Bu dosyaların tamamını depodan kaldırın (gerekirse `git init` sonrası ilk commit'ten önce); gerçekten gerekli debug betikleri varsa ayrı bir `tools/` veya `.gitignore`'lanmış bir klasöre taşıyın.

### 3.5 Lint / analiz yapılandırması

`analysis_options.yaml` tamamen varsayılan `flutter_lints` içeriyor, hiçbir özelleştirme yok (tüm örnek satırlar yorum halinde). ~19-29K satırlık, ağır network/state karmaşıklığına sahip bir proje için bu, sessiz hata yutma (`catch (_) {}`) gibi paternleri yakalayacak ek kural zenginliğinden yoksun.

### 3.6 Platform scaffolding fazlalığı

`android/`, `ios/` yanında `linux/`, `macos/`, `web/`, `windows/` klasörleri de mevcut — proje tanımı "mobil futbol bilgi oyunu" olmasına rağmen. Hiçbir dokümantasyon bu platformları hedef olarak belirtmiyor (web yalnızca yerel geliştirme sırasında `flutter run -d chrome` için kullanılmış görünüyor). CI olmadığı için bu platformlar hiç build-doğrulaması almıyor, yani sessizce bozulabilirler.

**Öneri:** Eğer ürün gerçekten yalnızca mobil hedefliyorsa `linux/`, `macos/`, `windows/` klasörlerini kaldırın; `web/` yerel geliştirme kolaylığı için tutulabilir.

### 3.7 pubspec.yaml'da kullanılmayan asset tanımı

`pubspec.yaml`'da tanımlı `assets/videos/` klasörü fiilen boş (sadece `.gitkeep`) ve kodda hiçbir yerden referans edilmiyor — gerçek video (`hero.mp4`) `assets/main/` altında duruyor. Build'i bozmuyor ama düzensiz asset yönetimine işaret ediyor. `assets/online/` ise doğru şekilde kullanılıyor.

**Öneri:** `assets/videos/` girdisini pubspec.yaml'dan kaldırın veya klasörü gerçekten kullanın.

### 3.8 Yerelleştirme (i18n) altyapısı yok

Proje `flutter_localizations`/`intl` paketi kullanmıyor; tüm Türkçe metinler doğrudan widget kodlarına gömülü. Ürün şu an yalnızca Türkiye pazarını hedeflediği için bu makul bir tercih, ancak gelecekte başka bir dile geçiş kademeli değil, tam bir retrofit gerektirecek.

---

## 4. Önceliklendirilmiş Aksiyon Planı

### Hemen (bu hafta — güvenlik açıkları aktif olarak istismar edilebilir durumda)
1. Sabit şifre (`'AutoLoginPass123!'`) auth akışını kaldırın — gerçek şifre veya magic-link/OTP'ye geçin. (§1.1)
2. `online_profiles` UPDATE politikasına `WITH CHECK` ekleyin; `coins`/`rating`/`wins` gibi alanları doğrudan client UPDATE'inden çıkarıp RPC'ye taşıyın. (§1.2)
3. `credit_reward`/`close_competitive_season` fonksiyonlarının production'daki gerçek GRANT/REVOKE durumunu kontrol edin ve kapatın; `credit_reward` içine yetki kontrolü ekleyin. (§1.3)
4. Ranked maç sonuç doğrulamasını sunucu tarafına taşıyın (istemciden gelen "stat" değerine güvenmeyi bırakın). (§1.4)
5. `messages` tablosunun gerçek şema ve RLS politikalarını production'dan çekip migration olarak ekleyin, DELETE/SELECT politikalarını doğrulayın. (§1.6)

### Bu ay
6. `git init` yapın, `.gitignore`'a `.env` ekleyin, scratch/debug dosyalarını (`check_db*.dart`, `test_parse.dart`, `scratch_auth.dart`, `main.dart.bak`, `scripts/*.py`) temizleyin, ilk commit'i atın. (§3.1, §3.4)
7. `merge_offline_progress`'e coins/xp üst sınırı ve kozmetik unlock doğrulaması ekleyin. (§1.5)
8. Tüm "fix_*.sql" dosyalarını düzgün numaralı migration'lara dönüştürün. (§1.7)
9. OAuth giriş akışlarına offline-progress merge kontrolünü ekleyin. (§2.3)
10. README.md'yi projeye özgü içerikle yeniden yazın. (§3.3)

### Orta vadede
11. Kritik servislere (`game_store.dart`, `progress_merge_service.dart`) birim test ekleyin; en azından ana akışlar için widget testleri yazın. (§3.2)
12. Basit bir CI pipeline kurun (`flutter analyze` + `flutter test`, git deposu kurulduktan sonra). (§3.1)
13. Sosyal/arkadaşlık özelliği için repository katmanı ekleyin; büyük ekran dosyalarını (`home_screen.dart`, `settings_screen.dart`) bölün. (§2.2)
14. Tüm `catch` bloklarında tutarlı `diagnostics.record(...)` kullanımı sağlayın. (§2.4)

### Uzun vadede
15. State management için hafif bir çözüme geçin (en azından tutarlı `ChangeNotifier` dinleme paterni).
16. Kullanılmayan platform klasörlerini (`linux/`, `macos/`, `windows/`) temizleyin.
17. Yerelleştirme altyapısı gerekiyorsa erken planlayın (şu an retrofit maliyeti düşükken).
