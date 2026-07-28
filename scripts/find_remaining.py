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
    
    matches = re.findall(r'^(?:abstract\s+)?(?:class|enum|mixin)\s+([A-Za-z0-9_]+)', content, re.MULTILINE)
    return set(matches)

def main():
    dart_files = get_dart_files(lib_dir)
    extracted_classes = set()
    main_classes = set()
    for f in dart_files:
        classes = extract_class_names(f)
        if os.path.basename(f) == "main.dart":
            main_classes.update(classes)
        else:
            extracted_classes.update(classes)
    
    not_extracted = main_classes - extracted_classes
    print("Classes ONLY in main.dart:", len(not_extracted))
    print(list(not_extracted))

if __name__ == "__main__":
    main()
