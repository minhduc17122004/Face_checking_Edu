import os

def process_dir(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".py"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                if "from __future__ import annotations" not in content:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write("from __future__ import annotations\n" + content)

process_dir("app")
process_dir("tests")
