from pathlib import Path
import subprocess

DOCS_DIR = Path("docs")
INDEX_FILE = DOCS_DIR / "index.md"

START = "<!-- latest:start -->"
END = "<!-- latest:end -->"

EXCLUDE = {
    "index.md",
    "latest.md",
}

MAX_ITEMS = 8


def git_date(path: Path) -> int:
    try:
        result = subprocess.run(
            ["git", "log", "-1", "--format=%ct", "--", str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
        return int(result.stdout.strip() or 0)
    except Exception:
        return 0


def title_from_md(path: Path) -> str:
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("# "):
            return line[2:].strip()
    return path.stem.replace("-", " ")


files = [
    p for p in DOCS_DIR.rglob("*.md")
    if p.name not in EXCLUDE
]

files.sort(key=git_date, reverse=True)

items = []
for path in files[:MAX_ITEMS]:
    rel = path.relative_to(DOCS_DIR).as_posix()
    title = title_from_md(path)
    items.append(f"- [{title}]({rel})")

content = INDEX_FILE.read_text(encoding="utf-8")

new_block = START + "\n" + "\n".join(items) + "\n" + END

before, start_marker, rest = content.partition(START)
_, end_marker, after = rest.partition(END)

if not start_marker or not end_marker:
    raise RuntimeError("latest markers not found in docs/index.md")

INDEX_FILE.write_text(before + new_block + after, encoding="utf-8")