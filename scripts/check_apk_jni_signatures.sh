#!/usr/bin/env bash
# Fails if R8 renamed or removed something a plugin looks up through JNI.
#
# shared_preferences_android (Pigeon JNI + package:jni) finds Kotlin classes and
# methods by their exact names and signatures. If R8 renames one, the app
# crashes on start in release builds only (see apps/niyah/android/app/proguard-rules.pro).
#
# Usage: scripts/check_apk_jni_signatures.sh path/to/app-release.apk
#   DEXDUMP=/path/to/dexdump to choose the tool (default: newest in $ANDROID_HOME/build-tools).
set -euo pipefail

apk="${1:?usage: $0 app-release.apk}"
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
dexdump="${DEXDUMP:-}"
if [ -z "$dexdump" ]; then
  dexdump="$(ls -d "$sdk"/build-tools/*/dexdump* 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "$dexdump" ] || [ ! -x "$dexdump" ]; then
  echo "ERROR: dexdump not found (set DEXDUMP or ANDROID_HOME)" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
unzip -q -o "$apk" 'classes*.dex' -d "$tmp"
for dex in "$tmp"/classes*.dex; do
  "$dexdump" "$dex"
done > "$tmp/dump.txt"
failed=0

# 1. Classes the Dart side looks up by name (keep in sync with proguard-rules.pro).
classes=(
  kotlin/Result
  'kotlin/Result$Failure'
  kotlin/Unit
  kotlin/coroutines/Continuation
  kotlin/coroutines/intrinsics/CoroutineSingletons
  kotlin/coroutines/intrinsics/IntrinsicsKt
  io/flutter/plugins/sharedpreferences/SharedPreferencesApiRegistrar
  io/flutter/plugins/sharedpreferences/SharedPreferencesAsyncApiRegistrar
  io/flutter/plugins/sharedpreferences/SharedPreferencesPigeonOptions
  'io/flutter/plugins/sharedpreferences/SharedPreferencesPigeonOptions$Companion'
  io/flutter/plugins/sharedpreferences/StringListResult
  'io/flutter/plugins/sharedpreferences/StringListResult$Companion'
  io/flutter/plugins/sharedpreferences/StringListLookupResultType
)
for c in "${classes[@]}"; do
  if ! grep -qF "Class descriptor  : 'L$c;'" "$tmp/dump.txt"; then
    echo "ERROR: class $c is missing or renamed" >&2
    failed=1
  fi
done

# 2. Method signatures: every getAll (legacy and async API) must still name
# the real Continuation type.
continuation="Lkotlin/coroutines/Continuation;)Ljava/lang/Object;"
found="$(grep -A1 "name          : 'getAll'" "$tmp/dump.txt" | grep "type" | cut -d"'" -f2 | sort -u)"
if [ -z "$found" ]; then
  echo "ERROR: SharedPreferencesApiRegistrar.getAll not found" >&2
  failed=1
else
  broken="$(grep -vF "$continuation" <<<"$found" || true)"
  if [ -n "$broken" ]; then
    echo "ERROR: R8 renamed kotlin.coroutines.Continuation in JNI signatures:" >&2
    echo "$broken" | sed 's/^/  /' >&2
    failed=1
  fi
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "OK: ${#classes[@]} JNI classes present, getAll signatures intact."
