#!/usr/bin/env bash

# Fetch NixOS option descriptions for all boolean paths in modules.json
# This helper is designed to be called by _curios_apps_menu via gum spin.
#
# Usage:
#   fetch_app_descriptions.sh <nix_expr_file>
#
# Reads JSON objects {path: [...], status: bool} from stdin,
# outputs lines in the format: display|path_json|status

set -euo pipefail

main() {
  local NIX_EXPR_FILE
  NIX_EXPR_FILE="${1:-}"

  if [ -z "$NIX_EXPR_FILE" ] || [ ! -f "$NIX_EXPR_FILE" ]; then
    echo "Error: Nix expression file not provided or missing." >&2
    exit 1
  fi

  local ALL_DESCRIPTIONS
  ALL_DESCRIPTIONS=$(nix eval --json --impure --file "$NIX_EXPR_FILE" 2>/dev/null || true)

  while read -r item; do
    local path_arr status dot_path description category setting display
    path_arr=$(echo "$item" | jq -c '.path')
    status=$(echo "$item" | jq -r '.status')
    dot_path=$(echo "$item" | jq -r '.path | join(".")')

    if [ -n "$ALL_DESCRIPTIONS" ]; then
      description=$(echo "$ALL_DESCRIPTIONS" | jq -r --arg p "$dot_path" '.[$p] // empty')
    else
      description=""
    fi

    # Format the display name: (category) setting
    # If the path ends in .enable, we strip it to show the app name as the setting
    if [[ "$dot_path" == *".enable" ]]; then
      local base_path="${dot_path%.enable}"
      if [[ "$base_path" == *"."* ]]; then
        category="${base_path%.*}"
        setting="${base_path##*.}"
        display="($category) $setting"
      else
        display="$base_path"
      fi
    elif [[ "$dot_path" == *"."* ]]; then
      category="${dot_path%.*}"
      setting="${dot_path##*.}"
      display="($category) $setting"
    else
      display="$dot_path"
    fi

    if [ -n "$description" ] && [ "$description" != "null" ]; then
      display="$display - $description"
    fi

    # Replace commas in display name to avoid breaking gum choose --selected
    display="${display//,/;}"

    echo "$display|$path_arr|$status"
  done
}

main "$@"
