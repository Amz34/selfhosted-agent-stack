#!/usr/bin/env python3
"""
Gmail IMAP Toolbox — search and extract emails from any Gmail inbox.

A dependency-free, reusable CLI for newsletter/news monitoring workflows.
Credentials come from environment variables (never hardcode them):

    export GMAIL_ADDRESS="you@gmail.com"
    export GMAIL_APP_PASSWORD="your-16-char-app-password"   # Google App Password

Commands:
    python gmail_toolbox.py search "subject:stripe"          # list matching emails
    python gmail_toolbox.py search "from:newsletter@x.com" --limit 10
    python gmail_toolbox.py get MESSAGE_ID                   # full body (plain+html)
    python gmail_toolbox.py list --recent 15                 # latest emails
"""
import imaplib, email, os, re, sys, html as htmlmod
from email.header import decode_header, make_header

ADDR = os.environ.get("GMAIL_ADDRESS", "")
PWD = os.environ.get("GMAIL_APP_PASSWORD", "")


def get_text(part):
    """Extract plain or html text from a MIME part."""
    try:
        raw = part.get_payload(decode=True).decode("utf-8", errors="ignore")
    except Exception:
        return ""
    if part.get_content_type() == "text/plain":
        return raw
    if part.get_content_type() == "text/html":
        raw = re.sub(r"<script[\s\S]*?</script>", " ", raw)
        raw = re.sub(r"<style[\s\S]*?</style>", " ", raw)
        raw = re.sub(r"<br\s*/?>", "\n", raw)
        raw = re.sub(r"</(p|div|h1|h2|h3|li|tr)>", "\n", raw)
        raw = re.sub(r"<[^>]+>", " ", raw)
        return htmlmod.unescape(raw)
    return ""


def connect():
    if not ADDR or not PWD:
        sys.exit("Set GMAIL_ADDRESS and GMAIL_APP_PASSWORD env vars first.")
    m = imaplib.IMAP4_SSL("imap.gmail.com", 993)
    m.login(ADDR, PWD)
    m.select("INBOX")
    return m


def search(criteria, limit=20):
    m = connect()
    try:
        typ, data = m.search(None, criteria)
        ids = [i.decode() for i in data[0].split()]
        for mid in ids[-limit:]:
            typ, hdr = m.fetch(mid, "(BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE)])")
            raw = hdr[0][1].decode("utf-8", errors="ignore")
            msg = email.message_from_string(raw)
            subj = str(make_header(decode_header(msg.get("Subject", ""))))
            frm = str(make_header(decode_header(msg.get("From", ""))))
            print(f"ID {mid} | {msg.get('Date','')}")
            print(f"   From: {frm}")
            print(f"   Subj: {subj}")
    finally:
        m.logout()


def get(mid, max_chars=6000):
    m = connect()
    try:
        typ, data = m.fetch(mid, "(RFC822)")
        msg = email.message_from_bytes(data[0][1])
        print(f"SUBJ: {str(make_header(decode_header(msg.get('Subject',''))))}")
        print(f"FROM: {msg.get('From','')}")
        print(f"DATE: {msg.get('Date','')}")
        print("=" * 60)
        parts = []
        if msg.is_multipart():
            for part in msg.walk():
                if part.get_content_type() in ("text/plain", "text/html"):
                    parts.append(get_text(part))
        else:
            parts.append(get_text(msg))
        plain = [p for p in parts if p and len(p) > 100]
        body = max(plain, key=len) if plain else "".join(parts)
        body = re.sub(r"[ \t]+", " ", body)
        body = re.sub(r"\n\s*\n+", "\n\n", body)
        print(body[:max_chars])
    finally:
        m.logout()


def list_recent(count=15):
    m = connect()
    try:
        typ, data = m.search(None, "ALL")
        ids = [i.decode() for i in data[0].split()]
        for mid in ids[-count:]:
            typ, hdr = m.fetch(mid, "(BODY.PEEK[HEADER.FIELDS (SUBJECT FROM DATE)])")
            raw = hdr[0][1].decode("utf-8", errors="ignore")
            msg = email.message_from_string(raw)
            print(f"ID {mid} | {msg.get('Date','')}")
            print(f"   From: {str(make_header(decode_header(msg.get('From',''))))}")
            print(f"   Subj: {str(make_header(decode_header(msg.get('Subject',''))))}")
    finally:
        m.logout()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "search" and len(sys.argv) >= 3:
        search(sys.argv[2], int(sys.argv[4]) if len(sys.argv) > 4 and sys.argv[3] == "--limit" else 20)
    elif cmd == "get" and len(sys.argv) >= 3:
        get(sys.argv[2])
    elif cmd == "list":
        list_recent(int(sys.argv[3]) if len(sys.argv) > 3 else 15)
    else:
        sys.exit(__doc__)
