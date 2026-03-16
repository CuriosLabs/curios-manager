#!/usr/bin/env bash

#------------- Themes menu
themes_menu() {
  local THEMES_MENU
  local CURRENT_KEYBOARD
  CURRENT_KEYBOARD=$(nixos-option curios.system.keyboard | sed -n '/^Value:/{n;p;}' | tr -d '" ')

  THEMES_MENU=$(gum choose --header "Select an option:" --selected "One Dark (default)" \
    "Catppuccin Macchiato" \
    "Everforest Medium" \
    "Gruvbox Dark" \
    "Hackers Green" \
    "Kanagawa" \
    "Nord Dark" \
    "Nord Light" \
    "One Dark (default)" \
    "Tokyonight" \
    " Back")
  case $THEMES_MENU in
  "Catppuccin Macchiato")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Catppuccin-Macchiato "$HOME"
    themes_menu
    ;;
  "Everforest Medium")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Everforest-Medium "$HOME"
    themes_menu
    ;;
  "Gruvbox Dark")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Gruvbox-Dark "$HOME"
    themes_menu
    ;;
  "Hackers Green")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Hackers-Green "$HOME"
    themes_menu
    ;;
  "Kanagawa")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Kanagawa "$HOME"
    themes_menu
    ;;
  "Nord Dark")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Nord-Dark "$HOME"
    themes_menu
    ;;
  "Nord Light")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Nord-Light "$HOME"
    themes_menu
    ;;
  "One Dark (default)")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes One-Dark "$HOME"
    themes_menu
    ;;
  "Tokyonight")
    curios-dotfiles --lang "$CURRENT_KEYBOARD" --themes Tokyonight "$HOME"
    themes_menu
    ;;
  " Back")
    main_menu
    ;;
  esac
}
