#!/bin/sh
# Starts the local Firebase backend and fills it with fake people (docs/specs/testing.md).
# The `demo-` project id keeps it local: the emulators refuse to touch a live project with it.
#   --wifi  also lets devices on the same network in, for testing on a phone.
set -e
cd "$(dirname "$0")/.."
config=firebase.json
ready="Ready. Ctrl-C to stop."
if [ "$1" = "--wifi" ]; then
  config=.firebase-wifi.json
  node -e '
    const config = JSON.parse(fs.readFileSync("firebase.json"));
    for (const name of ["auth", "firestore", "functions", "storage"]) config.emulators[name].host = "0.0.0.0";
    fs.writeFileSync(".firebase-wifi.json", JSON.stringify(config, null, 2));
  '
  interface=$(route -n get default | awk '/interface:/ { print $2 }')
  ready="Ready. On the phone, enter this address: $(ipconfig getifaddr "$interface"). Ctrl-C to stop."
fi
npm --prefix functions run build
exec firebase emulators:exec --config "$config" --only auth,firestore,functions,storage --project demo-squabble \
  "node emulator/seed.mjs && echo '$ready' && tail -f /dev/null"
