#!/bin/bash
# Opens the site at http://localhost:8000 (Mac / Linux).
# Double-click this file, or run ./lancer-site.command in a terminal.
cd "$(dirname "$0")" || exit 1

if ! python3 -c 'import http.server' >/dev/null 2>&1; then
  echo "Python 3 introuvable : ouverture de index.html directement dans le navigateur."
  if command -v open >/dev/null 2>&1; then open index.html; else xdg-open index.html; fi
  exit 0
fi

exec python3 - <<'PY'
import functools, http.server, threading, webbrowser

class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args):
        pass

handler = functools.partial(QuietHandler, directory=".")
for port in range(8000, 8011):
    try:
        server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
        break
    except OSError:
        continue
else:
    raise SystemExit("Aucun port libre entre 8000 et 8010.")

url = f"http://localhost:{port}/"
print(f"\n  Site en ligne sur {url}")
print("  Laisse cette fenetre ouverte. Ferme-la (ou Ctrl+C) pour arreter le site.\n")
threading.Timer(0.5, webbrowser.open, [url]).start()
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
PY
