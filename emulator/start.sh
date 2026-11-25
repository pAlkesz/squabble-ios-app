#!/bin/sh
# Starts the local Firebase backend and fills it with fake people (docs/specs/testing.md).
# The `demo-` project id keeps it local: the emulators refuse to touch a live project with it.
set -e
cd "$(dirname "$0")/.."
npm --prefix functions run build
exec firebase emulators:exec --only auth,firestore,functions,storage --project demo-squabble \
  "node emulator/seed.mjs && echo 'Ready. Ctrl-C to stop.' && tail -f /dev/null"
