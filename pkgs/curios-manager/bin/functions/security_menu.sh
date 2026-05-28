#!/usr/bin/env bash

#------------- Security menu (U2F/FIDO2 YubiKey setup via pam_u2f)
# Requires curios.security.u2f.enable to be true for full functionality.
# Uses pamu2fcfg (provided by the security module) to register keys in
# ~/.config/Yubico/u2f_keys

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
      sudo curios-update --update-module curios.security.u2f.enable true

      echo ""
      echo -e "${BLUE}Applying system configuration (nixos-rebuild). This can take several minutes...${NC}"
      echo -e "${YELLOW}You will be prompted for your sudo password if needed.${NC}"
      echo ""
      sudo curios-update --update

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
  SECURITY_MENU=$(gum choose --header "YubiKey U2F/FIDO2 login setup - Select an option:" \
    "󰌾 Register primary YubiKey" \
    "󰐕 Add additional YubiKey (backup)" \
    " View current keys file" \
    "󰙨 Test authentication (pamtester)" \
    " Back")

  case $SECURITY_MENU in
  "󰌾 Register primary YubiKey")
    _register_u2f_key "primary"
    security_menu
    ;;
  "󰐕 Add additional YubiKey (backup)")
    _register_u2f_key "additional"
    security_menu
    ;;
  " View current keys file")
    _view_u2f_keys
    security_menu
    ;;
  "󰙨 Test authentication (pamtester)")
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
