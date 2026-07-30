import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:futbol_meydani/globals.dart';

class ChatSettingsScreen extends StatefulWidget {
  final String friendId;

  const ChatSettingsScreen({super.key, required this.friendId});

  @override
  State<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends State<ChatSettingsScreen> {
  String? _selectedBackground;
  
  final List<String> _backgroundOptions = [
    'assets/avatars/player_1.png',
    'assets/avatars/player_2.png',
    'assets/avatars/field_1.png',
    'assets/avatars/field_2.png',
  ];

  @override
  void initState() {
    super.initState();
    _selectedBackground = gameStore.prefs.getString('chat_bg_${widget.friendId}');
  }

  Future<void> _saveBackground(String? path) async {
    setState(() {
      _selectedBackground = path;
    });
    
    if (path == null) {
      await gameStore.prefs.remove('chat_bg_${widget.friendId}');
    } else {
      await gameStore.prefs.setString('chat_bg_${widget.friendId}', path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.8),
        elevation: 0,
        title: const Text('Sohbet Ayarları', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: BackButton(onPressed: () => Navigator.pop(context, _selectedBackground)),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sohbet Arka Planı',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Default (No Background) Option
                  GestureDetector(
                    onTap: () => _saveBackground(null),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedBackground == null 
                            ? const Color(0xFF00E676).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedBackground == null 
                              ? const Color(0xFF00E676)
                              : Colors.white.withValues(alpha: 0.1),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFF050505),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text('Varsayılan (Siyah)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (_selectedBackground == null)
                            const Icon(Icons.check_circle, color: Color(0xFF00E676)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Text(
                    'Profil Avatarları (Bulanık)',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _backgroundOptions.length,
                    itemBuilder: (context, index) {
                      final bg = _backgroundOptions[index];
                      final isSelected = _selectedBackground == bg;
                      
                      return GestureDetector(
                        onTap: () => _saveBackground(bg),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00E676) : Colors.white.withValues(alpha: 0.1),
                              width: isSelected ? 3 : 1,
                            ),
                            boxShadow: isSelected 
                                ? [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.3), blurRadius: 10)]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.asset(bg, fit: BoxFit.cover),
                                BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                  child: Container(color: Colors.black.withValues(alpha: 0.3)),
                                ),
                                if (isSelected)
                                  const Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Icon(Icons.check_circle, color: Color(0xFF00E676), size: 28),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
