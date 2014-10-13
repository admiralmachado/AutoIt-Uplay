# AutoIt-Uplay

(Windows-Only) Uses AutoIt to automate launching games with Uplay DRM and closing Uplay once the game finishes. Ideal for those using Steam in Big Picture Mode or anyone else who doesn't want to deal with Uplay.

## Quick Start

1. Download the latest release
2. Rename the .exe to something unique related to your game (e.g. "watch_dogs.exe")
3. Start the program
4. Browse to the game's .exe file (Usually in C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\\&lt;Game Folder&gt;)
5. Test to make sure setup worked correctly. If not, delete the .ini file that was created (e.g. "watch_dogs.ini") and go back to step 3.
6. For additional games, copy the .exe and go back to Step 2.

## A Warning About Uplay Cloud Save Sync

Uplay will attempt to sync your save after the game closes. Because this tool kills Uplay once the game finishes, the sync process might get interrupted, corrupting your save file. __I've never seen this myself while running this tool,__ but I figure since [Uplay has enough trouble syncing saves on its own](https://www.google.com/search?q=uplay+cloud+save+sync+corruption) it doesn't hurt to be too careful.

To avoid this, just turn off "Cloud Save Sychronization" or have Uplay always start in Offline mode.

## Bugs and Suggestions

This is my first project using AutoIt so there are bound to be bugs and places where it can be improved. If you see a problem, please create an issue.

If you're interested in contributing feel free to pick up an open issue (or create one) and send a pull request.