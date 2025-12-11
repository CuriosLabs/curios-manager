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
  local choosen_repo_type
  local BACKUP_SETUP_MENU
  if var_exists RESTIC_REPOSITORY; then
    echo -e "${BLUE}Backup repository found...${NC}"
  else
    echo -e "${YELLOW}No backup repos found.${NC}"
    BACKUP_SETUP_MENU=$(gum choose --header "Choose a backup repository type:" " Local (USB)" " S3 server (Amazon or MinIO)" " Back")
    case $BACKUP_SETUP_MENU in
    " Local (USB)")
      echo ""
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
  BACKUP_MENU=$(gum choose --header "Select an option:" "󱘸 Sync now" "󱘪 Restore" "󱙌 Setup" " Back")
  case $BACKUP_MENU in
  "󱘸 Sync now")
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
