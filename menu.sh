#!/usr/bin/env bash

# ============================================
# CONFIGURATION
# ============================================
MENU_SELECTOR_SYMBOL=">"
MENU_SELECTED_COLOR=$'\e[1;34m'  # Bold Blue
MENU_NORMAL_COLOR=$'\e[0m'        # Reset
MENU_CURSOR_VISIBLE=false
MENU_CLEAR_AFTER_SELECT=true
BROWSE_DIR="$HOME/Desktop"

# ============================================
# TERMINAL HELPER
# ============================================
function _term_restore() {
    tput cnorm 2>/dev/null
    stty echo 2>/dev/null
    trap - EXIT INT TERM
}

# ============================================
# MENU SELECTOR
# ============================================
# Usage:
#   menu_select "Prompt" result_var "Opt A" "Opt B"
#   menu_select "Prompt" result_var "Display A" "Display B" -- "val_a" "val_b"
#
# Returns: 0=selected, 1=error, 130=cancelled
# ============================================
function menu_select() {
    local -r prompt="$1" outvar="$2"
    shift 2
    local -a display_options=() return_values=()
    local parsing_display=true

    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--" ]]; then
            parsing_display=false; shift; continue
        fi
        $parsing_display && display_options+=("$1") || return_values+=("$1")
        shift
    done

    (( ${#return_values[@]} == 0 )) && return_values=("${display_options[@]}")

    local -r count=${#display_options[@]}
    if (( count == 0 )); then
        echo "Error: No options provided" >&2; return 1
    fi
    if (( ${#display_options[@]} != ${#return_values[@]} )); then
        echo "Error: Mismatched display and return value counts" >&2; return 1
    fi

    local cur=0
    $MENU_CURSOR_VISIBLE || tput civis 2>/dev/null
    trap '_term_restore' EXIT INT TERM
    stty -echo 2>/dev/null

    printf "%s\n" "$prompt"

    while true; do
        for (( i=0; i<count; i++ )); do
            if (( i == cur )); then
                printf " %s%s %s %s\n" "$MENU_SELECTOR_SYMBOL" "$MENU_SELECTED_COLOR" "${display_options[i]}" "$MENU_NORMAL_COLOR"
            else
                printf "   %s\n" "${display_options[i]}"
            fi
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
            $'\003'|q|Q)
                _term_restore
                printf "\e[%dA" "$count"
                printf "\nSelection cancelled\n" >&2
                return 130
                ;;
        esac

        printf "\e[%dA" "$((count + 1))"
    done

    _term_restore

    # Clear prompt + options + help text (count + 2 lines)
    if $MENU_CLEAR_AFTER_SELECT; then
        printf "\e[%dA" "$((count + 2))"
        for (( i=0; i<count+2; i++ )); do printf "\e[2K\n"; done
        printf "\e[%dA" "$((count + 2))"
    fi

    printf -v "$outvar" "%s" "${return_values[$cur]}"
    return 0
}

# ============================================
# UTILITIES
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
# PATH SELECTOR (shared logic for files/folders)
# ============================================
function _select_paths() {
    local -r prompt="$1" outvar="$2" dir="$3" type="$4"

    if [[ -z "$dir" || ! -d "$dir" ]]; then
        echo "Error: Directory not found: $dir" >&2; return 1
    fi

    local -a paths=() names=()
    while IFS= read -r p; do
        paths+=("$p")
        names+=("$(basename "$p")")
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -type "$type" -print | sort)

    if (( ${#paths[@]} == 0 )); then
        echo "No entries found in: $dir" >&2; return 1
    fi

    menu_select "$prompt" "$outvar" "${names[@]}" -- "${paths[@]}"
}

function select_file_from_dir()   { _select_paths "$1" "$2" "$3" f; }
function select_folder_from_dir() { _select_paths "$1" "$2" "$3" d; }


# ============================================
# MAIN
# ============================================
show_header

while true; do
    menu_select "Choose an action:" choice \
        "Instagram analysis" "Film" "Stocks" "SSH Raspberry Pi" \
        "File selector" "Folder selector" "Exit"

    case $? in
        130) clear; break ;;
        1)   continue ;;
    esac

    case "$choice" in
        "Instagram analysis")
            cd "$HOME/Desktop/Programming/0_Done/Instagram_Analysis"
            conda run -n base python instagram_comparison.py
            pause_for_key; show_header
            ;;
        "Film")
            cd "$HOME/Desktop/Programming/1_Work_in_progress/Movie" && node .
            show_header
            ;;
        "Stocks")
            echo "Opens in VScode..."
            code -n "$HOME/Desktop/Programming/1_Work_in_progress/Stock_marked/notebooks"
            show_header
            ;;
        "SSH Raspberry Pi")
            clear
            ssh frederik3650@192.168.50.223
            ;;
        "File selector")
            select_file_from_dir "Select a file:" selected_file "$BROWSE_DIR" \
                && echo "Selected file: $selected_file"
            pause_for_key; show_header
            ;;
        "Folder selector")
            select_folder_from_dir "Select a folder:" selected_folder "$BROWSE_DIR" \
                && echo "Selected folder: $selected_folder"
            pause_for_key; show_header
            ;;
        "Exit")
            _term_restore
            clear
            exit 0
            ;;
    esac
done