#!/usr/bin/env bash

#------------- System menu
system_menu() {
  local SETTINGS_FILE
  local SETTINGS_LAST_MOD
  local SYSTEM_MENU
  SYSTEM_MENU=$(gum choose " Shutdown" " Reboot" " Lock session" "󱃶 Process Management" "󰋊 Disk infos" " Settings (manual edit)" " Firmware" " Info" " Back")
  case $SYSTEM_MENU in
  " Shutdown")
    #sudo shutdown -P now
    cosmic-osd shutdown
    exit 0
    ;;
  " Reboot")
    #sudo reboot now
    cosmic-osd restart
    exit 0
    ;;
  " Lock session")
    loginctl lock-session
    ;;
  "󱃶 Process Management")
    btop
    system_menu
    ;;
  "󰋊 Disk infos")
    disk_menu
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
    system_menu
    ;;
  " Firmware")
    gum spin --spinner globe --title "Refreshing firmware metadata..." --show-error -- fwupdmgr refresh --force
    DEVICES_UPDATE=$(fwupdmgr --json get-updates)
    if [[ $(echo "$DEVICES_UPDATE" | jq -r '.Devices | length') -ge 1 ]]; then
      echo -e "The following devices can be upgraded:"
      echo ""
      echo "$DEVICES_UPDATE" | jq -c '.Devices.[]' | while read -r item; do
        DeviceName=$(echo "$item" | jq -r '.Name')
        DeviceSummary=$(echo "$item" | jq -r '.Summary')
        DeviceVendor=$(echo "$item" | jq -r '.Vendor')
        #DeviceID=$(echo "$item" | jq -r '.DeviceId')
        echo -e "- ${GREEN}$DeviceName${NC} (${BLUE}$DeviceVendor${NC}) [$DeviceSummary]"
      done
      echo ""
      #gum confirm "Would you like to update all devices now ?" && sudo whoami 1>/dev/null && gum spin --spinner dot --title "Updating firmware..." --show-error -- sudo fwupdmgr update
      gum confirm "Would you like to update all devices now ?" && sudo fwupdmgr update
    else
      echo -e "${GREEN}Nothing to update.${NC}"
    fi
    system_menu
    ;;
  " Info")
    fastfetch
    system_menu
    ;;
  " Back")
    main_menu
    ;;
  esac
}
