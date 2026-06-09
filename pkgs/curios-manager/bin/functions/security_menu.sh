#!/usr/bin/env bash

#------------- Security menu (U2F/FIDO2 YubiKey setup via pam_u2f + LUKS FIDO2 + Secure Boot)
# - PAM U2F: Requires curios.security.u2f.enable
# - LUKS FIDO2: Requires curios.security.luksFido2.enable (and a LUKS-encrypted system)
# Uses pamu2fcfg for login/sudo (respecting curios.security.u2f.origin + appid) and
# systemd-cryptenroll for disk encryption.

_get_security_enabled() {
  # Check via curios-update as documented (it delegates to nixos-option internally).
  # This is the first verification step for the security/U2F feature.
  curios-update --nixos-option curios.security.enable 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "unknown"
}

_get_u2f_enabled() {
  curios-update --nixos-option curios.security.u2f.enable 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "unknown"
}

_get_u2f_origin() {
  curios-update --nixos-option curios.security.u2f.origin 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "curios"
}

_get_u2f_appid() {
  curios-update --nixos-option curios.security.u2f.appid 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "curios"
}

security_menu() {
  local SECURITY_ENABLED
  SECURITY_ENABLED=$(_get_security_enabled)

  if [[ "$SECURITY_ENABLED" != "true" ]]; then
    echo -e "${YELLOW}CuriOS security module is currently DISABLED on this system.${NC}"
    echo -e "Security menu will not work until enabled."
    echo ""

    if gum confirm "Enable CuriOS security now?"; then
      echo -e "${YELLOW}You will be prompted for your sudo password if needed.${NC}"
      sudo whoami 1>/dev/null # Force prompt for sudo password now
      gum spin --spinner dot --title "Enabling module.." --show-error -- sudo curios-update --update-module curios.security.enable true

      echo ""
      echo -e "${BLUE}Applying system configuration. This can take several minutes...${NC}"
      echo -e "${YELLOW}You will be prompted for your sudo password if needed.${NC}"
      sudo whoami 1>/dev/null # Force prompt for sudo password now
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo curios-update --update

      # Re-check status after the update
      SECURITY_ENABLED=$(_get_security_enabled)
      if [[ "$SECURITY_ENABLED" == "true" ]]; then
        echo -e "${GREEN}✓ CuriOS security is now enabled!${NC}"
      else
        echo -e "${YELLOW}Module was activated but the live status is not yet 'true'. A reboot may be required.${NC}"
      fi
    else
      main_menu
      return
    fi
  fi

  local SECURITY_MENU
  SECURITY_MENU=$(gum choose --header "YubiKey Security - Select an option:" \
    "🔑 Register primary YubiKey for user login/sudo (PAM)" \
    "󰐕 Add additional YubiKey for user login/sudo (PAM)" \
    "🔐 Enroll YubiKey for full disk decryption (FIDO2)" \
    "🔗 Enable Secure Boot (Limine)" \
    " View current PAM/U2F keys file" \
    "󰙨 Test PAM authentication" \
    " Back")

  case $SECURITY_MENU in
  "🔑 Register primary YubiKey for user login/sudo (PAM)")
    _check_u2f_option
    _register_u2f_key "primary"
    security_menu
    ;;
  "󰐕 Add additional YubiKey for user login/sudo (PAM)")
    _check_u2f_option
    _register_u2f_key "additional"
    security_menu
    ;;
  "🔐 Enroll YubiKey for full disk decryption (FIDO2)")
    _enroll_luks_fido2
    security_menu
    ;;
  "🔗 Enable Secure Boot (Limine)")
    _enable_secure_boot
    security_menu
    ;;
  " View current PAM/U2F keys file")
    _view_u2f_keys
    security_menu
    ;;
  "󰙨 Test PAM authentication")
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

  # Read the system's configured origin and appid (new defaults are "curios")
  local ORIGIN
  local APPID
  ORIGIN=$(_get_u2f_origin)
  APPID=$(_get_u2f_appid)

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
      # We explicitly pass origin and appid so the credential is portable across machines
      if pamu2fcfg -o "$ORIGIN" -i "$APPID" >"$u2f_file"; then
        echo -e "${GREEN}✓ Primary YubiKey successfully registered!${NC}"
        echo ""
        echo -e "${YELLOW}Note:${NC} If you recently enabled the U2F module, run a system update and re-login for PAM changes to apply."
        echo -e "${GREY}You can view the file content from the 'View current U2F keys file' menu option.${NC}"
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
      return
    fi

    echo -e "${BLUE}Adding ADDITIONAL YubiKey for ${USER}${NC}"
    echo -e "Steps:"
    echo -e "  1. Insert the ${GREEN}additional${NC} YubiKey"
    echo -e "  2. Touch when it blinks"
    echo ""
    if gum confirm "Additional YubiKey inserted and ready?"; then
      if pamu2fcfg -n -o "$ORIGIN" -i "$APPID" >>"$u2f_file"; then
        echo -e "${GREEN}✓ Additional YubiKey registered successfully!${NC}"
        echo ""
        echo -e "${GREY}You can view the file content from the 'View current U2F keys file' menu option.${NC}"
      else
        echo -e "${RED}Failed to register additional key.${NC}"
      fi
    fi
  fi
}

