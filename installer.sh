#!/bin/bash
set -euo pipefail

function echo_error() {
  echo -e "\e[31mError: $*\e[0m" >&2 # Red
}

function echo_ok() {
  echo -e "\e[1;32m$*\e[0m" # Bold Green  
}

function echo_step() {
  local ARROW="\e[34m==>\e[0m" # Blue
  echo -e "${ARROW} \e[1m$*\e[0m" # Bold 
}

add_nemo_submenu() {
    local submenu_name="$1"
    shift

    local json_file="${HOME}/.config/nemo/actions-tree.json"

    if ! command -v jq >/dev/null 2>&1; then
        echo "Error: 'jq' is required to parse JSON safely. Please install it first." >&2
        return 1
    fi

    if [[ ! -f "$json_file" ]]; then
        mkdir -p "$(dirname "$json_file")"
        echo '{"toplevel":[]}' > "$json_file"
    fi

    local children='[]'

    for action in "$@"; do
        local uuid
        uuid=$(basename "$action")

        children=$(jq -c --arg uuid "$uuid" '. += [{
            "uuid": $uuid,
            "type": "action",
            "user-label": null,
            "user-icon": null,
            "accelerator": null
        }]' <<< "$children")
    done

    local tmp_file
    tmp_file=$(mktemp)

    jq \
        --arg name "$submenu_name" \
        --argjson children "$children" \
        '.toplevel += [{
            "uuid": $name,
            "type": "submenu",
            "user-label": $name,
            "user-icon": null,
            "accelerator": null,
            "children": $children
        }]' \
        "$json_file" > "$tmp_file"

    if [[ -s "$tmp_file" ]]; then
        mv "$tmp_file" "$json_file"
        echo_ok "Submenu \"${submenu_name}\" successfully added to ${json_file}"
        echo_ok 'Run "nemo -q" to restart the file manager and apply changes.'
    else
        echo_error "jq failed to process the JSON. Your original file is untouched."
        rm "$tmp_file"
    fi
}

function main() {
  # TODO: check if necessary dependencies exist
  cd "$(dirname "$0")"

  # check if expected files exist before copying
  if [[ ! -d "./actions/checksum_menu@pwlcz" ]]; then
    echo_error "missing script dir"
  fi

  if ! ls actions/*.nemo_action &>/dev/null; then
    echo_error "no nemo action present"
  fi

  echo_step "Copy checksum_menu@pwlcz dir and .nemo_action files to ~/.local/share/nemo/actions/"
  rsync -av actions/ "${HOME}/.local/share/nemo/actions/"
  
  echo_step "Create submenu \"checksum\" in context menu"
  cp "${HOME}/.config/nemo/actions-tree.json" "${HOME}/.config/nemo/actions-tree.json.old"
  echo "Moved previous context menu file ${HOME}/.config/nemo/actions-tree.json
        to ${HOME}/.config/nemo/actions-tree.json.old"
  add_nemo_submenu "test" ./actions/*.nemo_action

}

main "$@"
