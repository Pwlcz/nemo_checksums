#!/bin/bash
# The first argument is the command (e.g., md5sum), the second is the display label.
ALGORITHM=$1
LABEL=$2
# Shift the first two arguments out so only the selected files remain in $@
shift 2
# TODO: change to zenity popup
for f in "$@"; do
    if [ ! -f "$f" ]; then
        echo "Skipping directory: $f"
        echo "--------------------------------------------------------------------------------"
        continue
    fi
    
    echo -e "\e[1;34mFile:\e[0m $f"
    
    # Calculate the hash and grab only the hex string (cut drops the file path)
    HASH=$($ALGORITHM "$f" | cut -d' ' -f1)
    
    echo -e "\e[1;32m$LABEL:\e[0m $HASH"
    echo "--------------------------------------------------------------------------------"
done

echo ""
read -rp "Press [Enter] to close..."