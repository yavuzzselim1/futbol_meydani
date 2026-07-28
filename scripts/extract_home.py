import os
import re

main_path = r"c:\Users\ydursun\Desktop\futbol_meydani\lib\main.dart"
home_path = r"c:\Users\ydursun\Desktop\futbol_meydani\lib\screens\home_screen.dart"
new_main_path = r"c:\Users\ydursun\Desktop\futbol_meydani\lib\new_main.dart"

with open(main_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Helper to extract a class and its body
def extract_class(class_name, text):
    # Regex to find the start of the class
    pattern = r"^(class\s+" + class_name + r"\b.*?{)"
    match = re.search(pattern, text, re.MULTILINE | re.DOTALL)
    if not match:
        return ""
    start_index = match.start()
    
    # We now count braces to find the end
    brace_count = 0
    in_class = False
    for i in range(start_index, len(text)):
        if text[i] == '{':
            if not in_class:
                in_class = True
            brace_count += 1
        elif text[i] == '}':
            brace_count -= 1
            if in_class and brace_count == 0:
                # end of class
                return text[start_index:i+1]
    return ""

# Classes for home screen
home_classes = [
    'AppDrawerWrapper', 'AppDrawerWrapperState', 'HomeScreen', 'HomeAtmosphere', 
    'HomeAtmospherePainter', 'MenuSidebar', '_SidebarItem', 'ModeSelectionScreen', 
    'VideoBackground', '_VideoBackgroundState', 'ZoomOutAnimator', '_ZoomOutAnimatorState', 
    'PulsingRewardSlot', '_PulsingRewardSlotState', 'HeroContentAnimator', '_HeroContentAnimatorState', 
    'ArenaHero', 'ArenaPainter', 'GameModeCard', 'StadiumHero', 'PitchPainter', 'ModeCard', 
    'StatPanel', 'MiniStat'
]

home_code = """import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

import '../globals.dart';
import '../constants.dart';
import '../models/game_data.dart';
import '../online/supabase_online_game.dart';
import '../widgets/common_widgets.dart';

// Other screens imported
import 'last_minute_screens.dart';
import 'setup_screen.dart';
import 'squad_challenge_screen.dart';
import 'online_screens.dart';
import 'profile_screen.dart';
import 'daily_challenge_screen.dart';
import 'settings_screen.dart';
import '../widgets/squad_pitch.dart';

"""

for c in home_classes:
    code = extract_class(c, content)
    home_code += code + "\n\n"

with open(home_path, 'w', encoding='utf-8') as f:
    f.write(home_code)

# Now we write the new main.dart
new_main_code = """import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'online/supabase_online_game.dart';
import 'globals.dart';
import 'constants.dart';
import 'screens/home_screen.dart';
import 'models/game_data.dart';
import 'models/multi_league.dart';
import 'widgets/common_widgets.dart';

"""

main_classes = [
    'FutbolMeydaniApp', 'DataLoader', 'BrandedSplash', '_BrandedSplashState', 'LogoRevealClipper'
]

# We need the main() function too
main_func_match = re.search(r"^Future<void> main\(\) async {.*?\n}", content, re.MULTILINE | re.DOTALL)
def extract_func(func_name, text):
    pattern = r"^Future<void> " + func_name + r"\(\) async {"
    match = re.search(pattern, text, re.MULTILINE)
    if not match: return ""
    start_index = match.start()
    brace_count = 0
    in_func = False
    for i in range(start_index, len(text)):
        if text[i] == '{':
            if not in_func: in_func = True
            brace_count += 1
        elif text[i] == '}':
            brace_count -= 1
            if in_func and brace_count == 0:
                return text[start_index:i+1]
    return ""

new_main_code += extract_func("main", content) + "\n\n"

for c in main_classes:
    code = extract_class(c, content)
    new_main_code += code + "\n\n"

with open(new_main_path, 'w', encoding='utf-8') as f:
    f.write(new_main_code)

print("Created home_screen.dart and new_main.dart successfully!")
