import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/globals.dart';
import 'package:futbol_meydani/services/game_store.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
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
  const _SubPageScaffold({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0, scrolledUnderElevation: 0, surfaceTintColor: Colors.transparent,
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
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
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: gameStore.playerName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: gameStore,
      builder: (_, _) => _SubPageScaffold(
        title: 'Hesap Bilgileri',
        children: [
          const _SectionTitle(title: 'OYUNCU ADI'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Adını gir...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () {
                    final name = _nameController.text.trim();
                    if (name.isNotEmpty) {
                      gameStore.savePlayerName(name);
                      GlassToast.show(context, 'Adın güncellendi.', isError: false);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF71F39A),
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _SectionTitle(title: 'ARKADAŞ KODU'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint_rounded, color: Colors.white54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      gameStore.friendCode,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white54),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: gameStore.friendCode));
                      if (context.mounted) GlassToast.show(context, 'Kod kopyalandı!', isError: false);
                    },
                  )
                ],
              ),
            ),
          )
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
