#!/usr/bin/env bash

#------------- various functions
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
  chmod 0600 "$env_file"

  # Check if the variable already exists in the file
  if grep -q "^$var_name=" "$env_file"; then
    # Update the existing variable
    sed -i "s|^$var_name=.*|$var_name=\"$var_value\"|" "$env_file"
  else
    # Append the new variable
    echo "$var_name=\"$var_value\"" >>"$env_file"
  fi

  #echo -e "${GREEN}Variable '$var_name' saved to $env_file.${NC}"
  echo -e "${GREEN}Setting saved.${NC}"
}

backup_set_password() {
  local repo_passwd
  local repo_passwd_confirm

  echo -e "${BLUE}Setting a backup password${NC} - 6 characters length minimum."
  echo -e "${YELLOW}Use Ctrl+Shift+V to paste.${NC}"
  #echo -e "Please note that knowledge of your password is required to access\nthe repository. Losing your password means that your data is\n${RED}irrecoverably lost!${NC}"
  repo_passwd=$(gum input --password --char-limit=50 --placeholder="Enter password...")
  repo_passwd_confirm=$(gum input --password --char-limit=50 --placeholder="Confirm password...")
  if [ "${#repo_passwd}" -le 5 ]; then
    echo -e "${RED}Password is too short!${NC} It must be at least 6 characters long."
    return 1
  elif [[ "$repo_passwd" != "$repo_passwd_confirm" ]]; then
    echo -e "${RED}Password mismatch!${NC}"
    return 1
  fi
  gum confirm --affirmative="I understand" --negative="Cancel" \
    $'Please note that knowledge of your password is required to access the backup repository.\nLosing your password means that your data is irrecoverably lost!' || return 1
  printf "%s" "$repo_passwd" | secret-tool store --label="Backup password" restic password
  export RESTIC_PASSWORD_COMMAND="secret-tool lookup restic password"
}

