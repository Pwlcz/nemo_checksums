#!/bin/bash
# Verifies checksum in clipboard with selected file. Automatically detects which algorithm was used.
# If multiple algorithms, are possible, checks them all.
set -euo pipefail
export TEXTDOMAIN="checksum_menu@pwlcz"
export TEXTDOMAINDIR="${HOME}/.local/share/locale/"
OK_LABEL="$(gettext "Close")"

FILE="$1"

CLIP_CONTENT=$(xclip -o -selection clipboard 2>/dev/null || true)

if [[ -z "${CLIP_CONTENT:-}" ]]; then
  TITLE="$(gettext "No Clipboard Content")"
  TEXT="$(gettext "The clipboard is empty or does not contain text.")"
  zenity --warning --title="${TITLE}" --text="${TEXT}" --ok-label="${OK_LABEL}"
  exit 1
fi

# I like your funny words magic man
EXPECTED_HASH=$(printf '%s\n' "${CLIP_CONTENT}" | \
  grep -oE '\b([a-fA-F0-9]{32}|[a-fA-F0-9]{40}|[a-fA-F0-9]{56}|[a-fA-F0-9]{64}|[a-fA-F0-9]{96}|[a-fA-F0-9]{128})\b' | \
  head -n 1 | \
  tr '[:upper:]' '[:lower:]' || true)

if [[ -z "${EXPECTED_HASH:-}" ]]; then
  TITLE="$(gettext "No Checksum Found")"
  TEXT="$(gettext "Could not find a valid hash string in the clipboard.")"
  zenity --warning --title="${TITLE}" --text="${TEXT}" --ok-label="${OK_LABEL}"
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
  128) ALGS=("sha512sum" "b2sum") ; EXPECTED_TYPE="$(gettext "SHA-512 or BLAKE2")" ;;
  *)
    TITLE="$(gettext "Unsupported Hash Length")"
    TEXT="$(gettext "The clipboard hash length is not supported.")"
    zenity --error --title="${TITLE}" --text="${TEXT}" --ok-label="${OK_LABEL}"
    exit 1
    ;;
esac

# Wrap the calculation and the results in a subshell piped to zenity --progress
TITLE_PROGRESS="$(gettext "Verifying Checksum")"
# shellcheck disable=SC2059
TEXT_PROGRESS=$(printf "$(gettext "Hashing %s...")" "${FILE}")
(
  MATCH_FOUND=false
  ACTUAL_RESULTS=""
  MATCHED_ALG=""
  # shellcheck disable=SC2012
  FILE_SIZE=$(ls -lh "${FILE}" | awk '{print $5}')

  for ALG in "${ALGS[@]}"; do
    if ! command -v "${ALG}" &>/dev/null; then
      continue
    fi

    # Translate the raw command into a clean display name
    case "${ALG}" in
      md5sum)    FORMATTED_ALG="MD5" ;;
      sha1sum)   FORMATTED_ALG="SHA-1" ;;
      sha224sum) FORMATTED_ALG="SHA-224" ;;
      sha256sum) FORMATTED_ALG="SHA-256" ;;
      sha384sum) FORMATTED_ALG="SHA-384" ;;
      sha512sum) FORMATTED_ALG="SHA-512" ;;
      b2sum)     FORMATTED_ALG="BLAKE2" ;;
      *)         FORMATTED_ALG="${ALG}" ;;
    esac

    # Added || true to prevent pipefail from terminating the script
    HASH=$("${ALG}" "${FILE}" 2>/dev/null | awk '{print $1}' || true)
    
    if [[ -z "$HASH" ]]; then
      # shellcheck disable=SC2059
      ACTUAL_RESULTS+=$(printf "$(gettext "<b>%s:</b>\n<i>Failed to read file</i>\n")" "${FORMATTED_ALG}")
      continue
    fi

    # shellcheck disable=SC2059
    ACTUAL_RESULTS+=$(printf "$(gettext "\n<b>%s:</b>\n%s\n")" "${FORMATTED_ALG}" "${HASH}")

    if [[ "${EXPECTED_HASH}" == "${HASH}" ]]; then
      MATCH_FOUND=true
      MATCHED_ALG="${FORMATTED_ALG}"
      break
    fi
  done

  # Redirect standard output to /dev/null. This breaks the pipe to zenity --progress, 
  # forcing the loading bar to close BEFORE the final result dialog appears.
  exec >/dev/null

  if [[ "$MATCH_FOUND" == true ]]; then
    TITLE="$(gettext "Checksum Match")"
    # shellcheck disable=SC2059
    TEXT=$(printf "$(gettext "<span foreground='green' size='x-large'><b>MATCH</b></span>
<b>Algorithm:</b> %s
<b>File:</b> %s
<b>Size:</b> %s
<b>Hash:</b> %s")" \
"${MATCHED_ALG}" "$(basename "${FILE}")" "${FILE_SIZE}" "${EXPECTED_HASH}")
    zenity --info --title="${TITLE}" \
           --icon-name=checkbox-checked-symbolic \
           --text="${TEXT}" --ok-label="${OK_LABEL}"
  else
    TITLE="$(gettext "Checksum Mismatch")"
    # shellcheck disable=SC2059
    TEXT=$(printf "$(gettext "<span foreground='red' size='x-large'><b>MISMATCH</b></span>
<b>Expected type:</b> %s
<b>File:</b> %s
<b>Size:</b> %s
<b>Expected (Clipboard):</b> %s
<b>Actual Computed:</b> %s")" \
"${EXPECTED_TYPE}" "$(basename "${FILE}")" "${FILE_SIZE}" "${EXPECTED_HASH}" "${ACTUAL_RESULTS}")
    zenity --error --title="${TITLE}" --text="${TEXT}" --ok-label="${OK_LABEL}"
  fi
) | zenity --progress --title="${TITLE_PROGRESS}" --text="${TEXT_PROGRESS}" \
           --pulsate --auto-close --auto-kill
