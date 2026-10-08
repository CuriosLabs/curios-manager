#!/usr/bin/env bash

#------------- Main menu
main_menu() {
  # Startup menu choice
  local MAIN_MENU
  local SETTINGS_FILE
  local SETTINGS_LAST_MOD
  # --height forces showing all items (11 choices + header) unless terminal is too small
  MAIN_MENU=$(gum choose --height 14 --header "Select an option:" "󰀻 Applications" \
    " Update" \
    " Upgrade" \
    "󱘸 Backup" \
    " System" \
    "󰌾 Security" \
    " Settings (manual edit)" \
    " Themes" \
    "? Help" \
    " About" \
    "󰈆 Exit")
  #echo "Your choice is: $MAIN_MENU"
  case $MAIN_MENU in
  "󰀻 Applications")
    app_menu
    ;;
  " Update")
    sudo whoami 1>/dev/null # Force prompt for sudo password now
    gum spin --spinner dot --title "Updating packages..." --show-error -- sudo curios-update --update
    nixos-rebuild list-generations | head -n 6
    reboot_check
    ;;
  " Upgrade")
    sudo whoami 1>/dev/null # Force prompt for sudo password now
    gum spin --spinner dot --title "Upgrading CuriOS..." --show-error -- sudo curios-update --upgrade
    nixos-rebuild list-generations | head -n 6
    reboot_check
    ;;
  "󱘸 Backup")
    backup_menu
    ;;
  " System")
    system_menu
    ;;
  "󰌾 Security")
    security_menu
    ;;
  " Settings (manual edit)")
    SETTINGS_FILE="/etc/nixos/settings.nix"
    SETTINGS_LAST_MOD=$(stat -c %Y $SETTINGS_FILE)
    sudo "$EDITOR" $SETTINGS_FILE
    if [[ $(stat -c %Y $SETTINGS_FILE) -gt $SETTINGS_LAST_MOD ]]; then
      # Settings have changed, updating system.
      sudo whoami 1>/dev/null # Force prompt for sudo password now
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo nixos-rebuild switch --cores 0 --max-jobs auto
      nix_generations
      echo -e "Latest update: ${LIST_GEN_DATE} - Kernel: ${LIST_GEN_KERNEL}"
      reboot_check
    fi
    ;;
  " Themes")
    themes_menu
    ;;
  "? Help")
    help_menu
    ;;
  " About")
    nix_generations
    echo -e "${VARIANT} ${GREY}(${VARIANT_ID})${NC} - based on ${BLUE}${PRETTY_NAME}${NC}"
    print_core_info
    echo -e "Latest update: ${LIST_GEN_DATE} - Kernel: ${LIST_GEN_KERNEL}"
    echo -e "CuriOS manager version: $SCRIPT_VERSION"
    echo -e "Visit ${BLUE}${CURIOS_SRC_URL}${NC}"
    ;;
  "󰈆 Exit")
    echo -e "${GREEN}Program exited...${NC}"
    exit 0
    ;;
  esac
  main_menu # self loop
}
