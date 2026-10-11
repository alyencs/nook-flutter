#!/usr/bin/env bash
#
# Refuses to publish a web build that carries a credential.
#
# Everything under build/web is served verbatim to anyone who opens the site:
# every string in main.dart.js, every bundled asset. A key in there is a
# published key, and no amount of obfuscation changes that.
#
# Nook is arranged so this cannot happen — credentials arrive as --dart-define
# on a local command and the deploy passes none — but "cannot happen" is a
# property of today's code, and the failure is silent and expensive. So the
# built output is checked before it goes out.
#
# Run it yourself before publishing a build you made by hand:
#   ./tool/check_bundle.sh build/web
#
# Exit 0: nothing credential-shaped found. Exit 1: do not publish this.

set -uo pipefail

bundle="${1:-build/web}"

if [ ! -d "$bundle" ]; then
  echo "check_bundle: no such directory: $bundle" >&2
  echo "build it first: flutter build web --release" >&2
  exit 1
fi

findings=0

note() {
  findings=$((findings + 1))
  echo ""
  echo "  ✗ $1"
}

echo "Checking $bundle for credentials…"

# 1. Vendor key formats, which are recognisable on sight and so can be found
#    wherever they ended up — a bundled asset, a compiled string, a stray
#    config file someone copied in.
while IFS= read -r line; do
  [ -z "$line" ] && continue
  note "an Anthropic key is in the build: ${line%%:*}"
done < <(grep -rlE 'sk-ant-api[0-9]{2}-' "$bundle" 2>/dev/null)

while IFS= read -r line; do
  [ -z "$line" ] && continue
  note "a Google API key is in the build: ${line%%:*}"
done < <(grep -rlE 'AIza[0-9A-Za-z_-]{35}' "$bundle" 2>/dev/null)

# 2. The env asset, checked by shape rather than by format. This is the one
#    that actually catches the realistic mistake: a working nook.env left in
#    place while running `flutter build web` by hand. A name ending in KEY,
#    TOKEN, SECRET or PASSWORD with anything after the = is refused, whatever
#    the value looks like.
while IFS= read -r envfile; do
  [ -z "$envfile" ] && continue
  while IFS= read -r assignment; do
    [ -z "$assignment" ] && continue
    note "${envfile#"$bundle"/} sets ${assignment%%=*}, which is a credential and is served to every visitor"
  done < <(
    grep -hE '^[[:space:]]*[A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD)[[:space:]]*=[[:space:]]*[^[:space:]]' \
      "$envfile" 2>/dev/null
  )
done < <(find "$bundle" -type f \( -name '*.env' -o -name '.env' -o -name '.env.*' \) 2>/dev/null)

echo ""
if [ "$findings" -gt 0 ]; then
  echo "$findings problem(s). This build must not be published."
  echo ""
  echo "A web build is public in full. Pass credentials to a local run with"
  echo "--dart-define instead, and keep the deployed build keyless — it reaches"
  echo "the model through Nook's AI service, which holds the key server-side."
  exit 1
fi

echo "Clean: no credential found in the build."
