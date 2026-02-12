#!/usr/bin/env bash

search_new_package() {
  echo -e "Find a package by name:"
  SEARCH_NAME=$(gum input --placeholder="web browser")
  PKGS_LIST=$(nix-search --channel "$VERSION_ID" --json "$SEARCH_NAME")
  CHOSEN_PKG=$(echo "$PKGS_LIST" | jq -r '. | "\(.package_attr_name)\t\(.package_pversion)\t\(.package_description)"' | gum choose --header "Choose a package to install:")
  if [ -z "$CHOSEN_PKG" ]; then
    echo -e "${YELLOW}No package selected.${NC}"
    app_menu
  fi
  PKG_NAME=$(echo "$CHOSEN_PKG" | cut -f1)
  echo "$PKG_NAME"
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
