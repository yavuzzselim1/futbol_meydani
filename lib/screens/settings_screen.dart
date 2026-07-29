import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/services/game_store.dart';
import 'package:futbol_meydani/services/supabase_state.dart';
import 'package:futbol_meydani/utils/countries.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

String _formatDisplayPhone(String? rawPhone) {
  if (rawPhone == null || rawPhone.isEmpty) return 'Eklenmedi';
  
  final sortedCountries = List<CountryData>.from(allCountries)..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
  for (final country in sortedCountries) {
    if (rawPhone.startsWith(country.dialCode)) {
      final numberPart = rawPhone.substring(country.dialCode.length).replaceAll(RegExp(r'\D'), '');
      if (numberPart.length == 10) {
        return '${country.dialCode} (${numberPart.substring(0,3)}) ${numberPart.substring(3,6)} ${numberPart.substring(6,10)}';
      }
      return rawPhone;
    }
  }
  return rawPhone;
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text('Ayarlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent,
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            const _SectionTitle(title: 'HESAP VE PROFİL'),
            _MenuTile(
              icon: Icons.person_outline,
              title: 'Hesap Bilgileri',
              subtitle: 'İsim, arkadaş kodu ve detaylar',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AccountSubScreen())),
            ),
            _MenuTile(
              icon: Icons.face_retouching_natural_rounded,
              title: 'Avatar Seçimi',
              subtitle: 'Profilinde görünen avatar',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AvatarSubScreen())),
            ),
            _MenuTile(
              icon: Icons.bar_chart_rounded,
              title: 'Profil İstatistikleri',
              subtitle: 'Oynanan maçlar ve kariyer özeti',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _StatsSubScreen())),
            ),
            _MenuTile(
              icon: Icons.block_rounded,
              title: 'Engellenen Kullanıcılar',
              subtitle: 'İletişimi kestiğin oyuncular',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _BlockedUsersSubScreen())),
            ),

            const _SectionTitle(title: 'OYUN DENEYİMİ'),
            _MenuTile(
              icon: Icons.sports_soccer_rounded,
              title: 'Oyun Ayarları',
              subtitle: 'Zorluk, maç süresi ve deneyim',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _GameplaySubScreen())),
            ),
            _MenuTile(
              icon: Icons.volume_up_outlined,
              title: 'Ses ve Titreşim',
              subtitle: 'Efektler, spiker ve stadyum',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AudioSubScreen())),
            ),

            const _SectionTitle(title: 'GÖRÜNÜM VE ÖZELLEŞTİRME'),
            _MenuTile(
              icon: Icons.palette_outlined,
              title: 'Arayüz ve Temalar',
              subtitle: 'Saha, menü ve top tasarımları',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AppearanceSubScreen())),
            ),

            const _SectionTitle(title: 'SİSTEM VE BAĞLANTI'),
            _MenuTile(
              icon: Icons.wifi_rounded,
              title: 'Bağlantı ve Performans',
              subtitle: 'Ping, FPS ve veri kullanımı',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _SystemSubScreen())),
            ),
            _MenuTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Tanılama Raporu',
              subtitle: 'Sistem logları ve rapor paylaşımı',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _DiagnosticsSubScreen())),
            ),
            _MenuTile(
              icon: Icons.delete_sweep_outlined,
              title: 'Önbelleği Temizle',
              subtitle: 'Yerel cihaz dosyalarını siler',
              onTap: () {
                 GlassToast.show(context, 'Önbellek temizlendi.', isError: false);
              },
            ),

            const _SectionTitle(title: 'GÜVENLİK VE TEHLİKELİ BÖLGE'),
            _MenuTile(
              icon: Icons.lock_outline_rounded,
              title: 'Şifre Değiştir',
              onTap: () {
                GlassToast.show(context, 'Şifre değiştirme sayfası yakında!', isError: true);
              },
            ),
            _MenuTile(
              icon: Icons.security_rounded,
              title: 'İki Adımlı Doğrulama (2FA)',
              onTap: () {
                 GlassToast.show(context, 'İki adımlı doğrulama aktif değil.', isError: true);
              },
            ),
            _MenuTile(
              icon: Icons.warning_amber_rounded,
              title: 'Tüm Verileri Sıfırla',
              textColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              onTap: _confirmReset,
            ),
            _MenuTile(
              icon: Icons.person_off_outlined,
              title: 'Hesabı Sil',
              textColor: Colors.redAccent,
              iconColor: Colors.redAccent,
              onTap: () {
                GlassToast.show(context, 'Hesap silme işlemi yönetici izni gerektirir.', isError: true);
              },
            ),

            const _SectionTitle(title: 'HAKKINDA'),
            _MenuTile(
              icon: Icons.info_outline_rounded,
              title: 'Sürüm Notları',
              subtitle: 'v2.1.4',
              onTap: () {},
            ),
            _MenuTile(
              icon: Icons.policy_outlined,
              title: 'Gizlilik Politikası',
              onTap: () {},
            ),
            _MenuTile(
              icon: Icons.gavel_rounded,
              title: 'Kullanım Koşulları',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Tüm Verileri Sıfırla', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tüm ilerleme, mağaza alışverişleri, rozetler ve ayarlar sıfırlanacak. Bu işlem geri alınamaz!',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await gameStore.resetAllData();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                GlassToast.show(context, 'Tüm veriler sıfırlandı.', isError: true);
              }
            },
            child: const Text('Sıfırla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? textColor;
  final Color? iconColor;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white10,
      highlightColor: Colors.white10,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? Colors.white70, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ]
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!, style: const TextStyle(color: Colors.white38, fontSize: 12)) : null,
        value: value,
        activeColor: const Color(0xFF71F39A),
        onChanged: (v) {
          gameStore.tap(GameSound.select);
          onChanged(v);
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------
// SUB PAGES
// ----------------------------------------------------------------------

class _SubPageScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  const _SubPageScaffold({required this.title, required this.children, this.actions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: actions,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + MediaQuery.of(context).padding.bottom),
        children: children,
      ),
    );
  }
}

