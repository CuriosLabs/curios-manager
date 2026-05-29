#!/usr/bin/env bash

#------------- Security menu (U2F/FIDO2 YubiKey setup via pam_u2f + LUKS FIDO2)
# - PAM U2F: Requires curios.security.u2f.enable
# - LUKS FIDO2: Requires curios.security.luksFido2.enable (and a LUKS-encrypted system)
# Uses pamu2fcfg for login/sudo and systemd-cryptenroll for disk encryption.

_get_u2f_enabled() {
  # Check via curios-update as documented (it delegates to nixos-option internally).
  # This is the first verification step for the security/U2F feature.
  curios-update --nixos-option curios.security.u2f.enable 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "unknown"
}

security_menu() {
  local U2F_ENABLED
  U2F_ENABLED=$(_get_u2f_enabled)

  if [[ "$U2F_ENABLED" != "true" ]]; then
    echo -e "${YELLOW}U2F/FIDO2 authentication is currently DISABLED on this system.${NC}"
    echo -e "YubiKey login (for greetd, cosmic-greeter, login and sudo) will not work until enabled."
    echo ""

    if gum confirm "Enable U2F/FIDO2 authentication with YubiKey now?"; then
      echo -e "${BLUE}Enabling the security.u2f module...${NC}"
      gum spin --spinner dot --title "Enabling module.." --show-error -- sudo curios-update --update-module curios.security.u2f.enable true

      echo ""
      echo -e "${BLUE}Applying system configuration (nixos-rebuild). This can take several minutes...${NC}"
      echo -e "${YELLOW}You will be prompted for your sudo password if needed.${NC}"
      echo ""
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo curios-update --update

      # Re-check status after the update
      U2F_ENABLED=$(_get_u2f_enabled)
      if [[ "$U2F_ENABLED" == "true" ]]; then
        echo -e "${GREEN}✓ U2F/FIDO2 authentication is now enabled!${NC}"
      else
        echo -e "${YELLOW}Module was activated but the live status is not yet 'true'. A reboot may be required.${NC}"
      fi
      echo -e "${YELLOW}You may need to log out and log back in (or reboot) for the new PAM configuration to take full effect.${NC}"
      echo ""
      read -n 1 -s -r -p "Press any key to continue to the YubiKey registration menu..."
      echo ""
    else
      main_menu
      return
    fi
  fi

  if ! available pamu2fcfg; then
    echo -e "${RED}pamu2fcfg not found!${NC}"
    echo -e "This usually means ${BLUE}curios.security.u2f.enable${NC} is not active (or system not yet rebuilt)."
    echo -e "Enable the module and run a full system update, then retry."
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    main_menu
    return
  fi

  local SECURITY_MENU
  SECURITY_MENU=$(gum choose --header "YubiKey Security (PAM U2F + LUKS FIDO2) - Select an option:" \
    "󰌾 Register primary YubiKey (PAM login/sudo)" \
    "󰐕 Add additional YubiKey (PAM backup)" \
    "🔐 Enroll YubiKey for LUKS FIDO2 disk decryption" \
    " View current U2F keys file" \
    "󰙨 Test PAM authentication (pamtester)" \
    " Back")

  case $SECURITY_MENU in
  "󰌾 Register primary YubiKey (PAM login/sudo)")
    _register_u2f_key "primary"
    security_menu
    ;;
  "󰐕 Add additional YubiKey (PAM backup)")
    _register_u2f_key "additional"
    security_menu
    ;;
  "🔐 Enroll YubiKey for LUKS FIDO2 disk decryption")
    _enroll_luks_fido2
    security_menu
    ;;
  " View current U2F keys file")
    _view_u2f_keys
    security_menu
    ;;
  "󰙨 Test PAM authentication (pamtester)")
    _test_u2f_auth
    security_menu
    ;;
  " Back")
    main_menu
    ;;
  esac
}

