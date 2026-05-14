#!/usr/bin/env bash
set -euo pipefail

# /opt/hal/scripts/add_httpx_to_dockerfiles.sh
# Usage: sudo ./add_httpx_to_dockerfiles.sh --dry-run
DRY_RUN=false
TARGET_DIRS=(/opt/hal/docker/node1 /opt/hal/docker/node2)
INSERT_LINE='RUN python -m pip install --no-cache-dir httpx'

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

backup_and_write() {
  local src="$1"
  local new="$2"
  local bak="${src}.bak.$(date +%s)"
  cp "${src}" "${bak}"
  if [ "${DRY_RUN}" = true ]; then
    echo "DRY RUN: would write patched file to ${src} (backup at ${bak})"
  else
    mv "${new}" "${src}"
    echo "Patched ${src} (backup: ${bak})"
  fi
}

for d in "${TARGET_DIRS[@]}"; do
  if [ ! -d "${d}" ]; then
    echo "Skipping ${d}: directory not found"
    continue
  fi
  for df in "${d}/Dockerfile" "${d}/Dockerfile.rag"; do
    if [ ! -f "${df}" ]; then
      continue
    fi
    echo "Processing ${df}..."
    tmp="$(mktemp)"
    inserted=false

    # Strategy: insert after first RUN that contains pip install or requirements.txt handling
    awk -v insert="${INSERT_LINE}" -v inserted_flag=0 '
    BEGIN { inserted=0 }
    {
      print $0
      if (!inserted && match(tolower($0), /run .*pip install/) ) {
        print insert
        inserted=1
      } else if (!inserted && match(tolower($0), /run .*install.*requirements.txt/) ) {
        print insert
        inserted=1
      }
    }
    END {
      if (!inserted) {
        # will append later by the shell wrapper
      }
    }' "${df}" > "${tmp}"

    # If awk did not insert, append before last CMD/ENTRYPOINT or at EOF
    if ! grep -qF "${INSERT_LINE}" "${tmp}"; then
      # try to insert before last CMD or ENTRYPOINT
      if grep -qE '^(CMD|ENTRYPOINT)\b' "${tmp}"; then
        awk -v insert="${INSERT_LINE}" '
        BEGIN { done=0 }
        {
          if (!done && ($1=="CMD" || $1=="ENTRYPOINT")) {
            print insert
            done=1
          }
          print $0
        }' "${tmp}" > "${tmp}.2" && mv "${tmp}.2" "${tmp}"
      else
        echo "${INSERT_LINE}" >> "${tmp}"
      fi
    fi

    # show diff in dry-run
    if [ "${DRY_RUN}" = true ]; then
      echo "----- ${df} (patched preview) -----"
      diff -u "${df}" "${tmp}" || true
      rm -f "${tmp}"
    else
      backup_and_write "${df}" "${tmp}"
    fi
  done
done

echo "Done. If not dry-run, remember to rebuild images and push to registry."
