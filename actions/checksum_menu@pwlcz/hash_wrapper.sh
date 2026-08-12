#!/bin/bash
# The first argument is the command (e.g., md5sum), the second is the display label, the rest are files.
set -euo pipefail

ALGORITHM=$1
LABEL=$2
shift 2
TEXT=""
for f in "$@"; do
  if [[ ! -f "$f" ]]; then
    TEXT+="<b>File:</b> $(basename "${f}")
<b>Status:</b> missing file
\n
"
    continue
  fi

  HASH=$($ALGORITHM "$f" | awk '{print $1}')
  # shellcheck disable=SC2012
  FILE_SIZE=$(ls -lh "${f}" | awk '{print $5}')
  TEXT+="<b>File:</b> $(basename "${f}")
<b>Size:</b> ${FILE_SIZE}
<b>${LABEL}:</b> ${HASH}
\n
"
done

if [[ "$#" -eq 1 ]]; then
  RESPONSE=$(zenity --info \
                    --title="$LABEL Checksum" \
                    --icon-name=checkbox-checked-symbolic \
                    --text="$TEXT" \
                    --ok-label="Close" \
                    --extra-button="Copy Hash" || true)

  if [[ "$RESPONSE" == "Copy Hash" ]]; then
    printf "%s" "$HASH" | xclip -selection clipboard
  fi
else
  # If multiple files were selected, just show the standard dialog
  zenity --info \
         --title="$LABEL Checksums" \
         --icon-name=checkbox-checked-symbolic \
         --text="$TEXT" \
         --ok-label="Close"
fi
