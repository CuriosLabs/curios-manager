#!/usr/bin/env bash

#------------- Help menu
help_menu() {
  local HELP_MENU
  HELP_MENU=$(gum choose --header "Open a new browser window with:" " Shortcuts" "󰄄 CuriOS" "󰄄 CuriOS - report a bug" " NixOS Wiki" " NixOS forum" " NixOS manual" " Back")
  case $HELP_MENU in
  " Shortcuts")
    cosmic-settings keyboard 2>/dev/null
    ;;
  "󰄄 CuriOS")
    if ! xdg-open "https://github.com/CuriosLabs/CuriOS"; then
      echo -e "${RED}Failed to open URL. Is a web browser installed?${NC}"
    fi
    ;;
  "󰄄 CuriOS - report a bug")
    if ! xdg-open "https://github.com/CuriosLabs/CuriOS/issues"; then
      echo -e "${RED}Failed to open URL. Is a web browser installed?${NC}"
    fi
    ;;
  " NixOS Wiki")
    if ! xdg-open "https://wiki.nixos.org/wiki/NixOS_Wiki"; then
      echo -e "${RED}Failed to open URL. Is a web browser installed?${NC}"
    fi
    ;;
  " NixOS forum")
    if ! xdg-open "https://discourse.nixos.org/"; then
      echo -e "${RED}Failed to open URL. Is a web browser installed?${NC}"
    fi
    ;;
  " NixOS manual")
    if ! xdg-open "https://nixos.org/manual/nixos/stable/"; then
      echo -e "${RED}Failed to open URL. Is a web browser installed?${NC}"
    fi
    ;;
  " Back")
    main_menu
    ;;
  esac
}