#------------- Setup functions
backup_setup() {
  #local choosen_repo_type
  local usb_drives
  local usb_choosen_drive
  local BACKUP_SETUP_MENU
  local aws_access_key_id
  local aws_secret_access_key
  local s3_bucket_url

  if [[ -v RESTIC_REPOSITORY ]]; then
    echo -e "${YELLOW}WARNING!${NC} ${BLUE}A backup repository already exist:${NC} ${RESTIC_REPOSITORY}"
    gum confirm "Do you want to replace it?" --default=false || backup_menu
  fi

  if [[ ! -v RESTIC_PASSWORD_COMMAND ]]; then
    export RESTIC_PASSWORD_COMMAND="secret-tool lookup restic password"
  fi

  BACKUP_SETUP_MENU=$(gum choose --header "Choose a backup repository type:" " Local (USB)" " S3 server (Amazon AWS)" " S3-compatible server (MinIO, RustFS...)" "󱇶 Google Cloud Storage" " Back")
  case $BACKUP_SETUP_MENU in
  " Local (USB)")
    # List USB drive mounted
    if [ ! -d /run/media/"$USER" ]; then
      echo -e "${RED}No media file mounted.${NC}"
      return 1
    fi
    # TODO: automount USB drive check for /dev/sdX and udiskctl them
    # TODO: format drive if not in a compatible filesystem.
    usb_drives=$(fd --type d --max-depth 1 "" /run/media/"$USER"/)
    # Check if any was found
    if [ -z "$usb_drives" ]; then
      echo -e "${RED}No USB drive found in${NC} /run/media/$USER/"
      echo -e "Make sure that a USB drive is plugged and mounted."
      return 1
    fi
    # TODO: Show USB drive total space in Go. Check if free space is enough.
    # Let user choose a USB drive
    usb_choosen_drive=$(echo "$usb_drives" | gum choose --header "Select a USB drive:")
    if [ -z "$usb_choosen_drive" ]; then
      echo -e "${YELLOW}No USB drive selected.${NC}"
      return 1
    fi
    # ask user for repo password
    if ! backup_set_password; then
      echo -e "${RED}Password not saved.${NC}"
      return 1
    fi
    # Make repo directory
    RESTIC_REPOSITORY="${usb_choosen_drive}$(hostname)-${USER}"
    mkdir -p "$RESTIC_REPOSITORY"
    export RESTIC_REPOSITORY
    if gum spin --spinner dot --title "Checking backup configuration..." --show-error -- restic -r "$RESTIC_REPOSITORY" cat config 1>/dev/null; then
      echo -e "${YELLOW}Repository is already initialized.${NC}"
      save_env_var RESTIC_REPOSITORY
    else
      if gum spin --spinner dot --title "Initializing backup repository..." --show-error -- restic init; then
        save_env_var RESTIC_REPOSITORY
        echo -e "${BLUE}Backup repository set to:${NC} ${RESTIC_REPOSITORY}"
      else
        unset RESTIC_REPOSITORY
        return 1
      fi
    fi
    backup_menu
    ;;
  " S3 server (Amazon AWS)")
    echo "TBD"
    backup_setup
    ;;
  " S3-compatible server (MinIO, RustFS...)")
    echo -e "Provide S3 server access key information:"
    echo -e "${YELLOW}Use Ctrl+Shift+V to paste.${NC}"
    aws_access_key_id=$(gum input --placeholder="Access Key")
    if [ -z "$aws_access_key_id" ]; then
      echo -e "${RED}You must provide a valid access key.${NC}"
      return 1
    fi
    export AWS_ACCESS_KEY_ID=$aws_access_key_id
    aws_secret_access_key=$(gum input --placeholder="Secret Key")
    if [ -z "$aws_secret_access_key" ]; then
      echo -e "${RED}You must provide a valid secret key.${NC}"
      return 1
    fi
    export AWS_SECRET_ACCESS_KEY=$aws_secret_access_key

    echo -e "Provide S3 server bucket URL:"
    s3_bucket_url=$(gum input --placeholder="http://localhost:9000/bucket_name")
    if [ -z "$s3_bucket_url" ]; then
      echo -e "${RED}You must provide a valid bucket URL.${NC}"
      return 1
    fi
    RESTIC_REPOSITORY="s3:$s3_bucket_url"
    if gum spin --spinner dot --title "Checking backup configuration..." --show-error -- restic -r "$RESTIC_REPOSITORY" cat config 1>/dev/null; then
      echo -e "${YELLOW}Repository is already initialized.${NC}"
      save_env_var RESTIC_REPOSITORY
      save_env_var AWS_ACCESS_KEY_ID
      save_env_var AWS_SECRET_ACCESS_KEY
    else
      if gum spin --spinner dot --title "Initializing backup repository..." --show-error -- restic init -r "$RESTIC_REPOSITORY"; then
        save_env_var RESTIC_REPOSITORY
        save_env_var AWS_ACCESS_KEY_ID
        save_env_var AWS_SECRET_ACCESS_KEY
        echo -e "${BLUE}Backup repository set to:${NC} ${RESTIC_REPOSITORY}"
      else
        unset RESTIC_REPOSITORY
        return 1
      fi
    fi
    backup_menu
    ;;
  "󱇶 Google Cloud Storage")
    echo "TBD"
    backup_setup
    ;;
  # TODO: Backblaze B2 cloud storage.
  " Back")
    backup_menu
    ;;
  esac
}