_register_u2f_key() {
  local mode="$1" # "primary" or "additional"
  local u2f_dir="$HOME/.config/Yubico"
  local u2f_file="$u2f_dir/u2f_keys"

  mkdir -p "$u2f_dir"

  if [[ "$mode" == "primary" ]]; then
    if [[ -f "$u2f_file" ]]; then
      echo -e "${YELLOW}Warning:${NC} $u2f_file already exists for user $USER."
      echo -e "Continuing will ${RED}overwrite${NC} the existing primary registration."
      gum confirm "Overwrite existing U2F keys?" --default=false || return
    fi

    echo -e "${BLUE}Registering PRIMARY YubiKey for ${USER}${NC}"
    echo -e "Steps:"
    echo -e "  1. Insert your YubiKey"
    echo -e "  2. When the LED blinks, ${GREEN}touch the button / metal contact${NC}"
    echo -e "  3. The tool will output one line with the new credential"
    echo ""
    if gum confirm "YubiKey inserted and ready?"; then
      # pamu2fcfg prints touch instructions on stderr (visible), credential on stdout
      if pamu2fcfg >"$u2f_file"; then
        echo -e "${GREEN}✓ Primary YubiKey successfully registered!${NC}"
        echo -e "File: ${BLUE}$u2f_file${NC}"
        echo ""
        echo -e "${GREY}Recorded credential:${NC}"
        cat "$u2f_file"
        echo ""
        echo -e "${YELLOW}Note:${NC} If you recently enabled the U2F module, run a system update and re-login for PAM changes to apply."
      else
        echo -e "${RED}Registration failed.${NC}"
        echo -e "Make sure your YubiKey supports FIDO2/U2F (see https://www.yubico.com/products/identifying-your-yubikey/) and try again."
      fi
    fi
  else
    # additional key
    if [[ ! -f "$u2f_file" ]]; then
      echo -e "${RED}No existing $u2f_file found.${NC}"
      echo -e "Register a primary key first."
      read -n 1 -s -r -p "Press any key to continue..."
      return
    fi

    echo -e "${BLUE}Adding ADDITIONAL YubiKey for ${USER}${NC}"
    echo -e "This appends a new credential (pamu2fcfg -n)."
    echo -e "Recommended: use a second physical key as backup."
    echo -e "Steps:"
    echo -e "  1. Insert the ${GREEN}additional${NC} YubiKey"
    echo -e "  2. Touch when it blinks"
    echo ""
    if gum confirm "Additional YubiKey inserted and ready?"; then
      if pamu2fcfg -n >>"$u2f_file"; then
        echo -e "${GREEN}✓ Additional YubiKey registered successfully!${NC}"
        echo ""
        echo -e "${GREY}Updated content of $u2f_file:${NC}"
        cat "$u2f_file"
        echo ""
        echo -e "${YELLOW}Tip:${NC} For maximum compatibility keep all credentials for one user on a single line (edit manually if newlines appear)."
      else
        echo -e "${RED}Failed to register additional key.${NC}"
      fi
    fi
  fi

  echo ""
  read -n 1 -s -r -p "Press any key to continue..."
}

_view_u2f_keys() {
  local u2f_file="$HOME/.config/Yubico/u2f_keys"

  echo -e "${BLUE}U2F keys configuration for user: ${USER}${NC}"
  echo ""
  if [[ -f "$u2f_file" ]]; then
    cat "$u2f_file"
    echo ""
    echo -e "${GREY}Location: $u2f_file${NC}"
    echo -e "${GREY}Format: username:handle1,key1,...:handle2,key2,... (one logical line per user)${NC}"
  else
    echo -e "${YELLOW}No U2F keys file found for this user yet.${NC}"
    echo -e "Use the registration options above to create one."
  fi
  echo ""
  read -n 1 -s -r -p "Press any key to continue..."
}

