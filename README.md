# Dynamic Island for KDE Plasma

A notch at the top of the screen for KDE Plasma 6 on Wayland. It shows what's playing, takes over volume and notification popups, and opens into a small panel with a calendar, weather, a timer and a few tools.

I wanted something like the Dynamic Island on macOS for my Arch setup, inspired by Notchy. I built it with Claude as a coding assistant: Claude wrote most of the code, and I decided what it should do and tried it out on my laptop as it grew.

It runs on my machine (CachyOS, Plasma 6, Wayland). It hasn't been tested anywhere else yet.

Here's a 16-second demo, recorded on my laptop with demo data:


https://github.com/user-attachments/assets/41d47ead-64d6-4dfa-99cd-7c2cd56dae01



## What it does

### Closed pill

- Cover art and a small level meter while music plays, or the countdown while a timer runs. With both, it switches between them, and a touchpad swipe switches by hand.
- When nothing is going on, it shows a glance (an event starting soon, low battery, the time, the weather) or an animation: aurora, wave, fireflies, a pixel cat, or your own GIF or WebP.
- While a download, copy or extraction runs, it takes a turn too: the file name or "3 jobs", the combined percent and a thin line filling along the bottom. Point at it to see each job and its time left. On the music and timer turns, a small blue chip shows jobs are running.
- Point at it to see the song title. Click it, or press Meta+N from anywhere, to open the panel. Meta+N again or Esc closes it. The key can be changed in System Settings → Shortcuts.
- Choose between a notch joined to the top edge or a floating pill. Switching animates.

### Short alerts in the pill

- Volume and brightness levels, and Caps Lock turning on or off, replacing Plasma's on-screen box.
- Notifications, replacing Plasma's popups. Click one to open the app.
- Every notification is also saved, even ones that never popped up (do not disturb, a locked screen, the panel open). On the idle pill, an amber bell chip counts the ones you haven't looked at yet.
- Downloads and copies finishing or failing. Click a finished one to open its folder.
- An app starting to use the microphone or camera, Bluetooth devices connecting, and the charger being plugged in or out.
- Over a full-screen game or film, alerts still come to the front for a moment. Notifications only do when their app is on your urgent list (or marked critical), unless "Show all notifications" is on. Each kind can be turned off under Settings → Alerts → Over full-screen apps.

### Panel tabs

- Home: music, the month calendar, weather for the next few hours, upcoming events with a Join button for Meet, Zoom and Teams links, and the timer.
- Music: cover with a soft colour glow, seeking, shuffle, repeat and player volume.
- Timer: drag the minute tape or pick a preset.
- Sound mixer: output and input devices, mic level, and per-app volume.
- Notifications: the saved ones from the last 7 days, grouped by app, with the new ones marked. Click one to open its app. Settings choose how long they're kept and which kinds and apps are saved.
- From the `⋯` menu: clipboard history, notes, a shelf for dragged files, quick links to sites and folders, and a colour picker.

### Quick buttons

The panel has buttons for battery, volume, Wi-Fi, Bluetooth, do not disturb, keeping the screen awake, screenshot and lock.

## Requirements

- KDE Plasma 6 on Wayland. The island is a layer-shell surface and uses KWin and Plasma services, so it won't work on X11 or other desktops.
- Browser downloads show only with Plasma's browser integration add-on installed in the browser.
- It imports Plasma's private MPRIS and volume QML modules. A Plasma update can change those and break the music or mixer parts.

Packages on Arch:

```sh
sudo pacman -S --needed cmake ninja qt6-base qt6-declarative qt6-shadertools \
    layer-shell-qt kirigami kcalendarcore kguiaddons kconfig kidletime kglobalaccel \
    plasma-workspace plasma-pa wireplumber networkmanager bluez-utils spectacle
```

The quick buttons call `wpctl`, `nmcli`, `bluetoothctl`, `spectacle` and `loginctl`.

## Build and run

```sh
cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build build
./build/dynamic-island
```

To install it and add it to the app menu:

```sh
cmake --install build
```

Start at login is a switch in Settings → General.

Run the tests with:

```sh
cd build && ctest
```

## Settings

Open Settings with the gear button in the panel. It covers the style and accent colour, sizes, behaviour, which alerts to show, the idle pill, calendars, weather, quick buttons and quick links.

For calendar events, paste a calendar's secret iCal address (Google Calendar → Settings → your calendar → Integrate calendar → Secret address in iCal format). The address is kept in the config file and never shown or logged.

Weather comes from [Open-Meteo](https://open-meteo.com). The location is found from your IP address through geojs.io, or you can set a city in Settings.

## Where things are stored

- Settings: `~/.config/dynamic-island.conf` (only readable by you, since it can hold calendar addresses)
- Clipboard history: `~/.local/share/dynamic-island/clipboard`
- Notes: `~/.local/share/dynamic-island/notes`, one text file per note
- Saved notifications: `~/.local/share/dynamic-island/notifications.json` (only readable by you, since it holds message text)

## License

MIT, see [LICENSE](LICENSE).