_check_u2f_option() {
  local U2F_ENABLED
  U2F_ENABLED=$(_get_u2f_enabled)

  if [[ "$U2F_ENABLED" != "true" ]]; then
    echo -e "${YELLOW}PAM U2F authentication is currently DISABLED on this system.${NC}"
    echo -e "YubiKey login (for greetd, cosmic-greeter, login and sudo) will not work until enabled."
    echo ""

    if gum confirm "Enable PAM U2F authentication with YubiKey now?"; then
      echo -e "${YELLOW}You will be prompted for your sudo password if needed.${NC}"
      sudo whoami 1>/dev/null # Force prompt for sudo password now
      gum spin --spinner dot --title "Enabling module.." --show-error -- sudo curios-update --update-module curios.security.u2f.enable true
      echo ""
      echo -e "${BLUE}Applying system configuration. This can take several minutes...${NC}"
      echo -e "${YELLOW}You will be prompted for your sudo password if needed.${NC}"
      sudo whoami 1>/dev/null # Force prompt for sudo password now
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo curios-update --update

      # Re-check status after the update
      U2F_ENABLED=$(_get_u2f_enabled)
      if [[ "$U2F_ENABLED" == "true" ]]; then
        echo -e "${GREEN}✓ PAM U2F authentication is now enabled!${NC}"
      else
        echo -e "${YELLOW}Module was activated but the live status is not yet 'true'. A reboot may be required.${NC}"
      fi
      echo -e "${YELLOW}You may need to log out and log back in (or reboot) for the new PAM configuration to take full effect.${NC}"
    else
      security_menu
      return
    fi
  fi

  if ! available pamu2fcfg; then
    echo -e "${RED}pamu2fcfg not found!${NC}"
    echo -e "This usually means ${BLUE}curios.security.u2f.enable${NC} is not active (or system not yet rebuilt)."
    echo -e "Enable the module and run a full system update, then retry."
    security_menu
    return
  fi
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
}