_test_u2f_auth() {
  echo -e "${BLUE}PAM U2F authentication test for ${USER}${NC}"
  echo -e "Note: because U2F is configured as 'sufficient', password authentication remains a working fallback."
  echo ""

  if ! available pamtester; then
    echo -e "${YELLOW}pamtester is not installed on this system.${NC}"
    echo -e "It is a development/testing helper (present in the curios-manager dev shell)."
    echo -e "You can still test manually:"
    echo -e "  nix-shell -p pamtester --command 'pamtester login $USER authenticate'"
    echo -e "  nix-shell -p pamtester --command 'pamtester sudo $USER authenticate'"
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi

  echo -e "${YELLOW}--- Testing 'login' PAM service ---${NC}"
  pamtester login "$USER" authenticate || true
  echo ""

  echo -e "${YELLOW}--- Testing 'sudo' PAM service ---${NC}"
  pamtester sudo "$USER" authenticate || true
  echo ""

  echo -e "${GREEN}Test complete.${NC} A successful U2F touch or password prompt means the stack is responsive."
  echo -e "If U2F module is enabled and key registered, touching the YubiKey should authenticate without password."
  echo ""
  read -n 1 -s -r -p "Press any key to continue..."
}

#------------- LUKS FIDO2 enrollment functions

_get_luks_enabled() {
  curios-update --nixos-option curios.filesystems.luks.enable 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "unknown"
}

_get_luks_fido2_enabled() {
  curios-update --nixos-option curios.security.luksFido2.enable 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "unknown"
}

_count_luks_keyslots() {
  local device="/dev/disk/by-label/curiosystem"
  if [[ ! -e "$device" ]]; then
    echo 0
    return
  fi

  # luksDump on the encrypted partition requires root (standard users get
  # "Device /dev/... is not a valid LUKS device" or lock errors).
  local dump
  if ! dump=$(sudo cryptsetup luksDump "$device" 2>/dev/null); then
    # User probably cancelled sudo or device is inaccessible
    echo 0
    return
  fi

  echo "$dump" | grep -c '^[[:space:]]*[0-9]\+:' || echo 0
}

# Check if the currently inserted YubiKey has a FIDO2 PIN set.
# Works with ykman 5.x text output (JSON output not available on all versions).
_check_yubikey_fido_pin() {
  if ! available ykman; then
    echo "unknown"
    return
  fi

  local output
  output=$(ykman fido info 2>/dev/null)

  if [[ -z "$output" ]]; then
    echo "unknown"
    return
  fi

  # In ykman 5.x, when a PIN is set it shows "PIN: X attempt(s) remaining"
  # When no PIN is set it usually shows "PIN: disabled"
  if echo "$output" | grep -q "PIN:.*attempt"; then
    echo "set"
  elif echo "$output" | grep -qi "PIN:.*disabled"; then
    echo "not_set"
  else
    echo "unknown"
  fi
}

