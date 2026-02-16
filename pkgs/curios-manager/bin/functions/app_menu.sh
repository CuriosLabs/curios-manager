#!/usr/bin/env bash

add_package_to_settings() {
  local PKG="$1"
  local SETTINGS_FILE="/etc/nixos/settings.nix"

  if [ -z "$PKG" ]; then
    return
  fi

  # Check if package is already in the list
  if grep -q "pkgs.$PKG" "$SETTINGS_FILE"; then
    echo -e "${YELLOW}Package pkgs.$PKG is already present in $SETTINGS_FILE.${NC}"
    return
  fi

  # Add the package to the environment.systemPackages list.
  # We find the line with environment.systemPackages = [ and append after it.
  if sudo sed -i "/environment.systemPackages = \[/a \    pkgs.$PKG" "$SETTINGS_FILE"; then
    echo -e "${GREEN}Package pkgs.$PKG added to $SETTINGS_FILE${NC}"
    gum spin --spinner dot --title "Installing package..." --show-error -- sudo nixos-rebuild switch --upgrade --cores 0 --max-jobs auto
    status=$?
    if [ $status -ne 0 ]; then
      echo -e "${RED}Nix packages install failed!${NC}"
      exit 1
    fi
    reboot_check
  else
    echo -e "${RED}Failed to add package pkgs.$PKG to $SETTINGS_FILE.${NC}"
  fi
}

search_new_package() {
  echo -e "Find a package by name:"
  SEARCH_NAME=$(gum input)

  if [ -z "$SEARCH_NAME" ]; then
    echo -e "${YELLOW}Package name could not be empty.${NC}"
    app_menu
  fi

  PKGS_LIST=$(nix-search --channel "$VERSION_ID" --json "$SEARCH_NAME")
  CHOSEN_PKG=$(echo "$PKGS_LIST" | jq -r '. | "\(.package_attr_name)\t\(.package_pversion)\t\(.package_description)"' | gum choose --limit=1 --header "Choose a package to install:")

  if [ -z "$CHOSEN_PKG" ]; then
    echo -e "${YELLOW}No package selected.${NC}"
    app_menu
  fi

  PKG_NAME=$(echo "$CHOSEN_PKG" | cut -f1)
  add_package_to_settings "$PKG_NAME"
}

curios_apps_menu() {
  local SETTINGS_FILE="/etc/nixos/modules.json"
  if [ ! -f "$SETTINGS_FILE" ]; then
    echo -e "${RED}Settings file $SETTINGS_FILE not found!${NC}"
    return
  fi

  # 1. Read all boolean paths and their current values
  local BOOLS_DATA
  BOOLS_DATA=$(jq -c 'paths(type == "boolean") as $p | {path: $p, status: getpath($p), description: (getpath($p[:-1]) | .description // "")}' "$SETTINGS_FILE" 2>/dev/null)

  if [ -z "$BOOLS_DATA" ]; then
    echo -e "${YELLOW}No configurable boolean settings found in $SETTINGS_FILE.${NC}"
    return
  fi

  local GUM_OPTIONS=()
  local GUM_SELECTED=()
  declare -A DISPLAY_TO_PATH
  declare -A DISPLAY_TO_STATUS

  local item
  local path_arr
  local status
  local description
  local dot_path
  local category
  local setting
  local display

  while read -r item; do
    path_arr=$(echo "$item" | jq -c '.path')
    status=$(echo "$item" | jq -r '.status')
    description=$(echo "$item" | jq -r '.description')
    dot_path=$(echo "$item" | jq -r '.path | join(".")')

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

    GUM_OPTIONS+=("$display")
    [ "$status" == "true" ] && GUM_SELECTED+=("$display")
    DISPLAY_TO_PATH["$display"]="$path_arr"
    DISPLAY_TO_STATUS["$display"]="$status"
  done <<<"$BOOLS_DATA"

  local SELECTED_STR
  SELECTED_STR=$(
    IFS=,
    echo "${GUM_SELECTED[*]}"
  )

  # 2. Present the menu
  local CHOICES
  CHOICES=$(printf "%s\n" "${GUM_OPTIONS[@]}" | gum choose --no-limit --selected="$SELECTED_STR" --header "Enable/Disable CuriOS Apps (Space to toggle):")
  local RET=$?

  if [ $RET -ne 0 ]; then
    return
  fi

  # 3. Update the JSON file if changes occurred
  local CHANGED=0
  local jq_cmd="."
  local old_status
  local new_status
  local path_arr_val

  for display in "${GUM_OPTIONS[@]}"; do
    path_arr_val="${DISPLAY_TO_PATH["$display"]}"
    old_status="${DISPLAY_TO_STATUS["$display"]}"
    new_status="false"

    # Fix: use -qFx (lowercase x) and -- to ensure pattern is treated literally
    if echo "$CHOICES" | grep -qFx -- "$display"; then
      new_status="true"
    fi

    if [ "$old_status" != "$new_status" ]; then
      jq_cmd="$jq_cmd | setpath($path_arr_val; $new_status)"
      CHANGED=1
    fi
  done

  if [ $CHANGED -eq 1 ]; then
    echo -e "${BLUE}Saving settings to $SETTINGS_FILE...${NC}"
    if jq "$jq_cmd" "$SETTINGS_FILE" | sudo tee "$SETTINGS_FILE" >/dev/null; then
      echo -e "${GREEN}Settings updated!${NC}"
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo nixos-rebuild switch --cores 0 --max-jobs auto
      reboot_check
    else
      echo -e "${RED}Failed to update $SETTINGS_FILE!${NC}"
    fi
  else
    echo -e "${YELLOW}Nothing to change.${NC}"
  fi
}

#------------- Apps menu
app_menu() {
  local APP_MENU
  APP_MENU=$(gum choose --header "Select an option:" "󰄬 Install/Uninstall CuriOS Apps" " Find/Add a NixOS package" "󰣆 Applications menu" "󱓞 Launcher" " Open Flatpak Store" " Back")
  case $APP_MENU in
  " Find/Add a NixOS package")
    search_new_package
    app_menu
    ;;
  "󰄬 Install/Uninstall CuriOS Apps")
    curios_apps_menu
    app_menu
    ;;
  "󰣆 Applications menu")
    cosmic-app-library
    exit 0
    ;;
  "󱓞 Launcher")
    cosmic-launcher
    exit 0
    ;;
  " Open Flatpak Store")
    cosmic-store </dev/null &>/dev/null &
    sleep 2
    #exit 0
    ;;
  " Back")
    main_menu
    ;;
  esac
}
