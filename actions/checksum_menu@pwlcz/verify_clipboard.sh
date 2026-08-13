#!/bin/bash
# Verifies checksum in clipboard with selected file. Automatically detects which algorithm was used.
# If multiple algorithms, are possible, checks them all.
set -euo pipefail

FILE="$1"

CLIP_CONTENT=$(xclip -o -selection clipboard 2>/dev/null || true)

if [[ -z "${CLIP_CONTENT:-}" ]]; then
  zenity --warning --title="No Clipboard Content" \
         --text="The clipboard is empty or does not contain text."
  exit 1
fi

# I like your funny words magic man
EXPECTED_HASH=$(printf '%s\n' "$CLIP_CONTENT" | \
  grep -oE '\b([a-fA-F0-9]{32}|[a-fA-F0-9]{40}|[a-fA-F0-9]{56}|[a-fA-F0-9]{64}|[a-fA-F0-9]{96}|[a-fA-F0-9]{128})\b' | \
  head -n 1 | \
  tr '[:upper:]' '[:lower:]' || true)

if [[ -z "${EXPECTED_HASH:-}" ]]; then
  zenity --warning --title="No Checksum Found" \
         --text="Could not find a valid hash string in the clipboard."
  exit 1
fi

LEN=${#EXPECTED_HASH}

# Map string length to an array of possible commands
case $LEN in
  32) ALGS=("md5sum") ; EXPECTED_TYPE="MD5" ;;
  40) ALGS=("sha1sum") ; EXPECTED_TYPE="SHA-1" ;;
  56) ALGS=("sha224sum") ; EXPECTED_TYPE="SHA-224" ;;
  64) ALGS=("sha256sum") ; EXPECTED_TYPE="SHA-256" ;;
  96) ALGS=("sha384sum") ; EXPECTED_TYPE="SHA-384" ;;
  128) ALGS=("sha512sum" "b2sum") ; EXPECTED_TYPE="SHA-512 or BLAKE2" ;;
  *)
    zenity --error --title="Unsupported Hash Length" \
           --text="The clipboard hash length is not supported."
    exit 1
    ;;
esac

# Wrap the calculation and the results in a subshell piped to zenity --progress
(
  MATCH_FOUND=false
  ACTUAL_RESULTS=""
  MATCHED_ALG=""
  # shellcheck disable=SC2012
  FILE_SIZE=$(ls -lh "${FILE}" | awk '{print $5}')

  for ALG in "${ALGS[@]}"; do
    if ! command -v "$ALG" >/dev/null 2>&1; then
      continue
    fi

    # Translate the raw command into a clean display name
    case "$ALG" in
      md5sum)    FORMATTED_ALG="MD5" ;;
      sha1sum)   FORMATTED_ALG="SHA-1" ;;
      sha224sum) FORMATTED_ALG="SHA-224" ;;
      sha256sum) FORMATTED_ALG="SHA-256" ;;
      sha384sum) FORMATTED_ALG="SHA-384" ;;
      sha512sum) FORMATTED_ALG="SHA-512" ;;
      b2sum)     FORMATTED_ALG="BLAKE2" ;;
      *)         FORMATTED_ALG="$ALG" ;;
    esac

    # Added || true to prevent pipefail from terminating the script
    ACTUAL=$("$ALG" "$FILE" 2>/dev/null | awk '{print $1}' || true)
    
    if [[ -z "$ACTUAL" ]]; then
      ACTUAL_RESULTS+="<b>${FORMATTED_ALG}:</b>\n<i>Failed to read file</i>\n"
      continue
    fi

    ACTUAL_RESULTS+="<b>${FORMATTED_ALG}:</b>\n${ACTUAL}\n"

    if [[ "$EXPECTED_HASH" == "$ACTUAL" ]]; then
      MATCH_FOUND=true
      MATCHED_ALG="$FORMATTED_ALG"
      break
    fi
  done

  # Redirect standard output to /dev/null. This breaks the pipe to zenity --progress, 
  # forcing the loading bar to close BEFORE the final result dialog appears.
  exec >/dev/null

  if [[ "$MATCH_FOUND" == true ]]; then
    zenity --info --title="Checksum Match" \
           --icon-name=checkbox-checked-symbolic \
           --text="<span foreground='green' size='x-large'><b>MATCH</b></span>

<b>Algorithm:</b> ${MATCHED_ALG}
<b>File:</b> $(basename "${FILE}")
<b>Size:</b> ${FILE_SIZE}

<b>Hash:</b>
${EXPECTED_HASH}"
  else
    zenity --error --title="Checksum Mismatch" \
      --text="<span foreground='red' size='x-large'><b>MISMATCH</b></span>

<b>Expected type:</b> ${EXPECTED_TYPE}
<b>File:</b> $(basename "$FILE")
<b>Size:</b> ${FILE_SIZE}

<b>Expected (Clipboard):</b>
$EXPECTED_HASH

<b>Actual Computed:</b>
$ACTUAL_RESULTS"
  fi
) | zenity --progress --title="Verifying Checksum" \
           --text="Hashing $(basename "$FILE")..." \
           --pulsate --auto-close --auto-kill
