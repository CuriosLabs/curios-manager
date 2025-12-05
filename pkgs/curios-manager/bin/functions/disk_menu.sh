#!/usr/bin/env bash

#------------- Disk menu
disk_menu() {
  local APP_MENU
  APP_MENU=$(gum choose --header "Select an option:" "󰋊 Disk usage" "󰋜 Home folder usage" " Root folder usage" "󰋊 Disk S.M.A.R.T health status" " Back")
  case $APP_MENU in
  "󰋊 Disk usage")
    duf -only-mp "/,/boot,/home"
    disk_menu
    ;;
  "󰋜 Home folder usage")
    dust -D "$HOME"
    disk_menu
    ;;
  " Root folder usage")
    sudo dust -D -X /home /
    disk_menu
    ;;
  "󰋊 Disk S.M.A.R.T health status")
    sudo smartctl -H -A /dev/disk/by-label/curiosystem
    disk_menu
    ;;
  " Back")
    main_menu
    ;;
  esac
}
