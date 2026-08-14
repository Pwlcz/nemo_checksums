#!/bin/bash
# The first argument is the command (e.g., md5sum), the second is the display label, the rest are files.
set -euo pipefail
export TEXTDOMAIN="checksum_menu@pwlcz"
export TEXTDOMAINDIR="${HOME}/.local/share/locale"
ALGORITHM=$1
LABEL=$2
shift 2
TEXT=""
for f in "$@"; do
  if [[ ! -f "${f}" ]]; then
    # shellcheck disable=SC2059
    TEXT+=$(printf "$(gettext "<b>File:</b> %s
<b>Status:</b> missing file\n\n")" "$(basename "${f}")")
    continue
  fi

  HASH=$(${ALGORITHM} "${f}" | awk '{print $1}')
  # shellcheck disable=SC2012
  FILE_SIZE=$(ls -lh "${f}" | awk '{print $5}')
  # shellcheck disable=SC2059
  TEXT+=$(printf "$(gettext "<b>File:</b> %s
<b>Size:</b> %s
<b>%s Checksum:</b> %s\n\n")" \
"$(basename "${f}")" "${FILE_SIZE}" "${LABEL}" "${HASH}")

done

# shellcheck disable=SC2059
TITLE=$(printf "$(gettext "%s Checksum")" "${LABEL}")
OK_LABEL="$(gettext "Close")"
CP_BTN="$(gettext "Copy Hash")"

if [[ "$#" -eq 1 ]]; then
  # When one file was selected, shows 'copy to clipboard' button
  RESPONSE=$(zenity --info \
                    --title="${TITLE}" \
                    --icon-name=checkbox-checked-symbolic \
                    --text="${TEXT}" \
                    --ok-label="${OK_LABEL}" \
                    --extra-button="${CP_BTN}" || true)

  if [[ "${RESPONSE}" == "${CP_BTN}" ]]; then
    printf "%s" "${HASH}" | xclip -selection clipboard
  fi
else
  # If multiple files were selected, just show the standard dialog
  zenity --info \
         --title="${TITLE}" \
         --icon-name=checkbox-checked-symbolic \
         --text="${TEXT}" \
         --ok-label="${OK_LABEL}"
fi