#------------- Backup menu
backup_menu() {
  local BACKUP_MENU
  local backup_exclude_file="$HOME/.config/backup/excludes.txt"
  local SNAPSHOTS_LIST

  if ! available restic; then
    echo -e "${RED}restic command not found!${NC}"
    main_menu
  fi

  if ! available secret-tool; then
    echo -e "${RED}secret-tool command not found!${NC}"
    main_menu
  fi

  # Source env default file
  if [ -f "$HOME/.env" ]; then
    # shellcheck source=/home/datux/.env
    source "$HOME/.env"
  fi

  if [[ ! -v RESTIC_PASSWORD_COMMAND ]]; then
    export RESTIC_PASSWORD_COMMAND="secret-tool lookup restic password"
  fi

  # TODO: check if the repo is up / plugged ??

  if [ ! -f "$backup_exclude_file" ]; then
    # TODO: exclude ~/.local/state/nix/profiles/ - Steam games folder ??
    echo -e "Creating default backup exclude files..."
    dir=$(dirname "$backup_exclude_file")
    mkdir -p "$dir"
    touch "$backup_exclude_file"
    {
      echo "# Exclude common cache folders"
      echo "$HOME/.cache"
      echo "$HOME/.npm/_cacache"
      echo "cache"
      echo "Cache"
      echo "GPUCache"
      echo "*_cache"
      echo "# Exclude trash folder"
      echo "$HOME/.local/share/Trash"
      echo "# exclude iso files"
      echo "*.iso"
      echo "# Add custom folders or files to exclude here"
    } >>"$backup_exclude_file"
  fi

  BACKUP_MENU=$(gum choose --header "Select an option:" "󱘸 Backup now" "󱘪 Restore from backup" "󱙌 Setup your backup" "󱤢 Backup stats" " Back")
  case $BACKUP_MENU in
  "󱘸 Backup now")
    if [[ ! -v RESTIC_REPOSITORY ]]; then
      echo -e "${YELLOW}Backup parameters missing!${NC} Use Setup menu."
      backup_menu
    fi
    # TODO: follow symlinks ??
    gum spin --spinner dot --title "Creating new snapshot..." --show-error -- restic backup --skip-if-unchanged --one-file-system -r "$RESTIC_REPOSITORY" --exclude-file="$backup_exclude_file" "$HOME"
    gum spin --spinner dot --title "Removing old snapshots..." --show-error -- restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune -r "$RESTIC_REPOSITORY"
    gum spin --spinner dot --title "Checking repository health..." --show-error -- restic check -r "$RESTIC_REPOSITORY"
    backup_menu
    ;;
  "󱘪 Restore from backup")
    if [[ ! -v RESTIC_REPOSITORY ]]; then
      echo -e "${YELLOW}Backup parameters missing!${NC} Using Setup menu..."
      backup_setup
    fi
    if gum spin --spinner dot --title "Checking backup configuration..." --show-error -- restic -r "$RESTIC_REPOSITORY" cat config 1>/dev/null; then
      SNAPSHOTS_LIST=$(restic snapshots --json -r "$RESTIC_REPOSITORY")
      # Let user choose a snapshot
      CHOSEN_SNAPSHOT=$(echo "$SNAPSHOTS_LIST" | jq -r '(sort_by(.time) | reverse) | .[] | "\(.short_id)\t\(.time | .[0:16] | gsub("T"; " "))\t\((.summary.total_bytes_processed / (1024*1024*1024) * 100 | round) / 100)GiB\t\(.paths | join(" "))"' | gum choose --header "Choose a snapshot to restore")

      if [ -z "$CHOSEN_SNAPSHOT" ]; then
        echo -e "${YELLOW}No snapshot selected.${NC}"
        backup_menu
      fi

      SNAPSHOT_ID=$(echo "$CHOSEN_SNAPSHOT" | cut -f1)

      if gum confirm "Restore snapshot ${SNAPSHOT_ID} to ${HOME} ?"; then
        gum spin --spinner dot --title "Restoring..." --show-error -- restic restore "$SNAPSHOT_ID" --target "$HOME" -r "$RESTIC_REPOSITORY"
      else
        echo -e "${RED}Restoration canceled.${NC}"
      fi
    else
      echo -e "${RED}Backup configuration could not be read.${NC}"
    fi
    backup_menu
    ;;
  "󱙌 Setup your backup")
    backup_setup
    ;;
  "󱤢 Backup stats")
    if [[ ! -v RESTIC_REPOSITORY ]]; then
      echo -e "${YELLOW}Backup parameters missing!${NC} Use Setup menu."
      backup_menu
    fi
    restic stats -r "$RESTIC_REPOSITORY"
    restic snapshots --group-by host -r "$RESTIC_REPOSITORY"
    backup_menu
    ;;
  " Back")
    main_menu
    ;;
  esac
}
