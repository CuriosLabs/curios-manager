#!/usr/bin/env bash

#------------- Themes menu
themes_menu() {
  local THEMES_MENU
  local THEMES_LIST
  local theme
  local -a THEMES=()
  local -a GUM_ARGS=()

  if ! THEMES_LIST=$(curios-dotfiles --list); then
    echo -e "${RED}Failed to list themes.${NC}"
    main_menu
    return
  fi

  if [ -z "$THEMES_LIST" ]; then
    echo -e "${RED}No themes available.${NC}"
    main_menu
    return
  fi

  mapfile -t THEMES <<<"$THEMES_LIST"

  for theme in "${THEMES[@]}"; do
    if [ "$theme" = "One Dark" ]; then
      GUM_ARGS=(--selected "One Dark")
      break
    fi
  done

  THEMES_MENU=$(gum choose --height 12 --header "Select an option:" "${GUM_ARGS[@]}" -- "${THEMES[@]}" " Upgrade" " Back")
  case $THEMES_MENU in
  " Upgrade")
    local system_lang
    system_lang=$(nix-instantiate --eval --raw --expr '(import <nixpkgs/nixos> {}).config.curios.system.keyboard')
    gum spin --spinner dot --title "Upgrading themes..." --show-error -- curios-dotfiles --upgrade --lang "$system_lang" "$HOME"
    themes_menu
    ;;
  " Back")
    main_menu
    ;;
  *)
    [ -z "$THEMES_MENU" ] && return
    curios-dotfiles --themes "$THEMES_MENU" "$HOME"
    themes_menu
    ;;
  esac
}
