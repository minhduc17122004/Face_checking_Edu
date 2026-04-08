import pathlib

path = pathlib.Path(r'backend/app/services/face_service.py')
src = path.read_text(encoding='utf-8')

# Find lines 250-278 and print repr to diagnose
lines = src.splitlines(keepends=True)
print(f"Total lines: {len(lines)}")
for i, ln in enumerate(lines[248:280], start=249):
    print(f"{i}: {repr(ln)}")
