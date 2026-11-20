#!/usr/bin/env bash
# Phase 0 environment check. Does not install anything.
set -u

fail=0
warn=0

check() {
  local name="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    printf "[ok]   %-10s %s\n" "$name" "$("$@" 2>&1 | head -n 1)"
  else
    printf "[miss] %-10s not found\n" "$name"
    fail=1
  fi
}

check_optional() {
  local name="$1"; shift
  if command -v "$1" >/dev/null 2>&1; then
    printf "[ok]   %-10s %s\n" "$name" "$("$@" 2>&1 | head -n 1)"
  else
    printf "[warn] %-10s not found (optional for this step)\n" "$name"
    warn=1
  fi
}

echo "== Toolchain =="
check git git --version
check node node --version
check npm npm --version
check python3 python3 --version
check_optional docker docker --version
check_optional godot godot --version

echo
echo "== Pins (.env) =="
if [ -f .env ]; then
  for key in GODOT_COMMIT VOXEL_TOOLS_COMMIT EMSDK_VERSION GODOTCPP_BRANCH; do
    value="$(grep -E "^${key}=" .env | cut -d= -f2- || true)"
    if [ -z "${value}" ]; then
      printf "[todo] %-20s not pinned\n" "$key"
      warn=1
    else
      printf "[ok]   %-20s %s\n" "$key" "$value"
    fi
  done
else
  echo "[todo] .env missing — copy .env.example to .env and fill pins after G0"
  warn=1
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "Result: required tools missing."
  exit 1
fi
if [ "$warn" -ne 0 ]; then
  echo "Result: required tools present; optional items or pins pending."
  exit 0
fi
echo "Result: environment looks ready."
