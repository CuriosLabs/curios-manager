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

#------------- Apps menu
app_menu() {
  local APP_MENU
  APP_MENU=$(gum choose --header "Select an option:" "󰣆 Applications menu" "󱓞 Launcher" " Store (Flatpak)" " Add a new package" " Back")
  case $APP_MENU in
  "󰣆 Applications menu")
    cosmic-app-library
    exit 0
    ;;
  "󱓞 Launcher")
    cosmic-launcher
    exit 0
    ;;
  " Store (Flatpak)")
    cosmic-store </dev/null &>/dev/null &
    sleep 2
    #exit 0
    ;;
  " Add a new package")
    search_new_package
    app_menu
    ;;
  " Back")
    main_menu
    ;;
  esac
}
