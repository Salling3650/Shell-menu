#!/usr/bin/env bash

# ============================================
# MENU CONFIGURATION (Easy to Modify)
# ============================================
MENU_SELECTOR_SYMBOL=">"
MENU_SELECTED_COLOR=$'\e[1;32m'  # Bold Green
MENU_NORMAL_COLOR=$'\e[0m'        # Reset
MENU_CURSOR_VISIBLE=false
MENU_CLEAR_AFTER_SELECT=true

# ============================================
# ADVANCED MENU SELECTOR FUNCTION
# ============================================
# Usage Examples:
#   advanced_menu_selector "Choose:" choice "Option 1" "Option 2" "Option 3"
#   advanced_menu_selector "Select:" result "Display A" "Display B" -- "value_a" "value_b"
#
# Arguments:
#   $1: Prompt message
#   $2: Variable name to store result
#   $@: Options (display text, optionally followed by -- and return values)
#
# Returns:
#   0 on success
#   1 on error
#   130 on cancellation (Ctrl+C, q, or Q)
# ============================================
function advanced_menu_selector() {
    local -r prompt="$1" outvar="$2"
    shift 2
    local -a display_options=() return_values=()
    local parsing_display=true

    # Parse display options and return values
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--" ]]; then
            parsing_display=false
            shift
            continue
        fi
        if $parsing_display; then
            display_options+=("$1")
        else
            return_values+=("$1")
        fi
        shift
    done

    # If no return values specified, use display options as return values
    if (( ${#return_values[@]} == 0 )); then
        return_values=("${display_options[@]}")
    fi

    # Validation
    local count=${#display_options[@]}
    if (( count == 0 )); then
        echo "Error: No options provided" >&2
        return 1
    fi
    if (( ${#display_options[@]} != ${#return_values[@]} )); then
        echo "Error: Mismatched display and return value arrays" >&2
        return 1
    fi

    # Setup terminal
    local cur=0
    $MENU_CURSOR_VISIBLE || tput civis 2>/dev/null
    trap 'tput cnorm 2>/dev/null; stty echo 2>/dev/null' EXIT INT TERM
    stty -echo 2>/dev/null

    printf "%s\n" "$prompt"

    # Main selection loop
    while true; do
        local index=0
        for o in "${display_options[@]}"; do
            if [[ $index == $cur ]]; then
                printf " %s%s %s %s\n" "${MENU_SELECTOR_SYMBOL}" "${MENU_SELECTED_COLOR}" "$o" "${MENU_NORMAL_COLOR}"
            else
                printf "   %s\n" "$o"
            fi
            (( ++index ))
        done

        printf "\e[97m↑↓\e[0m \e[2;37mnavigate\e[0m \e[97m• ⏎\e[0m \e[2;37mselect\e[0m\n"

        # Read user input
        IFS= read -rsn1 key
        case "$key" in
            $'\x1b')  # ESC sequence
                read -rsn2 rest
                case "$rest" in
                    '[A') (( cur = (cur - 1 + count) % count )) ;;  # Up arrow
                    '[B') (( cur = (cur + 1) % count )) ;;          # Down arrow
                esac
                ;;
            ''|$'\n'|$'\r')  # Enter
                break
                ;;
            $'\003'|q|Q)  # Ctrl+C or q or Q
                tput cnorm 2>/dev/null; stty echo 2>/dev/null; trap - EXIT INT TERM
                printf "\e[%dA" "$count"
                printf "\nSelection cancelled\n" >&2
                return 130
                ;;
        esac

        # Move cursor back up (menu items + help text line)
        printf "\e[%dA" "$((count + 1))"
    done

    # Cleanup terminal
    tput cnorm 2>/dev/null
    stty echo 2>/dev/null
    trap - EXIT INT TERM

    # Clear menu if configured
    if $MENU_CLEAR_AFTER_SELECT; then
        printf "\e[%dA" "$count"
        for (( i=0; i<count; i++ )); do printf "\e[2K\n"; done
        printf "\e[%dA" "$count"
    fi

    # Set result and display selection
    printf -v "$outvar" "${return_values[$cur]}"
    #echo "Selected: ${display_options[$cur]} (value: ${return_values[$cur]})"

    return 0
}

# ============================================
# UTILITY FUNCTIONS
# ============================================
function pause_for_key() {
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
}

function show_header() {
    clear
    figlet "Project Launcher"
}

# ============================================
# MAIN SCRIPT
# ============================================

show_header

while true; do
advanced_menu_selector "Choose an action:" choice "Instagram analysis" "Film" "Stocks" "SSH Raspberry Pi" "Restart" "Exit"
# Check if user cancelled (pressed q, Q, or Ctrl+C)
if [[ $? -eq 130 ]]; then
    clear
    break
fi

if [[ "$choice" == "Instagram analysis" ]]; then
  cd "$HOME/Desktop/Programming/0 Done/Instagram_Analysis"
  conda run -n base python instagram_comparison.py
  pause_for_key
  show_header
elif [[ "$choice" == "Film" ]]; then
  cd "$HOME/Desktop/Movie" && node .
  show_header
elif [[ "$choice" == "Stocks" ]]; then
  echo "Opens in VScode..."
  code -n "$HOME/Desktop/Programming/1 Work in progress/Stock_marked/notebooks"
  show_header
elif [[ "$choice" == "SSH Raspberry Pi" ]]; then
  clear
  ssh frederik3650@192.168.50.223
elif [[ "$choice" == "Restart" ]]; then
  exec "$0"
elif [[ "$choice" == "Exit" ]]; then
  clear
  break
else
  echo "You chose: $choice"
fi
done
