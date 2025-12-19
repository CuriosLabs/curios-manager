#!/usr/bin/env bash

#------------- Apps menu
app_menu() {
  local APP_MENU
  APP_MENU=$(gum choose --header "Select an option:" "󰣆 Apps menu" "󱓞 Launcher" " Store (Flatpak)" " Back")
  case $APP_MENU in
  "󰣆 Apps menu")
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
  " Back")
    main_menu
    ;;
  esac
}
