# Disclaimer and Setup

Just my Setup for hyprland, hyprpaper, waybar, wlogout, rofi, ghostty and wallpapers (with a simple themeselector script). 

Uses some files from: 

- ml4w (https://www.ml4w.com/)
  > &#8593; the beginning of my rice was a modified version of one of his old setups.

- Keyitdev (https://github.com/Keyitdev/sddm-astronaut-theme/tree/master)
  > &#8593; his install script is straight up used in the install.sh script of mine at the end.

- newmanls (https://github.com/newmanls/rofi-themes-collection?tab=readme-ov-file)
  > &#8593; changed colors of rounded themes to match the wallpapers.

But be aware:

- The script is written with the assistance of Ai.

- Im a beginner in this sort of stuff so its not optimised or anything.

- Tested in a VM and my personal setup, but it might still cause problems.

If you find any obvious problems be sure to reach out!

# Automatic install:
```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/Syntr1x/dotfiles/master/install.sh)"
```
# Keybinds 

-$mainMod, W, exec, killall -SIGUSR1 waybar # Hide toggle waybar

-$mainMod, Q, exec, ghostty # Open TTY

-$mainMod, C, killactive # Close current window

-$mainMod, M, exit # Exit Hyprland

-$mainMod, E, exec, ~/.config/hypr/scripts/filemanager.sh # Opens the filemanager

-$mainMod, T, togglefloating # Toggle between tiling and floating window

-$mainMod, F, fullscreen # Open the window in fullscreen

-$mainMod, R, exec, rofi -show drun # Open rofi

-$mainMod, P, pseudo, # dwindle

-$mainMod, J, togglesplit, # dwindle

-$mainMod, B, exec, ~/.config/hypr/scripts/browser.sh # Opens the browser

-$mainMod SHIFT, B, exec, ~/.config/hypr/scripts/reload-waybar.sh # Reload Waybar

-$mainMod SHIFT, W, exec, ~/.config/hypr/scripts/reload-hyprpaper.sh # Reload hyprpaper after a changing the wallpaper

-$mainMod SHIFT, R, exec, killall rofi # kills rofi


# This is only an example how it looks out of the box:

- Anime bs wont be in the fastfetch config when installed via the script, dont worry.
- There is also a waybar border option that is toggleable in the themeselect.sh script if you want that, just havent attached the images yet (or wont cause thats gonna be alot more of images i need to paste in here; will do that when i find a better way to showcase the themes).

**Beige:**
![image](https://github.com/user-attachments/assets/f70eaccf-d803-4396-adcd-7e8e4d33efd7)
![image](https://github.com/user-attachments/assets/864d08ec-976c-402b-933e-39221267e4b7)
![image](https://github.com/user-attachments/assets/50fa9bbb-2620-48de-a9b4-3c72844cffc8)
**Dark:**
![image](https://github.com/user-attachments/assets/06940b03-4069-4a54-9138-ba36b22ed335)
![image](https://github.com/user-attachments/assets/0574ac31-3494-43d7-b6ee-520f70843d33)
![image](https://github.com/user-attachments/assets/f3b54c55-e958-4f3f-9963-91b9a624b0ed)
**Pinkish:**
![image](https://github.com/user-attachments/assets/30181923-6cf0-4283-a0d5-84b2f01dc33f)
![image](https://github.com/user-attachments/assets/b199c1b1-26e0-47d0-be9b-c89ae5c4a7ea)
![image](https://github.com/user-attachments/assets/2f4c265f-a7b9-4148-86bc-66740c72bda1)
**Blue:**
![image](https://github.com/user-attachments/assets/8819a7db-62c8-42d2-b4c2-2e6f655e5c2a)
![image](https://github.com/user-attachments/assets/d974623d-061a-4248-917f-6c2ad7d3052e)
![image](https://github.com/user-attachments/assets/b5b51b9a-19e7-4225-9e0f-449194b88afa)
**Orange:**
![image](https://github.com/user-attachments/assets/a213e028-5723-4d4e-92d6-ea1aee4db1c8)
![image](https://github.com/user-attachments/assets/79d0fdcc-3c26-4f42-b7ed-4755ff856876)
![image](https://github.com/user-attachments/assets/379e775d-429b-4f44-9fc9-db2f6093aa0a)
**Retro-ish**
![image](https://github.com/user-attachments/assets/5b40da5b-7250-4828-ba80-d4b53ebf4a10)
![image](https://github.com/user-attachments/assets/739ac406-ec77-477e-a403-9728a4941349)
![image](https://github.com/user-attachments/assets/627aa0c5-02e6-4eaa-b843-78f2cf94a083)

