#!/usr/bin/env python3
"""Create/update the JinjaHA BookStack book from bookstack-book/*.md.

Auth (first match wins):
  1) BOOKSTACK_URL + BOOKSTACK_TOKEN_ID + BOOKSTACK_TOKEN_SECRET env vars
  2) /tmp/bs_auth.env (local agent helper)
  3) HA bookstack_sync entry at /config/.storage/core.config_entries
"""

from __future__ import annotations

import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path

BOOK_NAME = "JinjaHA"
BOOK_SLUG_HINT = "jinjaha"
BOOK_DESCRIPTION = (
    "Owned Swift Jinja2 engine (JinjaCore) plus Home Assistant template helpers "
    "and SwiftUI presentation for Apple HA dashboard apps."
)
PAGES = [
    ("00-overview.md", "Overview"),
    ("01-architecture.md", "Architecture"),
    ("02-setup.md", "Setup"),
    ("03-roadmap.md", "Roadmap & phases"),
    ("04-notes.md", "Notes"),
    ("05-links.md", "Links"),
]


def _load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        os.environ.setdefault(key.strip(), val.strip())


def _auth_and_base() -> tuple[str, str]:
    _load_dotenv(Path("/tmp/bs_auth.env"))
    url = os.environ.get("BOOKSTACK_URL")
    tid = os.environ.get("BOOKSTACK_TOKEN_ID")
    secret = os.environ.get("BOOKSTACK_TOKEN_SECRET")
    if url and tid and secret:
        return url.rstrip("/"), f"Token {tid}:{secret}"

    candidates = [
        Path("/config/.storage/core.config_entries"),
        Path("/mnt/data/supervisor/homeassistant/.storage/core.config_entries"),
    ]
    for path in candidates:
        if not path.is_file():
            continue
        entries = json.loads(path.read_text(encoding="utf-8"))["data"]["entries"]
        entry = next(e for e in entries if e.get("domain") == "bookstack_sync")
        data = entry["data"]
        base = str(data["base_url"]).rstrip("/")
        auth = "Token %s:%s" % (data["token_id"], data["token_secret"])
        return base, auth

    raise SystemExit("No BookStack credentials found (env or HA config_entries)")


def api(base: str, auth: str, method: str, path: str, payload: dict | None = None):
    body = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        base + path,
        data=body,
        method=method,
        headers={
            "Authorization": auth,
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
    )
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=90) as resp:
            return resp.status, json.load(resp)
    except urllib.error.HTTPError as err:
        detail = err.read().decode("utf-8", "replace")
        raise SystemExit(f"HTTP {err.code} {path}: {detail[:800]}") from err


def strip_leading_h1(md: str) -> str:
    lines = md.splitlines()
    if lines and lines[0].startswith("# "):
        return "\n".join(lines[1:]).lstrip("\n")
    return md


def main() -> int:
    src = Path(os.environ.get("BOOK_DIR", Path(__file__).resolve().parents[1] / "bookstack-book"))
    if not src.is_dir():
        print(f"BOOK_DIR missing: {src}", file=sys.stderr)
        return 1

    base, auth = _auth_and_base()
    _, books = api(base, auth, "GET", "/api/books?count=100")
    existing = None
    for book in books.get("data", []):
        if book.get("slug") == BOOK_SLUG_HINT or book.get("name") == BOOK_NAME:
            existing = book
            break

    if existing:
        book = existing
        print("reuse_book", book["id"], book.get("slug"))
    else:
        _, book = api(
            base,
            auth,
            "POST",
            "/api/books",
            {
                "name": BOOK_NAME,
                "description": BOOK_DESCRIPTION,
                "tags": [
                    {"name": "jinja", "value": ""},
                    {"name": "home-assistant", "value": ""},
                    {"name": "swift", "value": ""},
                    {"name": "apple", "value": ""},
                ],
            },
        )
        print("created_book", book["id"], book.get("slug"))

    book_id = book["id"]
    book_slug = book.get("slug")

    by_name: dict[str, int] = {}
    _, pages_list = api(
        base, auth, "GET", f"/api/pages?filter[book_id]={book_id}&count=100"
    )
    for page in pages_list.get("data", []):
        by_name[page["name"]] = page["id"]

    for filename, title in PAGES:
        path = src / filename
        if not path.is_file():
            print("missing", path, file=sys.stderr)
            continue
        markdown = strip_leading_h1(path.read_text(encoding="utf-8"))
        payload = {
            "book_id": book_id,
            "name": title,
            "markdown": markdown,
        }
        if title in by_name:
            page_id = by_name[title]
            _, page = api(base, auth, "PUT", f"/api/pages/{page_id}", payload)
            print("updated_page", page_id, title)
        else:
            _, page = api(base, auth, "POST", "/api/pages", payload)
            print("created_page", page["id"], title)

    print("book_url", f"{base}/books/{book_slug}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
