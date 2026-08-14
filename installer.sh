#!/bin/bash
set -euo pipefail

function echo_error() {
  echo -e "\e[31m$*\e[0m" >&2 # Red
}

function echo_ok() {
  echo -e "\e[1;32m$*\e[0m" # Bold Green  
}

function echo_step() {
  local ARROW="\e[34m==>\e[0m" # Blue
  echo -e "${ARROW} \e[1m$*\e[0m" # Bold 
}

check_dependencies() {
  local required=(bash zenity rsync xclip jq)
  local checksum_tools=(md5sum sha1sum sha224sum sha256sum sha384sum sha512sum)
  local missing=()

  for tool in "${required[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done

  for tool in "${checksum_tools[@]}"; do
    if ! command -v "$tool" &>/dev/null; then
      missing+=("$tool")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo_error "Missing required dependencies: ${missing[*]}"
    echo_error "Please install them and run the installer again."
    exit 1
  fi
}

copy_actions() {
  local dest_dir="${HOME}/.local/share/nemo/actions"
  mkdir -p "$dest_dir"

  if command -v rsync &>/dev/null; then
    rsync -qa actions/ "${dest_dir}/"
  else
    cp -a actions/. "${dest_dir}/"
  fi
}

add_nemo_submenu() {
  local submenu_name="$1"
  shift

  local json_file="${HOME}/.config/nemo/actions-tree.json"

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

  if jq -e --arg name "$submenu_name" 'any(.toplevel[]; .uuid == $name)' "$json_file" &>/dev/null; then
    jq \
      --arg name "$submenu_name" \
      --argjson children "$children" \
      '.toplevel |= map(
        if .uuid == $name then
          . + {
            "uuid": $name,
            "type": "submenu",
            "user-label": $name,
            "user-icon": "checkbox-checked-symbolic",
            "accelerator": null,
            "children": $children
          }
        else
          .
        end
      )' \
      "$json_file" > "$tmp_file"
  else
    jq \
      --arg name "$submenu_name" \
      --argjson children "$children" \
      '.toplevel += [{
        "uuid": $name,
        "type": "submenu",
        "user-label": $name,
        "user-icon": "checkbox-checked-symbolic",
        "accelerator": null,
        "children": $children
      }]' \
      "$json_file" > "$tmp_file"
  fi

  if [[ -s "$tmp_file" ]]; then
    mv "$tmp_file" "$json_file"
    echo_ok "Submenu \"${submenu_name}\" successfully added to ${json_file}"
    echo_ok 'Run "nemo -q" to restart the file manager and apply changes.'
  else
    echo_error "jq failed to process the JSON. Your original file is untouched."
    rm "$tmp_file"
  fi
}

function install_translation() {
  if ! command -v msgfmt &>/dev/null; then
    echo_error "Warning: 'msgfmt' (gettext) is not installed. Skipping translations."
  else
    for po_file in actions/checksum_menu@pwlcz/po/*.po; do
        lang=$(basename "$po_file" .po)
        
        target_dir="$HOME/.local/share/locale/$lang/LC_MESSAGES"
        mkdir -p "$target_dir"
        
        msgfmt "$po_file" -o "$target_dir/checksum_menu@pwlcz.mo"
        
        echo "Installed translation for: $lang"
    done
  fi
}

function main() {
  cd "$(dirname "$0")"

  if [[ ! -d "./actions/checksum_menu@pwlcz" ]]; then
    echo_error "Missing script directory."
    exit 1
  fi

  if ! ls actions/*.nemo_action &>/dev/null; then
    echo_error "No Nemo actions are present."
    exit 1
  fi

  check_dependencies

  echo_step "Copy checksum_menu@pwlcz dir and .nemo_action files to ~/.local/share/nemo/actions/"
  copy_actions

  echo_step "Installing translations..."
  install_translation

  echo_step "Create submenu \"checksum\" in context menu"
  if [[ -f "${HOME}/.config/nemo/actions-tree.json" ]]; then
    cp "${HOME}/.config/nemo/actions-tree.json" "${HOME}/.config/nemo/actions-tree.json.old"
    echo "Moved previous context menu file ${HOME}/.config/nemo/actions-tree.json to ${HOME}/.config/nemo/actions-tree.json.old"
  else
    echo "No existing context menu file found; a new one will be created."
  fi

  add_nemo_submenu "Checksum" ./actions/*.nemo_action
}

main "$@"
