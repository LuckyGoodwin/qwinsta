"""Keep the homepage article catalog in sync with the two-level MkDocs nav.

The historical filename and markers are retained for the deployment workflow.
PyYAML is already a dependency of MkDocs; no additional packages are required.
"""
from pathlib import Path

import yaml

DOCS_DIR = Path("docs")
INDEX_FILE = DOCS_DIR / "index.md"
START = "<!-- latest:start -->"
END = "<!-- latest:end -->"


def article_catalog(nav: list) -> str:
    sections = []
    for entry in nav:
        for topic, articles in entry.items():
            if isinstance(articles, str):
                continue  # The standalone homepage is not a catalog section.
            links = []
            for article in articles:
                for title, path in article.items():
                    if not isinstance(path, str):
                        raise ValueError("Navigation must contain only topics and articles")
                    if not (DOCS_DIR / path).is_file():
                        raise FileNotFoundError(f"Navigation target does not exist: {path}")
                    links.append(f"- [{title}]({path})")
            if links:
                sections.append(f"## {topic}\n\n" + "\n".join(links))
    return "\n\n".join(sections)


def main() -> None:
    config = yaml.safe_load(Path("mkdocs.yml").read_text(encoding="utf-8"))
    content = INDEX_FILE.read_text(encoding="utf-8")
    before, start_marker, rest = content.partition(START)
    _, end_marker, after = rest.partition(END)
    if not start_marker or not end_marker:
        raise RuntimeError("Catalog markers not found in docs/index.md")
    block = START + "\n\n" + article_catalog(config["nav"]) + "\n\n" + END
    INDEX_FILE.write_text(before + block + after, encoding="utf-8")


if __name__ == "__main__":
    main()
