#!/usr/bin/env bash

#------------- System menu
system_menu() {
  local SYSTEM_MENU
  SYSTEM_MENU=$(gum choose " Shutdown" " Reboot" " Lock session" \
    "󱃶 Process Management" \
    "󱃶 Process Management (GPU)" \
    "󰩠 Network Connections" \
    "󰋊 Disk infos" \
    " Firmware" \
    " Info" \
    " Back")
  case $SYSTEM_MENU in
  " Shutdown")
    #cosmic-osd shutdown
    systemctl poweroff
    exit 0
    ;;
  " Reboot")
    #cosmic-osd restart
    systemctl reboot
    exit 0
    ;;
  " Lock session")
    loginctl lock-session
    ;;
  "󱃶 Process Management")
    btop
    system_menu
    ;;
  "󱃶 Process Management (GPU)")
    if ! available nvtop; then
      echo -e "${RED}nvtop command not found!${NC} A configured GPU is required."
    else
      nvtop
    fi
    system_menu
    ;;
  "󰩠 Network Connections")
    snitch
    system_menu
    ;;
  "󰋊 Disk infos")
    disk_menu
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
