import 'package:flutter/material.dart';

import 'package:futbol_meydani/constants.dart';
import 'package:futbol_meydani/models/game_data.dart';
import 'package:futbol_meydani/utils/helpers.dart';
import 'package:futbol_meydani/widgets/common_widgets.dart';
import 'package:futbol_meydani/screens/match_screen.dart';
import 'package:futbol_meydani/utils/glass_toast.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.data});
  final GameData data;
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final one = TextEditingController(text: 'Selim');
  final two = TextEditingController(text: 'Mert');
  int rounds = 5;
  @override
  void dispose() {
    one.dispose();
    two.dispose();
    super.dispose();
  }

  void start() {
    final a = one.text.trim(), b = two.text.trim();
    if (a.isEmpty || b.isEmpty || normalize(a) == normalize(b)) {
      GlassToast.show(context, 'İki farklı oyuncu adı yaz.', isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MatchScreen(data: widget.data, names: [a, b], roundCount: rounds),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      title: const Text('Maçı Kur'),
    ),
    body: AppBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Meydanı hazırlayın.',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Oyuncular seçimlerini sırayla ve gizli yapacak.',
              style: TextStyle(color: muted),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: one,
              maxLength: 18,
              decoration: const InputDecoration(
                labelText: 'Oyuncu 1',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: two,
              maxLength: 18,
              decoration: const InputDecoration(
                labelText: 'Oyuncu 2',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tur sayısı',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 Tur')),
                ButtonSegment(value: 5, label: Text('5 Tur')),
                ButtonSegment(value: 7, label: Text('7 Tur')),
              ],
              selected: {rounds},
              onSelectionChanged: (v) => setState(() => rounds = v.first),
            ),
            const SizedBox(height: 34),
            PrimaryButton(
              label: 'Maçı Başlat',
              icon: Icons.arrow_forward,
              onPressed: start,
            ),
          ],
        ),
      ),
    ),
  );
}
