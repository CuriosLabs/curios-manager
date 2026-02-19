#!/usr/bin/env bash

#------------- Colors -------------#
readonly RED="\033[31;1m"      # Red and bold
readonly GREEN="\033[32;1m"    # Green and bold
readonly BLUE="\033[34;1m"     # Blue and bold
readonly GREY="\033[37;1m"     # Grey and bold
readonly YELLOW="\033[33;1;3m" # Yellow, bold and italic
readonly NC="\033[0m"          # No Color

#------------- Variables init
readonly SCRIPT_VERSION="0.30.4"
VERBOSE=0
readonly CURIOS_SRC_URL="https://github.com/CuriosLabs/CuriOS"
LIST_GEN=""
LIST_GEN_DATE=""
LIST_GEN_KERNEL=""

export GUM_CHOOSE_CURSOR_FOREGROUND="#3584e4"
export GUM_CHOOSE_SELECTED_FOREGROUND="#26a269"
export GUM_CONFIRM_SELECTED_BACKGROUND="#26a269"