_enroll_luks_fido2() {
  echo -e "${BLUE}LUKS FIDO2 YubiKey Enrollment${NC}"
  echo ""

  local LUKS_ENABLED
  LUKS_ENABLED=$(_get_luks_enabled)

  if [[ "$LUKS_ENABLED" != "true" ]]; then
    echo -e "${YELLOW}This system does not appear to use CuriOS LUKS encryption.${NC}"
    echo -e "LUKS FIDO2 enrollment only makes sense on systems installed with full disk encryption."
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi

  if ! available systemd-cryptenroll; then
    echo -e "${RED}systemd-cryptenroll not found.${NC}"
    echo -e "This tool is required for FIDO2 LUKS enrollment."
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi

  # Check for FIDO2 device presence (user request)
  echo -e "${BLUE}Checking for FIDO2-compatible security key...${NC}"
  local FIDO2_LIST
  FIDO2_LIST=$(systemd-cryptenroll --fido2-device=list 2>/dev/null || true)

  if [[ -z "$FIDO2_LIST" ]]; then
    echo -e "${YELLOW}No FIDO2 device detected.${NC}"
    echo ""
    echo -e "Please insert your YubiKey (or other FIDO2 security key) and press any key to retry detection."
    read -n 1 -s -r -p ""
    echo ""
    FIDO2_LIST=$(systemd-cryptenroll --fido2-device=list 2>/dev/null || true)
    if [[ -z "$FIDO2_LIST" ]]; then
      echo -e "${RED}Still no FIDO2 device found.${NC}"
      echo -e "Make sure your key supports FIDO2 + the hmac-secret extension (most YubiKey 5 and newer)."
      read -n 1 -s -r -p "Press any key to continue..."
      return
    fi
  fi

  echo -e "${GREEN}FIDO2 device detected:${NC}"
  echo "$FIDO2_LIST"
  echo ""

  # --- Check FIDO2 PIN status (important for LUKS enrollment) ---
  local PIN_STATUS
  PIN_STATUS=$(_check_yubikey_fido_pin)

  case "$PIN_STATUS" in
  "set")
    echo -e "${GREEN}✓ This YubiKey already has a FIDO PIN set.${NC}"
    echo ""
    ;;
  "not_set")
    echo -e "${YELLOW}This YubiKey does NOT have a FIDO PIN set yet.${NC}"
    echo -e "A PIN is required if you want to use ${BLUE}--fido2-with-client-pin${NC} during enrollment."
    echo ""
    if gum confirm "Set a FIDO PIN on the YubiKey now?"; then
      echo -e "${BLUE}Launching PIN setup...${NC}"
      echo -e "${GREY}(You will be asked to set a new PIN for the FIDO application)${NC}"
      echo ""
      ykman fido access change-pin || true
      echo ""
      # Re-check after the user has (hopefully) set a PIN
      PIN_STATUS=$(_check_yubikey_fido_pin)
      if [[ "$PIN_STATUS" == "set" ]]; then
        echo -e "${GREEN}✓ FIDO PIN successfully set.${NC}"
      else
        echo -e "${YELLOW}Could not confirm that a PIN was set. You can try again later with:${NC}"
        echo -e "    ykman fido access change-pin"
      fi
      echo ""
      read -n 1 -s -r -p "Press any key to continue..."
      echo ""
    else
      echo -e "${GREY}Skipping PIN setup. You can set it later with: ykman fido access change-pin${NC}"
      echo ""
    fi
    ;;
  "unknown")
    echo -e "${GREY}Could not determine FIDO PIN status (ykman not available or no device).${NC}"
    echo ""
    ;;
  esac
  # --- End of PIN check ---

  # Check current LUKS FIDO2 module status
  local LUKS_FIDO2_ENABLED
  LUKS_FIDO2_ENABLED=$(_get_luks_fido2_enabled)

  if [[ "$LUKS_FIDO2_ENABLED" != "true" ]]; then
    echo -e "${YELLOW}The curios.security.luksFido2.enable module is currently DISABLED.${NC}"
    echo -e "Without it, the initrd will not attempt FIDO2 unlock at boot even if a key is enrolled."
    echo ""
    if gum confirm "Enable the LUKS FIDO2 module now?"; then
      echo -e "${BLUE}Enabling curios.security.luksFido2.enable...${NC}"
      gum spin --spinner dot --title "Enabling module..." --show-error -- sudo curios-update --update-module curios.security.luksFido2.enable true
      echo ""
      echo -e "${BLUE}Applying system configuration...${NC}"
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo curios-update --update
      echo -e "${GREEN}Module enabled.${NC}"
      echo ""
    else
      echo -e "${YELLOW}LUKS FIDO2 enrollment requires the module to be enabled.${NC}"
      echo -e "${YELLOW}You can enable it later from the Security menu.${NC}"
      echo ""
      read -n 1 -s -r -p "Press any key to return to the Security menu..."
      echo ""
      return
    fi
  fi

  # Check how many keyslots already exist.
  # This requires root because cryptsetup luksDump needs to read the LUKS header
  # on the encrypted partition (normal users get lock/read errors).
  echo -e "${GREY}Reading LUKS metadata (sudo may prompt for password)...${NC}"
  local KEYSLOT_COUNT
  KEYSLOT_COUNT=$(_count_luks_keyslots)

  echo -e "Detected LUKS keyslots on /dev/disk/by-label/curiosystem: ${BLUE}${KEYSLOT_COUNT}${NC}"
  echo ""

  # Strong safety warnings - adapted based on existing keyslots
  echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
  echo -e "${RED}                    IMPORTANT SECURITY WARNING${NC}"
  echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
  echo ""
  echo -e "${YELLOW}Enrolling a YubiKey for LUKS FIDO2 means:${NC}"
  echo -e "  • This YubiKey will be able to unlock the disk at boot"
  echo -e "  • If the YubiKey is lost, damaged, or not available, you will need"
  echo -e "    another valid keyslot (passphrase or another key) to boot"
  echo ""

  if [[ "$KEYSLOT_COUNT" -ge 2 ]]; then
    echo -e "${GREEN}Good news:${NC} You already have ${KEYSLOT_COUNT} keyslots."
    echo -e "This gives you some redundancy."
  elif [[ "$KEYSLOT_COUNT" -eq 1 ]]; then
    echo -e "${YELLOW}You currently only have 1 keyslot${NC} (probably the original install passphrase)."
    echo -e "It is ${RED}strongly recommended${NC} to have at least one backup method"
    echo -e "(either a second YubiKey or a recovery key)."
  else
    echo -e "${RED}Warning: No keyslots detected!${NC} This is unusual on a working CuriOS system."
  fi

  echo ""
  echo -e "${RED}Always keep at least one reliable way to unlock this disk${NC}"
  echo -e "(passphrase or recovery key) in addition to any YubiKeys."
  echo ""
  echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
  echo ""

  if ! gum confirm "I understand the risks and will maintain at least one recovery method"; then
    echo -e "${YELLOW}Enrollment cancelled for safety.${NC}"
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi

  # Offer to create a recovery key only if the user has very few keyslots
  echo ""
  if [[ "$KEYSLOT_COUNT" -le 1 ]]; then
    if gum confirm "Create an additional recovery key now? (recommended when you only have one keyslot)" --default=true; then
      echo -e "${BLUE}Creating a LUKS recovery key...${NC}"
      echo -e "You will need to enter an existing passphrase."
      echo ""
      sudo systemd-cryptenroll --recovery-key /dev/disk/by-label/curiosystem || true
      echo ""
      echo -e "${YELLOW}Store the printed recovery key in a safe place (password manager, printed paper, etc.).${NC}"
      read -n 1 -s -r -p "Press any key after you have safely stored the recovery key..."
      echo ""
    fi
  else
    echo -e "${GREY}(You already have ${KEYSLOT_COUNT} keyslots — skipping automatic recovery key suggestion.)${NC}"
    echo -e "${GREY}You can still create one later with: systemd-cryptenroll --recovery-key /dev/disk/by-label/curiosystem${NC}"
    echo ""
  fi

  echo -e "${BLUE}Ready to enroll the FIDO2 key for disk decryption.${NC}"
  echo ""
  echo -e "Recommended settings:"
  echo -e "  • Device: /dev/disk/by-label/curiosystem (CuriOS standard)"
  echo -e "  • With client PIN: yes (recommended for security)"
  echo ""
  echo -e "You will be prompted for:"
  echo -e "  1. An existing LUKS passphrase (to authorize the new keyslot)"
  echo -e "  2. Touching the YubiKey when it blinks"
  echo -e "  3. Setting a PIN for the key (if not already set)"
  echo ""

  if ! gum confirm "Proceed with FIDO2 enrollment now?"; then
    echo -e "${YELLOW}Enrollment cancelled.${NC}"
    read -n 1 -s -r -p "Press any key to continue..."
    return
  fi

  echo ""
  echo -e "${BLUE}Running systemd-cryptenroll...${NC}"
  echo ""

  # Perform the actual enrollment
  if sudo systemd-cryptenroll \
    --fido2-device=auto \
    --fido2-with-client-pin=yes \
    /dev/disk/by-label/curiosystem; then

    echo ""
    echo -e "${GREEN}✓ YubiKey successfully enrolled for LUKS FIDO2!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "  1. Reboot and test that the YubiKey can unlock the disk"
    echo -e "  2. Keep your recovery passphrase in a safe place"
    echo -e "  3. Consider enrolling a second backup YubiKey"
    echo ""
  else
    echo ""
    echo -e "${RED}Enrollment failed.${NC}"
    echo -e "Common reasons:"
    echo -e "  • Wrong or mistyped LUKS passphrase"
    echo -e "  • YubiKey does not support hmac-secret extension"
    echo -e "  • Key already enrolled (you can add more keys)"
    echo ""
  fi

  read -n 1 -s -r -p "Press any key to continue..."
}
