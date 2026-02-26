# Function to apply a random theme
apply_random_theme() {
    local random_index=$((RANDOM % ${#themes[@]}))
    local selected_theme=${themes[$random_index]}
    echo "Applying random theme: $selected_theme"
    # Apply the theme settings
    apply_theme "$selected_theme"
    # Additional commands to apply wallpaper, rofi, waybar can be added here
}

# Modify the main script logic
while [[ "$1" == -* ]]; do
    case "$1" in
        -r|--random)
            apply_random_theme
            exit 0
            ;; 
        *)
            # Handle other flags here
            exit 1
            ;;
    esac
    shift
}