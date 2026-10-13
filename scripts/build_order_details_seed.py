"""Land data/order_details.json as a dbt seed with one raw JSON document per row.

Each array element is copied verbatim (only whitespace between tokens is
collapsed), so number literals, nulls and string-typed values reach Snowflake
exactly as the source sent them. Parsing happens in dbt with PARSE_JSON.

Usage:
    python scripts/build_order_details_seed.py          # write the seed
    python scripts/build_order_details_seed.py --check  # fail if the seed is stale
"""

import argparse
import csv
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "order_details.json"
SEED = ROOT / "src" / "dbt" / "seeds" / "order_details.csv"

# Insignificant whitespace around structural characters. JSON strings cannot
# contain raw newlines, so collapsing line breaks never touches string content.
_NEWLINE_INDENT = re.compile(r"\s*\n\s*")


def split_array(text: str) -> list[str]:
    """Return the raw source text of each element of a top-level JSON array."""
    json.loads(text)  # fail fast on invalid JSON
    decoder = json.JSONDecoder()
    pos = text.index("[") + 1
    elements = []
    while True:
        while text[pos] in " \t\r\n,":
            pos += 1
        if text[pos] == "]":
            return elements
        _, end = decoder.raw_decode(text, pos)
        elements.append(_NEWLINE_INDENT.sub("", text[pos:end]))
        pos = end


def render_seed() -> str:
    buffer = io.StringIO()
    writer = csv.writer(buffer, lineterminator="\n")
    writer.writerow(["record_number", "payload"])
    for number, payload in enumerate(split_array(SOURCE.read_text(encoding="utf-8")), start=1):
        writer.writerow([number, payload])
    return buffer.getvalue()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if the seed is out of date")
    args = parser.parse_args()

    expected = render_seed()
    if args.check:
        current = SEED.read_text(encoding="utf-8") if SEED.exists() else ""
        if current != expected:
            print(f"{SEED.relative_to(ROOT)} is out of date; run {Path(__file__).name}", file=sys.stderr)
            return 1
        return 0

    SEED.write_text(expected, encoding="utf-8")
    print(f"wrote {SEED.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