_test_u2f_auth() {
  echo -e "${BLUE}PAM U2F authentication test for ${USER}${NC}"
  echo -e "Note: because U2F is configured as 'sufficient', password authentication remains a working fallback."
  echo -e "If U2F module is enabled and key registered, touching the YubiKey should authenticate without password."
  echo ""

  if ! available pamtester; then
    echo -e "${YELLOW}pamtester is not installed on this system.${NC}"
    echo -e "It is a development/testing helper (present in the curios-manager dev shell)."
    echo -e "You can still test manually:"
    echo -e "  nix-shell -p pamtester --command 'pamtester login $USER authenticate'"
    echo -e "  nix-shell -p pamtester --command 'pamtester sudo $USER authenticate'"
    return
  fi

  echo -e "${YELLOW}--- Testing 'sudo' PAM service ---${NC}"
  pamtester sudo "$USER" authenticate || true
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

  # --dump-json-metadata gives structured output; jq counts real keyslots.
  # This requires root because reading the LUKS header is privileged.
  local count
  if ! count=$(sudo cryptsetup --dump-json-metadata luksDump "$device" 2>/dev/null | jq '.keyslots | length' 2>/dev/null); then
    # User probably cancelled sudo, device is inaccessible, or jq failed
    echo 0
    return
  fi

  # Ensure we output a clean integer
  echo "$count" | tr -d '[:space:]'
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
    return
  fi

  if ! available systemd-cryptenroll; then
    echo -e "${RED}systemd-cryptenroll not found.${NC}"
    echo -e "This tool is required for FIDO2 LUKS enrollment."
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
        return
      fi
    else
      echo -e "${GREY}Skipping PIN setup. You can set it with: ykman or the Yubico authenticator app.${NC}"
      return
    fi
    ;;
  "unknown")
    echo -e "${GREY}Could not determine FIDO PIN status (ykman not available or not a Yubikey device).${NC}"
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
      sudo whoami 1>/dev/null # Force prompt for sudo password now
      gum spin --spinner dot --title "Enabling module..." --show-error -- sudo curios-update --update-module curios.security.luksFido2.enable true
      echo ""
      echo -e "${BLUE}Applying system configuration...${NC}"
      sudo whoami 1>/dev/null # Force prompt for sudo password now
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo curios-update --update
      echo -e "${GREEN}Module enabled.${NC}"
      echo ""
    else
      echo -e "${YELLOW}LUKS FIDO2 enrollment requires the module to be enabled.${NC}"
      echo -e "${YELLOW}You can enable it later from the Security menu.${NC}"
      return
    fi
  fi

  # Check how many keyslots already exist.
  # This requires root because cryptsetup luksDump needs to read the LUKS header
  # on the encrypted partition (normal users get lock/read errors).
  echo -e "${GREY}Reading LUKS metadata (sudo may prompt for password)...${NC}"
  local KEYSLOT_COUNT
  KEYSLOT_COUNT=$(_count_luks_keyslots)

  # Safety warnings adapted based on existing keyslots
  if [[ "$KEYSLOT_COUNT" -ge 1 ]]; then
    echo -e "${GREEN}✓ You have ${KEYSLOT_COUNT} keyslot(s) configured.${NC}"
    echo -e "At least one other method (likely a passphrase) can be used to decrypt the disk."
    echo -e "${YELLOW}If the YubiKey is lost, damaged, or not available, you will need${NC}"
    echo -e "${YELLOW}another valid keyslot (passphrase or another key) to boot.${NC}"
    echo ""
  else
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}                    IMPORTANT SECURITY WARNING${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${RED}Warning: No keyslots detected!${NC} This is unusual on a working CuriOS system."
    echo -e "${RED}Without any keyslots, you risk being locked out of your disk.${NC}"
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo ""
    if gum confirm "Create a recovery key now?" --default=true; then
      echo -e "${BLUE}Creating a LUKS recovery key...${NC}"
      echo -e "You will need to enter passphrase."
      echo ""
      sudo systemd-cryptenroll --recovery-key /dev/disk/by-label/curiosystem || true
      echo ""
      echo -e "${YELLOW}Store the printed recovery key in a safe place (password manager, printed paper, etc.).${NC}"
    fi
  fi

  echo -e "${BLUE}Ready to enroll the FIDO2 key for disk decryption.${NC}"
  echo ""
  echo -e "You will be prompted for:"
  echo -e "  1. An existing LUKS passphrase (to authorize the new keyslot)"
  echo -e "  2. Touching the YubiKey when it blinks"
  echo -e "  3. Setting a PIN for the key (if not already set)"
  echo ""

  if ! gum confirm "Proceed with FIDO2 enrollment now?"; then
    echo -e "${YELLOW}Enrollment cancelled.${NC}"
    return
  fi

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

}

