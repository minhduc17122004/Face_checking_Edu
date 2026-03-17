import os

def fix_dots(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(".py"):
                path = os.path.join(root, file)
                with open(path, "r", encoding="utf-8") as f:
                    content = f.read()
                
                new_content = content.replace("uuid.Optional[UUID]", "Optional[uuid.UUID]")
                new_content = new_content.replace("datetime.Optional[datetime]", "Optional[datetime.datetime]")
                
                if new_content != content:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(new_content)

fix_dots("app/models")
fix_dots("app/schemas")
