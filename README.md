# Dynamic Island for KDE Plasma 5 (X11)

A notch at the top of the screen for KDE Plasma 5 on X11. It shows what's playing, takes over volume and notification popups, and opens into a small panel with a calendar, weather, a timer and a few tools.

This is the `port/plasma5-x11` branch: a port of [Alnyz's Dynamic Island](https://github.com/Alnyz/dynamic-island), which is made for Plasma 6 on Wayland, to Qt 5.15 and KDE Frameworks 5, for distributions that still ship Plasma 5. It looks and works like the Plasma 6 version as of early November 2026; features added to `main` since then aren't here. Ported by [@viktorg1](https://github.com/viktorg1) with Claude as a coding assistant.

If you're on Plasma 6, use the [`main` branch](https://github.com/Alnyz/dynamic-island) instead.

Here's a 16-second demo of the Plasma 6 version (the port looks the same):


https://github.com/user-attachments/assets/41d47ead-64d6-4dfa-99cd-7c2cd56dae01



## Tested on

Ubuntu 22.04 with KDE Plasma 5.24, Qt 5.15 and KDE Frameworks 5.92, on X11, with two screens and Latte Dock. It hasn't been tried on other distributions yet.

Tried and working there: the pill with cover art, song title and level bars; the hover view; the panel's Home, Music and Sound Mixer tabs; the quick buttons; Settings; the shortcuts; and staying in place through panel changes and KWin restarts.

Not tried yet: replacing Plasma's notification and volume popups, behaviour over full-screen apps, clipboard history, notes and the To-Do list. Please open an issue if one of these misbehaves.

## What it does

### Closed pill

- Cover art, the song's title and a small level meter that follows the sound while music plays. A title too long to fit scrolls slowly from right to left. While a timer runs it shows the countdown; with both, it switches between them, and a touchpad swipe switches by hand.
- Point at the battery ring for the charge, whether it's charging, and the time until full or empty.
- When nothing is going on, it shows a glance (an event starting soon, low battery on the laptop or a Bluetooth device, your next To-Do task with a circle to tick it off, the time, the weather, how many system updates are waiting, off by default; click the count to see the packages and update them in a terminal) or an animation: aurora, wave, fireflies, a pixel cat, or your own GIF or WebP.
- While a download, copy or extraction runs, it takes a turn too: the file name or "3 jobs", the combined percent and a thin line filling along the bottom. Point at it to see each job and its time left. On the music and timer turns, a small blue chip shows jobs are running.
- Scroll up or down on it to change the volume, or the minutes left while the timer shows. Middle-click plays or pauses.
- Point at it to see the song title, a seek bar you can drag, and previous, play/pause and next buttons. Click it, or press Meta+N (or Meta+Alt+N) from anywhere, to open the panel. The same keys or Esc close it. With the panel open from the keyboard, 1–9 or Tab switch tabs, Space plays or pauses and ←/→ seek 5 seconds. Meta+Shift+V opens clipboard history with the search box ready. Both keys can be changed in System Settings → Shortcuts → Dynamic Island.
- Right-click it for a quick menu: pause notifications for an hour, start a 5, 10 or 25 minute timer, hide the island for an hour (the panel shortcut brings it back), or open Settings.
- Choose between a notch joined to the top edge or a floating pill. Switching animates.
- Dark or light colours (or follow Plasma's colour scheme), or any colour of your own; text turns dark or light to stay readable. An opacity slider makes it see-through, with KWin's blur behind it if you like. The blur strength slider changes KWin's own setting, so it applies to every blurred window.

### Short alerts in the pill

- Volume and brightness levels, and Caps Lock or Num Lock turning on or off, replacing Plasma's on-screen box.
- Notifications, replacing Plasma's popups. Click one to open it in its app, and use the app's own buttons (Mark as read, Accept, ...) right on the alert. Typed replies stay in Plasma's own popup: only Plasma can deliver them to the app.
- Every notification is also saved, even ones that never popped up (do not disturb, a locked screen, the panel open). On the idle pill, an amber bell chip counts the ones you haven't looked at yet; click it to open them.
- Downloads and copies finishing or failing. Click a finished one to open its folder.
- An app starting to use the microphone or camera, Bluetooth devices connecting, and the charger being plugged in or out.
- Over a full-screen game or film, alerts still come to the front for a moment. Notifications only do when their app is on your urgent list (or marked critical), unless "Show all notifications" is on. Each kind can be turned off under Settings → Alerts → Over full-screen apps.

### Panel tabs

- Home: music, the month calendar (click a day to see its events; public holidays in orange, festivals with an orange dot), weather for the next few hours (click it for the full forecast on weather.com), upcoming events with a Join button for Meet, Zoom and Teams links, and the timer.
- Music: cover with a soft colour glow, seeking, shuffle, repeat and player volume. With more than one player open, chips pick which one the island follows. The level bars, seek bars and a thin edge on the pill take the cover's main colour (Settings → Look). The lyrics button shows synced lyrics from LRCLIB; click a line to jump to it.
- Timer: drag the minute tape or pick a preset, or start a Pomodoro (25 minutes of focus, 5 minute breaks, a long one every fourth). The pill's countdown turns red while focusing and green on a break.
- Sound mixer: output and input devices, mic level, and per-app volume.
- Notifications: the saved ones from the last 7 days, grouped by app, with the new ones marked. Click one to open its app. Settings choose how long they're kept and which kinds and apps are saved.
- To-Do: add tasks, tick them off and clear the done ones.
- Deleting a note, clipboard item or task shows Undo for a few seconds.
- From the `⋯` menu: clipboard history, notes, a shelf for dragged files, quick links to sites and folders, and a colour picker.

### Quick buttons

The panel has buttons for battery, volume, Wi-Fi, Bluetooth (with a badge for a connected device's battery), do not disturb, keeping the screen awake, screenshot and lock.

## How it differs from the Plasma 6 version

- **The window.** X11 has no layer shell, so the island is a frameless window of the notification type, centred at the top of the primary screen, above panels and on every desktop. While a full-screen window covers it, it becomes an on-screen-display window to stay in front. Clicks outside the pill pass through to the windows below (an X shape input region). If KWin moves it, for example when a panel's reserved space changes, it moves straight back.
- **Compositing.** See-through areas need KWin's compositing. While compositing is off (KWin restarting, or Alt+Shift+F12), the window is clipped to the pill's shape, so it never shows as a black box.
- **Music** comes from a small MPRIS client in C++ (`src/mprisplayers.cpp`), since Plasma 5 has no private MPRIS QML module.
- **Shortcut.** The panel opens with Meta+N or Meta+Alt+N. When Meta+N is already taken (Latte Dock uses it for its task entries), only Meta+Alt+N is set.
- **System tools.** Volume buttons use `pactl` (Ubuntu 22.04's `wpctl` can't set the volume), and the update count uses `apt list --upgradable`; clicking it runs `sudo apt update && apt upgrade` in Konsole.
- **Under the hood.** QML uses Qt 5 imports and Qt Graphical Effects, colours go through a shared `ipal` object instead of Qt 6's per-item `palette`, the idle animations are plain OpenGL GLSL, and the KWin scripts use the KWin 5 API.
- **Tests.** The QML and C++ tests still target Qt 6 and aren't built on this branch.

## Requirements

- KDE Plasma 5 on X11, with KWin as the window manager and compositing on. It always runs through X11 (it sets `QT_QPA_PLATFORM=xcb`), and it won't work on other desktops.
- Qt 5.15 and KDE Frameworks 5.
- Browser downloads show only with Plasma's browser integration add-on installed in the browser.
- It imports Plasma 5's private volume QML module (`org.kde.plasma.private.volume`). A Plasma update can change it and break the mixer.

Packages on Ubuntu 22.04:

```sh
sudo apt install cmake ninja-build extra-cmake-modules libdbus-1-dev libx11-dev libqt5x11extras5-dev \
    qtbase5-dev qtbase5-private-dev qtdeclarative5-dev qtquickcontrols2-5-dev \
    libkf5calendarcore-dev libkf5config-dev libkf5globalaccel-dev libkf5guiaddons-dev libkf5idletime-dev libkf5windowsystem-dev \
    qml-module-qtgraphicaleffects qml-module-qtquick-shapes qml-module-qt-labs-settings qml-module-qt-labs-platform \
    qml-module-qtquick-dialogs qml-module-org-kde-kirigami2 plasma-pa network-manager bluez kde-spectacle
```

The quick buttons call `pactl`, `nmcli`, `bluetoothctl`, `spectacle` and `loginctl`, and the update count calls `apt` and `konsole`.

## Build and run

```sh
git clone -b port/plasma5-x11 https://github.com/Alnyz/dynamic-island.git
cd dynamic-island
cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build
./build/dynamic-island
```

To install it to `~/.local/bin` and add it to the app menu:

```sh
cmake --install build
```

Start at login is a switch in Settings → General.

## Settings

Open Settings with the gear button in the panel. It covers the style and accent colour, sizes, behaviour, which alerts to show, the idle pill, calendars, weather, quick buttons and quick links.

Public holidays and festivals come from Google's public holiday calendar for your country, picked from your system language (for example en_IN gives India). Choose another country, turn festivals off, or turn holidays off in Settings → Calendar.

For calendar events, paste a calendar's secret iCal address (Google Calendar → Settings → your calendar → Integrate calendar → Secret address in iCal format). The address is kept in the config file and never shown or logged.

Browsers often leave out the cover of a song you skip to. When one is missing, the island looks the song up on the iTunes Search API, sending only the artist and title. Turn this off in Settings → Behaviour.

Lyrics come from [LRCLIB](https://lrclib.net), only while the lyrics view is open; the artist, title, album and length are sent. Turn them off in Settings → Behaviour.

Weather comes from [Open-Meteo](https://open-meteo.com). The location is found from your IP address through geojs.io, or you can set a city in Settings. When the IP lookup has no city name, the place is named from its coordinates through BigDataCloud.

## Where things are stored

- Settings: `~/.config/dynamic-island.conf` (only readable by you, since it can hold calendar addresses)
- Clipboard history: `~/.local/share/dynamic-island/clipboard`
- Notes: `~/.local/share/dynamic-island/notes`, one text file per note
- To-Do list: `~/.local/share/dynamic-island/todo.json`
- Saved notifications: `~/.local/share/dynamic-island/notifications.json` (only readable by you, since it holds message text)
- Start at login: `~/.config/autostart/dynamic-island.desktop`

## License

MIT, see [LICENSE](LICENSE).