#------------- Secure Boot functions (Limine)

_get_limine_enabled() {
  curios-update --nixos-option curios.bootefi.limine.enable 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "unknown"
}

_get_secure_boot_module_enabled() {
  curios-update --nixos-option curios.bootefi.limine.secureBoot.enable 2>/dev/null |
    sed -n '/^Value:/{n;p;}' | tr -d ' " ' || echo "unknown"
}

_get_secure_boot_status() {
  if ! available bootctl; then
    echo "unknown"
    return
  fi
  local status
  status=$(bootctl status 2>/dev/null | grep -i "^   Secure Boot:" | sed 's/.*Secure Boot: //' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
  if [[ -z "$status" ]]; then
    echo "unknown"
    return
  fi
  echo "$status"
}

_enable_secure_boot() {
  echo -e "${BLUE}Secure Boot Setup (Limine)${NC}"
  echo ""

  if ! available bootctl; then
    echo -e "${RED}bootctl command not found!${NC}"
    echo -e "This is required to check Secure Boot status."
    return
  fi

  if ! available sbctl; then
    echo -e "${RED}sbctl command not found!${NC}"
    echo -e "This is required to check Secure Boot status."
    return
  fi

  # Step 1: Check if Limine is enabled
  local LIMINE_ENABLED
  LIMINE_ENABLED=$(_get_limine_enabled)

  if [[ "$LIMINE_ENABLED" != "true" ]]; then
    echo -e "${YELLOW}Limine bootloader is currently NOT enabled on this system.${NC}"
    echo -e "Secure Boot with CuriOS requires the Limine bootloader."
    echo -e "Limine will be the default bootloader in the next CuriOS version."
    echo ""

    if gum confirm "Switch to Limine bootloader now?"; then
      echo -e "${BLUE}Enabling Limine bootloader...${NC}"
      sudo whoami 1>/dev/null
      gum spin --spinner dot --title "Enabling Limine..." --show-error -- sudo curios-update --update-module curios.bootefi.limine.enable true
      echo ""
      echo -e "${BLUE}Applying system configuration. This can take several minutes...${NC}"
      sudo whoami 1>/dev/null
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo curios-update --update
      echo -e "${GREEN}✓ Limine bootloader is now enabled!${NC}"
      echo ""
      # Re-check
      LIMINE_ENABLED=$(_get_limine_enabled)
    else
      echo -e "${YELLOW}Secure Boot requires Limine. You can enable it later.${NC}"
      return
    fi
  fi

  if [[ "$LIMINE_ENABLED" != "true" ]]; then
    echo -e "${RED}Failed to enable Limine. Please check the system configuration.${NC}"
    return
  fi

  # Step 2: Check current Secure Boot status
  local SB_STATUS
  SB_STATUS=$(_get_secure_boot_status)
  echo -e "${BLUE}Current Secure Boot status: ${YELLOW}${SB_STATUS}${NC}"
  echo ""

  if [[ "$SB_STATUS" == "enabled"* ]]; then
    echo -e "${GREEN}✓ Secure Boot is already enabled on this system!${NC}"
    echo ""
    return
  fi

  # Step 2b: Check if the Microsoft KEK 2023 certificate is present
  # This certificate is needed for Secure Boot with the --microsoft flag in sbctl.
  # If not present, a firmware update may be required.
  local KEK_OUTPUT
  KEK_OUTPUT=$(efi-readvar -v KEK 2>/dev/null || true)
  if [[ -n "$KEK_OUTPUT" ]] && ! echo "$KEK_OUTPUT" | grep -q "Microsoft Corporation KEK 2K CA 2023"; then
    echo -e "${YELLOW}WARNING: The Microsoft KEK 2023 certificate is not present in the UEFI KEK database.${NC}"
    echo -e "This certificate is required for Secure Boot with the --microsoft flag in sbctl."
    echo -e "A firmware update may be needed to add this certificate."
    echo ""
    echo -e "You can update the firmware from the System menu (${BLUE} Firmware${NC})."
    echo ""
    if gum confirm "Would you like to go to the System menu to update the firmware now?"; then
      system_menu
      return
    else
      echo -e "${YELLOW}Continuing without the Microsoft KEK 2023 certificate. Secure Boot may fail.${NC}"
      echo ""
    fi
  fi

  # Step 2c: Check if the Microsoft UEFI CA 2023 certificate is present in db
  # This certificate is needed for Secure Boot with the --microsoft flag in sbctl.
  # If not present, a firmware update may be required.
  local DB_OUTPUT
  DB_OUTPUT=$(efi-readvar -v db 2>/dev/null || true)
  if [[ -n "$DB_OUTPUT" ]] && ! echo "$DB_OUTPUT" | grep -q "Microsoft UEFI CA 2023"; then
    echo -e "${YELLOW}WARNING: The Microsoft UEFI CA 2023 certificate is not present in the UEFI signature database (db).${NC}"
    echo -e "This certificate is required for Secure Boot with the --microsoft flag in sbctl."
    echo -e "A firmware update may be needed to add this certificate."
    echo ""
    echo -e "You can update the firmware from the System menu (${BLUE} Firmware${NC})."
    echo ""
    if gum confirm "Would you like to go to the System menu to update the firmware now?"; then
      system_menu
      return
    else
      echo -e "${YELLOW}Continuing without the Microsoft UEFI CA 2023 certificate. Secure Boot may fail.${NC}"
      echo ""
    fi
  fi

  # Step 2d: Check if the Microsoft Option ROM UEFI CA 2023 certificate is present in db
  # This certificate is needed for hardware Option ROMs (GPU, NIC firmware, etc.)
  # Some devices require this certificate to boot with Secure Boot enabled.
  local CERT_ROM
  CERT_ROM="unknown"
  if [[ -n "$DB_OUTPUT" ]] && echo "$DB_OUTPUT" | grep -q "Microsoft Option ROM UEFI CA 2023"; then
    CERT_ROM=true
  elif [[ -n "$DB_OUTPUT" ]]; then
    CERT_ROM=false
    echo -e "${YELLOW}WARNING: The Microsoft Option ROM UEFI CA 2023 certificate is not present in the UEFI signature database (db).${NC}"
    echo -e "This certificate is required for hardware Option ROMs (GPU, NIC firmware, etc.) with Secure Boot."
    echo -e "Missing this certificate may cause hardware to not initialize with Secure Boot enabled."
    echo ""
    echo -e "You can update the firmware from the System menu (${BLUE} Firmware${NC})."
    echo ""
    if gum confirm "Would you like to go to the System menu to update the firmware now?"; then
      system_menu
      return
    else
      echo -e "${YELLOW}Continuing without the Microsoft Option ROM UEFI CA 2023 certificate. Hardware may not work correctly with Secure Boot.${NC}"
      echo ""
    fi
  fi

  # Step 3: Create Secure Boot keys manually (as recommended in NixOS wiki)
  local SBCTL_STATUS
  SBCTL_STATUS=$(sudo sbctl status 2>/dev/null || true)
  if echo "$SBCTL_STATUS" | grep -q "sbctl is not installed" && echo "$SBCTL_STATUS" | grep -q "Secure Boot:.*Disabled"; then
    echo -e "${BLUE}Creating Secure Boot keys...${NC}"
    sudo sbctl create-keys
    # Verify that keys were created successfully
    local SBCTL_STATUS_AFTER
    SBCTL_STATUS_AFTER=$(sudo sbctl status 2>/dev/null || true)
    if ! echo "$SBCTL_STATUS_AFTER" | grep -q "sbctl is installed"; then
      echo -e "${RED}Failed to create Secure Boot keys. sbctl is still not installed.${NC}"
      echo -e "${YELLOW}Please check the error above and try again.${NC}"
      return
    fi
    echo -e "${GREEN}✓ Secure Boot keys created successfully.${NC}"
  fi

  # Step 4: Check if we are in UEFI Setup Mode
  if [[ "$SB_STATUS" == *"setup"* ]]; then
    echo -e "${GREEN}✓ System is in UEFI Secure Boot Setup Mode.${NC}"
    echo -e "${BLUE}Rebuilding the system will now enroll the generated keys automatically.${NC}"
    echo ""

    if gum confirm "Rebuild and enroll Secure Boot keys now?"; then
      echo -e "${BLUE}Applying system configuration to enroll keys...${NC}"
      local SBCTL_ARGS="--microsoft"
      if [[ "$CERT_ROM" == true ]]; then
        SBCTL_ARGS="--microsoft --firmware-builtin"
        echo -e "${BLUE}Firmware certificate will also be enrolled...${NC}"
      fi
      if ! sudo sbctl enroll-keys "${SBCTL_ARGS}"; then
        echo -e "${RED}Failed to enroll Secure Boot keys.${NC}"
        echo -e "${YELLOW}Please ensure you are in UEFI Setup Mode and try again.${NC}"
        return
      fi
      echo -e "${GREEN}✓ Secure Boot keys enrolled successfully.${NC}"
      echo ""
      sudo whoami 1>/dev/null
      gum spin --spinner dot --title "Enabling secure boot module..." --show-error -- sudo curios-update --update-module curios.bootefi.limine.secureBoot.enable true
      gum spin --spinner dot --title "Updating system..." --show-error -- sudo curios-update --update
      echo ""
      # Verify
      SB_STATUS=$(_get_secure_boot_status)
      if [[ "$SB_STATUS" == "enabled"* ]]; then
        echo -e "${GREEN}✓ Secure Boot is now enabled!${NC}"
        echo ""
        echo -e "${YELLOW}Next steps:${NC}"
        echo -e "  1. Reboot to verify that Secure Boot works correctly"
        echo -e "  2. If needed, re-enable Secure Boot manually in your UEFI firmware"
        echo ""
        if gum confirm "Reboot now?"; then
          systemctl reboot
        fi
      else
        echo -e "${YELLOW}Keys were enrolled but Secure Boot is not yet reported as enabled.${NC}"
        echo -e "${YELLOW}A reboot may be required. Please run this menu again after rebooting.${NC}"
        if gum confirm "Reboot now?"; then
          systemctl reboot
        fi
      fi
    else
      echo -e "${YELLOW}Rebuild cancelled. Run this menu again when ready to enroll keys.${NC}"
    fi
    return
  fi

  # Step 5: If we are not in setup mode and not enabled, guide the user
  echo -e "${YELLOW}Your system is currently NOT in UEFI Secure Boot Setup Mode.${NC}"
  echo ""
  echo -e "To enable Secure Boot, you need to enter Setup Mode in your UEFI firmware."
  echo -e "This usually involves:"
  echo -e "  1. Rebooting the computer"
  echo -e "  2. In the Limine boot menu, press ${GREEN}S${NC} to enter ${BLUE}Firmware Setup${NC}"
  echo -e "  3. In the UEFI firmware, find the Secure Boot settings"
  echo -e "  4. Select ${BLUE}Reset to Setup Mode${NC} or clear all keys"
  echo -e "  5. Save and exit, rebooting back to NixOS"
  echo ""
  echo -e "${YELLOW}Important:${NC} Do not select 'Clear All Secure Boot Keys' on ThinkPad devices."
  echo -e "Use 'Reset to Setup Mode' instead."
  echo ""
  echo -e "Once back in NixOS, open this menu again to complete the enrollment."
  echo ""

  if gum confirm "Reboot now to enter Firmware Setup?"; then
    systemctl reboot
  else
    echo -e "${YELLOW}You can reboot later. Remember to run this menu again after entering Setup Mode.${NC}"
  fi
}
