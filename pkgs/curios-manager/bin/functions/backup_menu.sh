#!/usr/bin/env bash

#------------- various functions
var_exists() {
  if [[ -v "$1" ]]; then
    return 0
  else
    return 1
  fi
}

save_env_var() {
  local var_name="$1"
  # Indirect expansion to get the value of the variable
  local var_value="${!1}"
  local env_file="$HOME/.env"

  # Check if the variable is set
  if [ -z "$var_value" ]; then
    echo -e "${RED}Error:${NC} Variable '$var_name' is not set or empty." >&2
    return 1
  fi

  # Create the file if it doesn't exist
  touch "$env_file"

  # Check if the variable already exists in the file
  if grep -q "^$var_name=" "$env_file"; then
    # Update the existing variable
    sed -i "s|^$var_name=.*|$var_name=\"$var_value\"|" "$env_file"
  else
    # Append the new variable
    echo "$var_name=\"$var_value\"" >>"$env_file"
  fi

  echo -e "${GREEN}Variable '$var_name' saved to $env_file.${NC}"
}

#------------- Setup functions
backup_setup() {
  #local choosen_repo_type
  local usb_drives
  local usb_choosen_drive
  local BACKUP_SETUP_MENU

  if var_exists RESTIC_REPOSITORY; then
    echo -e "${BLUE}Backup repository already set to:${NC} ${RESTIC_REPOSITORY}"
  else
    echo -e "${YELLOW}No backup repos found.${NC}"
    BACKUP_SETUP_MENU=$(gum choose --header "Choose a backup repository type:" " Local (USB)" " S3 server (Amazon or MinIO)" " Back")
    case $BACKUP_SETUP_MENU in
    " Local (USB)")
      usb_drives=$(fd --type d --max-depth 1 "" /run/media/"$USER"/)
      usb_choosen_drive=$(echo "$usb_drives" | gum choose --header "Select a USB drive:")
      RESTIC_REPOSITORY="${usb_choosen_drive}$(hostname)-${USER}"
      mkdir -p "$RESTIC_REPOSITORY"
      export RESTIC_REPOSITORY
      save_env_var RESTIC_REPOSITORY
      echo "Choosen drive: ${RESTIC_REPOSITORY}"
      ;;
    " S3 server (Amazon or MinIO)")
      echo "TBD"
      backup_setup
      ;;
    " Back")
      backup_menu
      ;;
    esac
  fi
}

#------------- Backup menu
backup_menu() {
  local BACKUP_MENU

  if ! available restic; then
    echo -e "${RED}restic command not found!${NC}"
    main_menu
  fi

  BACKUP_MENU=$(gum choose --header "Select an option:" "󱘸 Sync now" "󱘪 Restore" "󱙌 Setup" " Back")
  case $BACKUP_MENU in
  "󱘸 Sync now")
    if var_exists RESTIC_REPOSITORY; then
      echo "Current repo: ${RESTIC_REPOSITORY}"
    fi
    echo "TBD"
    backup_menu
    ;;
  "󱘪 Restore")
    echo "TBD"
    backup_menu
    ;;
  "󱙌 Setup")
    backup_setup
    ;;
  " Back")
    main_menu
    ;;
  esac
}
