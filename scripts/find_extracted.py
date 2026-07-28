import os
import re

lib_dir = r"c:\Users\ydursun\Desktop\futbol_meydani\lib"

def get_dart_files(directory):
    files = []
    for root, _, filenames in os.walk(directory):
        for filename in filenames:
            if filename.endswith(".dart"):
                files.append(os.path.join(root, filename))
    return files

def extract_class_names(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Matches top-level class, enum, and mixin names
    matches = re.findall(r'^(?:abstract\s+)?(?:class|enum|mixin)\s+([A-Za-z0-9_]+)', content, re.MULTILINE)
    return set(matches)

def main():
    dart_files = get_dart_files(lib_dir)
    extracted_classes = set()
    for f in dart_files:
        if os.path.basename(f) == "main.dart":
            continue
        extracted_classes.update(extract_class_names(f))
    
    # Let's print out what we found
    print("Extracted classes count:", len(extracted_classes))
    print("Sample:", list(extracted_classes)[:20])

if __name__ == "__main__":
    main()
