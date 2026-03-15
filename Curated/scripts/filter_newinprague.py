#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Reads HTML from stdin, removes:
  1) <p> containing "Realizátorem projektu" (grant acknowledgment)
  2) <div id="cmp-banner"> and <div id="cmp-modal"> (cookies UI)
  3) <script> blocks tied to CMP cookies UI
  4) <p> or text containing "© <year> Integrační centrum Praha o.p.s."
Writes cleaned HTML to stdout.
"""
import sys, re

def main():
    html = sys.stdin.read()

    try:
        from bs4 import BeautifulSoup, Comment
        soup = BeautifulSoup(html, "html.parser")

        # 1) Remove CMP banner & modal nodes
        for id_ in ("cmp-banner", "cmp-modal"):
            el = soup.find(id=id_)
            if el:
                el.decompose()

        # Remove the small CMP script that manipulates those nodes
        for script in soup.find_all("script"):
            txt = script.get_text() or ""
            if any(k in txt for k in (
                "cmp-banner", "cmp-modal", "accept-all", "reject-all",
                "customize", "save-settings", "close-modal"
            )):
                script.decompose()

        # Remove the helper comments (optional)
        for c in soup.find_all(string=lambda t: isinstance(t, Comment)):
            if "CMP Banner" in c or "CMP Modal" in c:
                c.extract()

        # 2) Remove the grant acknowledgment paragraph
        for node in soup.find_all(string=re.compile(r"Realizátorem\s+projektu", re.I)):
            p = node.find_parent("p")
            (p or node.parent).decompose()

        # 3) Remove copyright line (year-agnostic)
        for node in soup.find_all(
            string=re.compile(r"©\s*\d{4}\s*Integrační\s+centrum\s+Praha", re.I)
        ):
            p = node.find_parent("p")
            (p or node.parent).decompose()

        sys.stdout.write(str(soup))

    except Exception:
        # Regex fallback if BeautifulSoup isn't available
        out = re.sub(r'<div[^>]+id=["\']cmp-banner["\'][\s\S]*?</div>', '', html, flags=re.I)
        out = re.sub(r'<div[^>]+id=["\']cmp-modal["\'][\s\S]*?</div>', '', out, flags=re.I)
        out = re.sub(
            r'<script\b[^>]*>[\s\S]*?(cmp-banner|cmp-modal|accept-all|reject-all|customize|save-settings|close-modal)[\s\S]*?</script>',
            '',
            out,
            flags=re.I
        )
        out = re.sub(r'<p\b[^>]*>[\s\S]*?Realizátorem\s+projektu[\s\S]*?</p>', '', out, flags=re.I)
        out = re.sub(r'<p\b[^>]*>[\s\S]*?©\s*\d{4}\s*Integrační\s+centrum\s+Praha[\s\S]*?</p>', '', out, flags=re.I)
        sys.stdout.write(out)

if __name__ == "__main__":
    main()