class _AccountSubScreen extends StatefulWidget {
  const _AccountSubScreen();
  @override
  State<_AccountSubScreen> createState() => _AccountSubScreenState();
}

class _AccountSubScreenState extends State<_AccountSubScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Hesap Bilgileri',
        actions: const [],
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _AvatarSubScreen())),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Builder(
                      builder: (ctx) {
                        final avatarData = GameStore.avatars.firstWhere((a) => a['id'] == gameStore.currentAvatar, orElse: () => GameStore.avatars.first);
                        final IconData avatarIcon = avatarData['icon'] as IconData;
                        final Color avatarColor = avatarData['color'] as Color;

                        return Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                            border: Border.all(color: avatarColor.withValues(alpha: 0.5), width: 2),
                            boxShadow: [
                              BoxShadow(color: avatarColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -5),
                            ],
                          ),
                          child: Center(
                            child: Icon(avatarIcon, color: avatarColor, size: 50),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF71F39A),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 3),
                        ),
                        child: const Icon(Icons.edit_rounded, color: Colors.black, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const _SectionTitle(title: 'OYUNCU ADI'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: TextField(
              controller: TextEditingController(text: gameStore.playerName),
              readOnly: true,
              onTap: () async {
                final success = await showModalBottomSheet<bool>(
                  context: context,
                  backgroundColor: const Color(0xFF111111),
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                  builder: (ctx) => const _NameChangeBottomSheet(),
                );
                if (success == true && mounted) setState(() {});
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Adını gir...',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: const Icon(Icons.edit, color: Colors.white54, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'BAĞLI HESAPLAR VE İLETİŞİM'),
          _MenuTile(
            icon: Icons.email_outlined,
            title: 'E-posta Adresi',
            subtitle: SupabaseState.client?.auth.currentUser?.email ?? 'Eklenmedi',
            onTap: () async {
              final currentEmail = SupabaseState.client?.auth.currentUser?.email;
              if (currentEmail == null) return;
              
              final success = await showModalBottomSheet<bool>(
                context: context,
                backgroundColor: const Color(0xFF111111),
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (ctx) => _EmailChangeBottomSheet(currentEmail: currentEmail),
              );

              if (success == true && mounted) {
                setState(() {});
              }
            },
          ),
          _MenuTile(
            icon: Icons.phone_android_rounded,
            title: 'Telefon Numarası',
            subtitle: _formatDisplayPhone(SupabaseState.client?.auth.currentUser?.userMetadata?['phone'] as String?),
            onTap: () async {
              final success = await showModalBottomSheet<bool>(
                context: context,
                backgroundColor: const Color(0xFF111111),
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                builder: (ctx) => const _PhoneChangeBottomSheet(),
              );
              if (success == true && mounted) {
                setState(() {});
              }
            },
          ),
          _MenuTile(
            icon: Icons.apple,
            title: 'Apple ile Giriş Yapıldı',
            subtitle: 'Bağlantıyı Kes',
            textColor: Colors.white70,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _AvatarSubScreen extends StatelessWidget {
  const _AvatarSubScreen();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Avatar Seçimi',
        children: [
          const _SectionTitle(title: 'SAHİP OLUNAN AVATARLAR'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: GameStore.avatars.map((a) {
              final id = a['id'] as String;
              final bool owned = gameStore.unlockedAvatars.contains(id);
              final bool active = gameStore.currentAvatar == id;
              if (!owned && id != 'default') return const SizedBox.shrink();

              return GestureDetector(
                onTap: owned ? () => gameStore.setCurrentAvatar(id) : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF71F39A).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: active ? const Color(0xFF71F39A) : Colors.transparent, width: 2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a['icon'] as IconData?, color: a['color'] as Color?, size: 40),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Diğer avatarları Mağaza sayfasından MP (Meydan Parası) ile satın alabilirsin.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSubScreen extends StatelessWidget {
  const _StatsSubScreen();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Profil İstatistikleri',
        children: [
          const _SectionTitle(title: 'KARİYER ÖZETİ'),
          _StatRow(label: 'Oynanan Maç', value: '${gameStore.matches}'),
          _StatRow(label: 'Kazanılan Maç', value: '${gameStore.wins.length}'),
          _StatRow(label: 'Kupa Sayısı', value: '${gameStore.trophies} 🏆'),
          _StatRow(label: 'Meydan Parası (MP)', value: '${gameStore.coins} 💰'),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'SON DAKİKA MODU'),
          _StatRow(label: 'En Yüksek Skor', value: '${gameStore.lastMinuteBest}'),
          _StatRow(label: 'En Fazla Gol', value: '${gameStore.lastMinuteGoals}'),
          _StatRow(label: 'En İyi Seri', value: '${gameStore.lastMinuteBestStreak}'),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 15)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _BlockedUsersSubScreen extends StatelessWidget {
  const _BlockedUsersSubScreen();
  @override
  Widget build(BuildContext context) {
    return const _SubPageScaffold(
      title: 'Engellenen Kullanıcılar',
      children: [
        Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Engellenen kullanıcı bulunmuyor.',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ),
      ],
    );
  }
}

class _GameplaySubScreen extends StatelessWidget {
  const _GameplaySubScreen();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Oyun Ayarları',
        children: [
          const _SectionTitle(title: 'OYUN İÇİ ETKİLEŞİM'),
          _SwitchTile(
            title: 'Animasyonlar',
            subtitle: 'Kart açılışı ve kazanan gösterisi efektleri',
            value: gameStore.animations,
            onChanged: (v) => gameStore.setOption('animations', v),
          ),
          _SwitchTile(
            title: 'Gol Sevinci Gösterimi',
            subtitle: 'Kritik anlarda özel animasyonlar gösterilir',
            value: gameStore.goalCelebration,
            onChanged: (v) => gameStore.setOption('goalCelebration', v),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'MAÇ SÜRESİ'),
          _SegmentControl(
            options: const {'3': '3 Dakika', '5': '5 Dakika', '10': '10 Dakika'},
            currentValue: gameStore.matchDuration.toString(),
            onChanged: (v) => gameStore.setOption('matchDuration', int.parse(v)),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'YAPAY ZEKA ZORLUĞU (OFFLINE)'),
          _SegmentControl(
            options: const {'0': 'Kolay', '1': 'Normal', '2': 'Efsanevi'},
            currentValue: gameStore.difficulty.toString(),
            onChanged: (v) => gameStore.setOption('difficulty', int.parse(v)),
          ),
        ],
      ),
    );
  }
}

class _AudioSubScreen extends StatelessWidget {
  const _AudioSubScreen();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Ses ve Titreşim',
        children: [
          const _SectionTitle(title: 'GENEL'),
          _SwitchTile(
            title: 'Ses Efektleri',
            subtitle: 'Seçim, kart ve sonuç sesleri',
            value: gameStore.sound,
            onChanged: (v) => gameStore.setOption('sound', v),
          ),
          _SwitchTile(
            title: 'Titreşim',
            subtitle: 'Seçim ve kazanma dokunsal geri bildirimi',
            value: gameStore.vibration,
            onChanged: (v) => gameStore.setOption('vibration', v),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'OYUN İÇİ AMBİYANS'),
          _SwitchTile(
            title: 'Spiker Sesleri',
            subtitle: 'Goller ve kritik anlarda spiker yorumları',
            value: gameStore.commentator,
            onChanged: (v) => gameStore.setOption('commentator', v),
          ),
          _SwitchTile(
            title: 'Stadyum Ambiyans Sesleri',
            subtitle: 'Taraftar tezahüratları ve saha sesleri',
            value: gameStore.stadiumSounds,
            onChanged: (v) => gameStore.setOption('stadiumSounds', v),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSubScreen extends StatelessWidget {
  const _AppearanceSubScreen();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Arayüz ve Temalar',
        children: [
          const _SectionTitle(title: 'MENÜ TEMASI'),
          _SegmentControl(
            options: const {'dark': 'Koyu', 'light': 'Açık', 'system': 'Sistem'},
            currentValue: gameStore.menuTheme,
            onChanged: (v) => gameStore.setOption('menuTheme', v),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'TOP MODELİ'),
          _SegmentControl(
            options: const {'classic': 'Klasik', 'modern': 'Modern', 'retro': 'Retro'},
            currentValue: gameStore.ballModel,
            onChanged: (v) => gameStore.setOption('ballModel', v),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'HUD (ARAYÜZ) BOYUTU'),
          Slider(
            value: gameStore.hudSize,
            min: 0.8,
            max: 1.2,
            divisions: 4,
            activeColor: const Color(0xFF71F39A),
            inactiveColor: Colors.white24,
            onChanged: (v) => gameStore.setOption('hudSize', v),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'SAHA TEMASI (AKTİF)'),
          ...GameStore.themes.map((t) {
            final id = t['id'] as String;
            final owned = gameStore.unlockedThemes.contains(id);
            final active = gameStore.activeTheme == id;
            if (!owned && id != 'default') return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: InkWell(
                onTap: owned ? () => gameStore.setActiveTheme(id) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF71F39A).withValues(alpha: 0.1) : Colors.transparent,
                    border: Border.all(color: active ? const Color(0xFF71F39A) : Colors.white10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(t['icon'] as IconData, color: t['color'] as Color),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(t['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      if (active) const Icon(Icons.check_circle_rounded, color: const Color(0xFF71F39A)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _SystemSubScreen extends StatelessWidget {
  const _SystemSubScreen();
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Bağlantı ve Performans',
        children: [
          const _SectionTitle(title: 'BAĞLANTI'),
          _SwitchTile(
            title: 'Veri Tasarrufu Modu',
            subtitle: 'Mobil verideyken daha az bant genişliği kullanır',
            value: gameStore.dataSaver,
            onChanged: (v) => gameStore.setOption('dataSaver', v),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'PERFORMANS'),
          _SwitchTile(
            title: 'Oyun İçi Ping ve FPS',
            subtitle: 'Ekranın köşesinde ağ gecikmesini ve kare hızını gösterir',
            value: gameStore.showPingFps,
            onChanged: (v) => gameStore.setOption('showPingFps', v),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsSubScreen extends StatelessWidget {
  const _DiagnosticsSubScreen();

  @override
  Widget build(BuildContext context) {
    return _SubPageScaffold(
      title: 'Tanılama Raporu',
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Text(
            'Online bağlantı ve oyun akışı olaylarını gösterir. API anahtarı, oyuncu adı ve kadro seçimleri rapora eklenmez. Hata bildirimlerinde bu raporu kullanabilirsiniz.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FilledButton.icon(
            onPressed: () {
              final report = diagnostics.report();
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF111111),
                  title: const Text('Rapor', style: TextStyle(color: Colors.white)),
                  content: SizedBox(
                    width: 520,
                    child: SingleChildScrollView(
                      child: SelectableText(report, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70)),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Kapat', style: TextStyle(color: Colors.white70))),
                    FilledButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: report));
                        if (dialogContext.mounted) GlassToast.show(context, 'Kopyalandı.', isError: false);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Kopyala'),
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF71F39A), foregroundColor: Colors.black),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.receipt_long_rounded),
            label: const Text('Raporu Görüntüle'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FilledButton.icon(
            onPressed: () async {
              await diagnostics.clear();
              if (context.mounted) GlassToast.show(context, 'Kayıtlar temizlendi.', isError: false);
            },
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Cihaz Kayıtlarını Temizle'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white10,
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        )
      ],
    );
  }
}

// ----------------------------------------------------------------------
// HELPER COMPONENTS
// ----------------------------------------------------------------------

class _SegmentControl extends StatelessWidget {
  final Map<String, String> options;
  final String currentValue;
  final ValueChanged<String> onChanged;

  const _SegmentControl({required this.options, required this.currentValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: options.entries.map((e) {
            final active = e.key == currentValue;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  gameStore.tap(GameSound.select);
                  onChanged(e.key);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF71F39A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    e.value,
                    style: TextStyle(
                      color: active ? Colors.black : Colors.white70,
                      fontWeight: active ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmailChangeBottomSheet extends StatefulWidget {
  final String currentEmail;
  const _EmailChangeBottomSheet({required this.currentEmail});
  @override
  State<_EmailChangeBottomSheet> createState() => _EmailChangeBottomSheetState();
}

class _EmailChangeBottomSheetState extends State<_EmailChangeBottomSheet> {
  int _stage = 0; // 0: Start, 1: Old OTP, 2: New Email, 3: New OTP
  bool _isLoading = false;
  String _newEmail = '';
  String? _errorMessage;

  Timer? _resendTimer;
  int _remainingSeconds = 0;

  final _otpController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _resendTimer?.cancel();
    setState(() => _remainingSeconds = 180);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _sendOldEmailOtp() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await SupabaseState.client?.auth.signInWithOtp(email: widget.currentEmail);
      setState(() {
        _isLoading = false;
        _stage = 1;
        _otpController.clear();
      });
      _startTimer();
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      String msg = 'Bir hata oluştu.';
      if (e.message.contains('For security purposes')) {
        final match = RegExp(r'after (\d+) seconds').firstMatch(e.message);
        if (match != null) {
          msg = 'Güvenlik nedeniyle tekrar denemek için ${match.group(1)} saniye bekleyin.';
        } else {
          msg = 'Güvenlik nedeniyle lütfen biraz bekleyip tekrar deneyin.';
        }
      } else {
        msg = e.message;
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Hata: ${e.toString()}';
      });
    }
  }

  Future<void> _verifyOldEmailOtp() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await SupabaseState.client?.auth.verifyOTP(
        email: widget.currentEmail,
        token: _otpController.text.trim(),
        type: OtpType.magiclink,
      );
      setState(() {
        _isLoading = false;
        _stage = 2;
        _emailController.clear();
      });
      _resendTimer?.cancel();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Girdiğiniz onay kodu geçersiz veya süresi dolmuş.';
      });
    }
  }

  Future<void> _sendNewEmailOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) return;

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await SupabaseState.client?.auth.updateUser(UserAttributes(email: email));
      setState(() {
        _isLoading = false;
        _newEmail = email;
        _stage = 3;
        _otpController.clear();
      });
      _startTimer();
    } on AuthException catch (e) {
      setState(() => _isLoading = false);
      String msg = 'Bir hata oluştu.';
      if (e.message.contains('already been registered')) {
        msg = 'Bu e-posta adresi kullanımda. Lütfen başka bir e-posta deneyin.';
      } else if (e.message.contains('rate limit') || e.message.contains('Too many requests')) {
        msg = 'Çok fazla deneme yaptınız, lütfen daha sonra tekrar deneyin.';
      } else if (e.message.contains('For security purposes')) {
        final match = RegExp(r'after (\d+) seconds').firstMatch(e.message);
        if (match != null) {
          msg = 'Güvenlik nedeniyle tekrar denemek için ${match.group(1)} saniye bekleyin.';
        } else {
          msg = 'Güvenlik nedeniyle lütfen biraz bekleyip tekrar deneyin.';
        }
      } else {
        msg = e.message;
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Hata: ${e.toString()}';
      });
    }
  }

  Future<void> _verifyNewEmailOtp() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await SupabaseState.client?.auth.verifyOTP(
        email: _newEmail,
        token: _otpController.text.trim(),
        type: OtpType.emailChange,
      );
      setState(() => _isLoading = false);
      _resendTimer?.cancel();
      if (mounted) {
        GlassToast.show(context, 'E-posta başarıyla güncellendi.', isError: false);
        Navigator.pop(context, true); // true indicates success
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Girdiğiniz onay kodu geçersiz veya süresi dolmuş.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('E-posta Değiştir', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 24),
          if (_stage == 0) ...[
            TextField(
              controller: TextEditingController(text: widget.currentEmail),
              enabled: false,
              style: const TextStyle(color: Colors.white54),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _sendOldEmailOtp,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF71F39A), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : const Text('Değiştir', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ] else if (_stage == 1) ...[
            const Text('Mevcut e-postanıza gönderilen 6 haneli kodu girin:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('old_otp'),
              autofocus: true,
              controller: _otpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _clearError(),
              decoration: InputDecoration(
                hintText: 'Onay Kodu',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _verifyOldEmailOtp,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF71F39A), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : const Text('Doğrula', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _remainingSeconds == 0 ? _sendOldEmailOtp : null,
              child: Text(
                _remainingSeconds > 0 ? 'Tekrar Gönder ($_remainingSeconds)' : 'Kodu Tekrar Gönder',
                style: TextStyle(
                  color: _remainingSeconds == 0 ? const Color(0xFF71F39A) : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else if (_stage == 2) ...[
            const Text('Yeni e-posta adresinizi girin:', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('new_email'),
              autofocus: true,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _clearError(),
              decoration: InputDecoration(
                hintText: 'yeni@email.com',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _sendNewEmailOtp,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF71F39A), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : const Text('Devam Et', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ] else if (_stage == 3) ...[
            Text('$_newEmail adresine gönderilen kodu girin:', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('new_otp'),
              autofocus: true,
              controller: _otpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => _clearError(),
              decoration: InputDecoration(
                hintText: 'Onay Kodu',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _verifyNewEmailOtp,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF71F39A), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : const Text('Onayla', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _remainingSeconds == 0 ? _sendNewEmailOtp : null,
              child: Text(
                _remainingSeconds > 0 ? 'Tekrar Gönder ($_remainingSeconds)' : 'Kodu Tekrar Gönder',
                style: TextStyle(
                  color: _remainingSeconds == 0 ? const Color(0xFF71F39A) : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PhoneChangeBottomSheet extends StatefulWidget {
  const _PhoneChangeBottomSheet();
  @override
  State<_PhoneChangeBottomSheet> createState() => _PhoneChangeBottomSheetState();
}

class _PhoneChangeBottomSheetState extends State<_PhoneChangeBottomSheet> {
  CountryData _selectedCountry = allCountries.first;
  bool _isSelectingCountry = false;
  final _phoneController = TextEditingController();
  final _searchController = TextEditingController();
  List<CountryData> _filteredCountries = allCountries;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    final savedPhone = SupabaseState.client?.auth.currentUser?.userMetadata?['phone'] as String?;
    if (savedPhone != null && savedPhone.isNotEmpty) {
      _isSaved = true;
      final sortedCountries = List<CountryData>.from(allCountries)..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
      for (final country in sortedCountries) {
        if (savedPhone.startsWith(country.dialCode)) {
          _selectedCountry = country;
          final numberPart = savedPhone.substring(country.dialCode.length).replaceAll(RegExp(r'\D'), '');
          
          final buffer = StringBuffer();
          for (int i = 0; i < numberPart.length; i++) {
            if (i == 0) buffer.write('(');
            buffer.write(numberPart[i]);
            if (i == 2) buffer.write(') ');
            if (i == 5) buffer.write(' ');
          }
          _phoneController.text = buffer.toString();
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    if (query.isEmpty) {
      setState(() => _filteredCountries = allCountries);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredCountries = allCountries.where((c) => c.name.toLowerCase().contains(q) || c.dialCode.contains(q)).toList();
    });
  }

  Future<void> _savePhone() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) {
      setState(() => _errorMessage = 'Lütfen telefon numaranızı girin.');
      return;
    }
    if (phone.length < 10) {
      setState(() => _errorMessage = 'Lütfen 10 haneli telefon numaranızı eksiksiz girin.');
      return;
    }

    final fullNumber = '${_selectedCountry.dialCode}$phone';

    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await SupabaseState.client?.auth.updateUser(UserAttributes(data: {'phone': fullNumber}));
      if (mounted) {
        GlassToast.show(context, 'Telefon numarası güncellendi.', isError: false);
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        String msg = 'Bir hata oluştu.';
        if (e.message.contains('already been registered')) {
          msg = 'Bu telefon numarası kullanımda. Lütfen başka bir numara deneyin.';
        } else if (e.message.contains('rate limit') || e.message.contains('Too many requests')) {
          msg = 'Çok fazla deneme yaptınız, lütfen daha sonra tekrar deneyin.';
        } else if (e.message.contains('invalid phone')) {
          msg = 'Geçersiz telefon numarası formatı.';
        } else if (e.message.contains('Twilio') || e.message.contains('SMS')) {
          msg = 'Sunucu tarafında SMS sağlayıcısı ayarlanmamış olabilir. Lütfen destek ile iletişime geçin.';
        } else {
          msg = e.message;
        }
        _errorMessage = msg;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Hata: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_isSelectingCountry ? 'Ülke Seç' : 'Telefon Numarası', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () {
                FocusScope.of(context).unfocus();
                if (_isSelectingCountry) {
                  setState(() { _isSelectingCountry = false; _searchController.clear(); _filteredCountries = allCountries; });
                } else {
                  Navigator.pop(context);
                }
              }),
            ],
          ),
          const SizedBox(height: 24),
          if (_isSelectingCountry) ...[
            TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: _filterCountries,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ülke veya kod ara...',
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ListView.builder(
                itemCount: _filteredCountries.length,
                itemBuilder: (context, index) {
                  final country = _filteredCountries[index];
                  return ListTile(
                    leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(country.name, style: const TextStyle(color: Colors.white)),
                    trailing: Text(country.dialCode, style: const TextStyle(color: Colors.white54)),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _selectedCountry = country;
                        _isSelectingCountry = false;
                        _searchController.clear();
                        _filteredCountries = allCountries;
                      });
                    },
                  );
                },
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: () => setState(() => _isSelectingCountry = true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(_selectedCountry.flag, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text('${_selectedCountry.name} (${_selectedCountry.dialCode})', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [_PhoneInputFormatter()],
              autofocus: false,
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
              style: const TextStyle(color: Colors.white, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: '555 123 45 67',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 14, right: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${_selectedCountry.dialCode}', style: const TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 2)),
                    ],
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: _errorMessage != null ? const BorderSide(color: Colors.redAccent, width: 1.5) : BorderSide.none
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: _errorMessage != null ? const BorderSide(color: Colors.redAccent, width: 1.5) : BorderSide.none
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), 
                  borderSide: _errorMessage != null ? const BorderSide(color: Colors.redAccent, width: 1.5) : BorderSide.none
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _savePhone,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF71F39A), padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                : Text(_isSaved ? 'Değiştir' : 'Kaydet', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) return oldValue;
    
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 0) buffer.write('(');
      buffer.write(digits[i]);
      if (i == 2) buffer.write(') ');
      if (i == 5) buffer.write(' ');
    }
    
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _NameChangeBottomSheet extends StatefulWidget {
  const _NameChangeBottomSheet();

  @override
  State<_NameChangeBottomSheet> createState() => _NameChangeBottomSheetState();
}

class _NameChangeBottomSheetState extends State<_NameChangeBottomSheet> {
  late TextEditingController _nameController;
  Timer? _debounce;
  bool _isChecking = false;
  bool _isAvailable = true;
  String _lastCheckedName = '';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: gameStore.playerName);
    _lastCheckedName = gameStore.playerName;
    _nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final name = _nameController.text.trim();
    if (name == _lastCheckedName || name == gameStore.playerName) {
      setState(() {
        _isChecking = false;
        _isAvailable = true;
      });
      return;
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() => _isChecking = true);

    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final client = SupabaseState.client;
      if (client == null || name.isEmpty) {
        if (mounted) setState(() { _isChecking = false; _isAvailable = false; });
        return;
      }

      try {
        final res = await client
            .from('online_profiles')
            .select('id')
            .eq('display_name', name)
            .limit(1)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _isChecking = false;
            _isAvailable = res == null;
            _lastCheckedName = name;
          });
        }
      } catch (e) {
        if (mounted) setState(() { _isChecking = false; _isAvailable = false; });
      }
    });
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name == gameStore.playerName) return;

    if (gameStore.playerName.isNotEmpty && gameStore.coins < 500) {
      GlassToast.show(context, 'Yeterli Coin bulunmuyor (500 gerekli).', isError: true);
      return;
    }

    if (gameStore.playerName.isNotEmpty) {
      final confirm = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF111111),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          bool isPaying = false;
          bool isDone = false;
          final GlobalKey buttonKey = GlobalKey();
          return StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 48),
                    const SizedBox(height: 16),
                    Text('İsminiz "$name" olarak değiştirilecek. Onaylıyor musunuz?', 
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: (isPaying || isDone) ? null : () => Navigator.pop(ctx, false),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            key: buttonKey,
                            onPressed: (isPaying || isDone) ? null : () async {
                              setModalState(() => isPaying = true);
                              
                              await Future.delayed(const Duration(seconds: 2));
                              
                              setModalState(() {
                                isPaying = false;
                                isDone = true;
                              });

                              final RenderBox? box = buttonKey.currentContext?.findRenderObject() as RenderBox?;
                              final offset = box?.localToGlobal(box.size.center(Offset.zero));
                              _showCoinSplash(context, origin: offset);
                              
                              await Future.delayed(const Duration(milliseconds: 1500));
                              if (context.mounted) Navigator.pop(ctx, true);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF71F39A), 
                              padding: const EdgeInsets.symmetric(vertical: 16)
                            ),
                            child: isPaying 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                : isDone
                                    ? const Icon(Icons.check, color: Colors.black)
                                    : const Text('500 MP Öde', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      );

      if (confirm != true) return;
    }

    if (name.isNotEmpty) {
      final bool wasChangingName = gameStore.playerName.isNotEmpty;
      gameStore.savePlayerName(name);
      if (wasChangingName) {
        GlassToast.show(context, 'Adın güncellendi. 500 MP tahsil edildi.', isError: false);
      } else {
        GlassToast.show(context, 'Adın güncellendi.', isError: false);
      }
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Oyuncu Adı',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Adını gir...',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              suffixIcon: _isChecking
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (_nameController.text.trim() != gameStore.playerName && _nameController.text.trim().isNotEmpty && !_isChecking)
                Text(
                  _isAvailable ? '✅ Bu kullanıcı adı alınabilir.' : '❌ Bu kullanıcı adı alınamaz.',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isAvailable ? const Color(0xFF71F39A) : Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              const Text(
                'İsim değiştirme bedeli: 500 Coin',
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: (_isAvailable && !_isChecking && _nameController.text.trim() != gameStore.playerName) ? _saveName : null,
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF71F39A), padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(gameStore.playerName.isEmpty ? 'Kaydet' : 'Değiştir', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

void _showCoinSplash(BuildContext context, {Offset? origin}) {
  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => CoinScatterAnimation(
      origin: origin,
      onComplete: () {
        overlayEntry.remove();
      },
    ),
  );
  Overlay.of(context).insert(overlayEntry);
}

class CoinScatterAnimation extends StatefulWidget {
  final VoidCallback onComplete;
  final Offset? origin;
  const CoinScatterAnimation({super.key, required this.onComplete, this.origin});

  @override
  State<CoinScatterAnimation> createState() => _CoinScatterAnimationState();
}

class _CoinScatterAnimationState extends State<CoinScatterAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final int coinCount = 30;
  final List<_CoinParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    
    for (int i = 0; i < coinCount; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = _random.nextDouble() * 400 + 200; // pixels per second
      _particles.add(_CoinParticle(
        angle: angle,
        speed: speed,
        size: _random.nextDouble() * 20 + 15,
        rotationSpeed: _random.nextDouble() * 4 - 2,
      ));
    }

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final opacity = progress > 0.7 ? (1.0 - progress) / 0.3 : 1.0;
          
          return Stack(
            children: _particles.map((p) {
              final x = math.cos(p.angle) * p.speed * progress;
              final y = math.sin(p.angle) * p.speed * progress + (progress * progress * 800); // gravity effect
              
              final startX = widget.origin?.dx ?? MediaQuery.of(context).size.width / 2;
              final startY = widget.origin?.dy ?? MediaQuery.of(context).size.height / 2;

              return Positioned(
                left: startX + x - p.size / 2,
                top: startY + y - p.size / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.rotate(
                    angle: progress * 10 * p.rotationSpeed,
                    child: Icon(Icons.monetization_on, color: Colors.amber, size: p.size),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _CoinParticle {
  final double angle;
  final double speed;
  final double size;
  final double rotationSpeed;

  _CoinParticle({required this.angle, required this.speed, required this.size, required this.rotationSpeed});
}
