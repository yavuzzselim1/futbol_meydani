import os
import re

lib_dir = r"c:\Users\ydursun\Desktop\futbol_meydani\lib"

# Fix main.dart
main_file = os.path.join(lib_dir, "main.dart")
with open(main_file, "r", encoding="utf-8") as f:
    main_content = f.read()
main_content = main_content.replace("ErrorView('${snapshot.error}')", "ErrorView(message: '${snapshot.error}')")
with open(main_file, "w", encoding="utf-8") as f:
    f.write(main_content)

# Fix daily_challenge_screen.dart
daily = os.path.join(lib_dir, "screens", "daily_challenge_screen.dart")
with open(daily, "r", encoding="utf-8") as f:
    daily_content = f.read()
if "import 'match_screen.dart';" not in daily_content:
    daily_content = daily_content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'match_screen.dart';")
with open(daily, "w", encoding="utf-8") as f:
    f.write(daily_content)

# Fix online_screens.dart
online = os.path.join(lib_dir, "screens", "online_screens.dart")
with open(online, "r", encoding="utf-8") as f:
    online_content = f.read()
if "import '../models/multi_league.dart';" not in online_content:
    online_content = online_content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../models/multi_league.dart';")

# Fix line 767 in online_screens.dart (Expected to find ')')
# Let's see what's wrong with line 767. We will just use regex to fix it or print it first.
# Wait, let's print line 767.
lines = online_content.split('\n')
if len(lines) >= 767:
    # We will print it below.
    pass

with open(online, "w", encoding="utf-8") as f:
    f.write(online_content)

# Fix squad_challenge_screen.dart
squad = os.path.join(lib_dir, "screens", "squad_challenge_screen.dart")
with open(squad, "r", encoding="utf-8") as f:
    squad_content = f.read()
if "import '../models/multi_league.dart';" not in squad_content:
    squad_content = squad_content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport '../models/multi_league.dart';")
with open(squad, "w", encoding="utf-8") as f:
    f.write(squad_content)

# Fix setup_screen.dart (Remove duplicate Formation class)
setup = os.path.join(lib_dir, "screens", "setup_screen.dart")
with open(setup, "r", encoding="utf-8") as f:
    setup_content = f.read()
# Remove class Formation { ... }
# Simple brace matching or regex
pattern = r"class Formation\s*\{.*?\}"
setup_content = re.sub(r"class Formation\s*\{[^}]*\}", "", setup_content, flags=re.MULTILINE|re.DOTALL)
with open(setup, "w", encoding="utf-8") as f:
    f.write(setup_content)

# Fix home_screen.dart (HowToRow issue)
home = os.path.join(lib_dir, "screens", "home_screen.dart")
with open(home, "r", encoding="utf-8") as f:
    home_content = f.read()

# Let's change HowToRow to HomeHowToRow and add its definition
home_content = home_content.replace("HowToRow(number", "HomeHowToRow(number")

home_howto_class = """
class HomeHowToRow extends StatelessWidget {
  const HomeHowToRow({super.key, required this.number, required this.title, required this.text});
  final String number, title, text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24, height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF71F39A).withOpacity(0.2), shape: BoxShape.circle),
          child: Text(number, style: const TextStyle(color: Color(0xFF71F39A), fontWeight: FontWeight.w900, fontSize: 12)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(color: Color(0xFFAFC4B6), fontSize: 13, height: 1.4)),
            ]
          )
        )
      ]
    )
  );
}
"""
home_content += "\n" + home_howto_class
with open(home, "w", encoding="utf-8") as f:
    f.write(home_content)

print("Fixes applied. Check online_screens.dart line 767:")
print(lines[765:768])
