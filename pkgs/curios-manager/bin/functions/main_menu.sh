#!/usr/bin/env bash

#------------- Main menu
main_menu() {
  # Startup menu choice
  local MAIN_MENU
  local CURRENT_KEYBOARD
  local DOTFILES_VERSION
  local HOME_DIR
  local SETTINGS_FILE
  local SETTINGS_LAST_MOD
  local SKEL_DIR
  MAIN_MENU=$(gum choose --header "Select an option:" "󰀻 Applications" \
    " Update" \
    " Upgrade" \
    "󱘸 Backup" \
    " System" \
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
    gum spin --spinner dot --title "Deleting oldest generations..." --show-error -- sudo nix-collect-garbage --delete-older-than 7d
    status=$?
    if [ $status -ne 0 ]; then
      echo -e "${RED}Nix garbage collector failed!${NC}"
      exit 1
    fi
    gum spin --spinner dot --title "Upgrading packages..." --show-error -- sudo nixos-rebuild switch --upgrade --cores 0 --max-jobs auto
    status=$?
    if [ $status -ne 0 ]; then
      echo -e "${RED}Nix packages upgrade failed!${NC}"
      exit 1
    fi
    gum spin --spinner dot --title "Upgrading Nix flakes..." --show-error -- nix profile upgrade --all
    status=$?
    if [ $status -ne 0 ]; then
      echo -e "${RED}Nix flakes upgrade failed!${NC}"
      exit 1
    fi
    # Check if a reboot is necessary
    nix_generations
    echo -e "Latest update: ${LIST_GEN_DATE} - Kernel: ${LIST_GEN_KERNEL}"
    reboot_check
    ;;
  " Upgrade")
    DOTFILES_VERSION=$(curios-dotfiles --version)
    HOME_DIR="/home/*/"
    SKEL_DIR="/etc/skel/"
    CURRENT_KEYBOARD=$(nixos-option curios.system.keyboard | sed -n '/^Value:/{n;p;}' | tr -d '" ')
    sudo curios-update --upgrade
    status=$?
    # Updating dotfiles
    if [[ $(curios-dotfiles --version) != "$DOTFILES_VERSION" ]]; then
      # curios-dotfiles has been updated. We re-launch it.
      echo -e "${GREEN}Updating CuriOS dotfiles...${NC}"
      for DIR in $HOME_DIR; do
        if [[ -d "$DIR" && "$DIR" != */lost+found/ ]]; then
          OWNER=$(stat -c '%U' "$DIR")
          sudo -u "$OWNER" curios-dotfiles --lang "$CURRENT_KEYBOARD" "$DIR"
        fi
      done
      sudo mkdir -p "$SKEL_DIR"
      sudo curios-dotfiles --lang "$CURRENT_KEYBOARD" "$SKEL_DIR"
    fi
    if [ $status -eq 2 ]; then
      echo -e "A new CuriOS system was installed - ${YELLOW}You should REBOOT now${NC}."
      echo -e "${BLUE}Please${NC} ensure that all other applications are properly closed."
      gum confirm "Reboot now:" && systemctl reboot
    fi
    ;;
  "󱘸 Backup")
    backup_menu
    ;;
  " System")
    system_menu
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
    if [ ! -d /run/current-system/sw/share/themes/curios/ ]; then
      echo -e "${RED}Themes folder not found!${NC}"
    else
      themes_menu
    fi
    ;;
  "? Help")
    help_menu
    ;;
  " About")
    nix_generations
    echo -e "${VARIANT} ${GREY}(${VARIANT_ID})${NC} - based on ${PRETTY_NAME}"
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
