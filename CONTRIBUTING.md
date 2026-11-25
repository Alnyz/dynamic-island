# Contributing

Thanks for helping with the island. Bug reports, ideas and pull requests are all welcome.

By taking part you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).

## Reporting a bug

Open an issue with:

- what you did, what you expected and what happened instead
- your Plasma, Qt and distribution versions
- for music or lyrics problems, the player you use (Spotify, a browser, mpv…), since players report songs differently
- a screenshot or short screen recording if it's something you can see

## Before you start on a change

For anything bigger than a small fix, open an issue first and say what you plan to do. It saves you from building something that clashes with work already under way.

## Building and testing

The packages and build steps are in the [README](README.md#requirements). In short:

```sh
cmake -S . -B build -G Ninja
cmake --build build
./build/dynamic-island
cd build && ctest
```

Close the island you normally run before starting one from the source folder, or you'll get two islands drawn on top of each other.

The interface tests are in `tests/`. To run one file while you work on it:

```sh
QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input tests/tst_island.qml -import build
```

(`/usr/lib/qt6/bin` is where Arch puts it; other distributions may use another folder.)

All tests must pass before a pull request is merged. A change to how something behaves should come with a test that fails without the change.

## Where things live

- `qml/`: the interface. `Island.qml` is the pill and the panel, `Main.qml` wires the sources to it.
- `qml/logic.js`: plain functions with no interface (layouts, parsing, timing). Put logic here when you can; it's the easiest part to test, in `tests/tst_logic.qml`.
- `src/`: small C++ helpers for things QML can't do (D-Bus, files, the window region). Each one is a QML type; add new files to `qt_add_qml_module` in `CMakeLists.txt`.
- Plasma's private MPRIS module is used only in `qml/MprisPlayers.qml`. Keep it that way, so a Plasma update that changes the module breaks one file, not many.

## Things to keep in mind

- **Privacy.** Anything that sends data off the computer must send as little as possible, have a switch in Settings and be described in the README's Settings section: what is sent, to whom, and how to turn it off.
- **Light on the system.** The island runs all day. Decorative extras, like the level bars and the idle animations, should not keep it redrawing when nothing changes. If your change animates something, check the island's CPU use before and after (`top -p $(pgrep -x dynamic-island)`).
- **Plain comments.** Comments say why something is done, in plain words. Match the style of the code around your change.

## Commits and pull requests

Commit messages start with a lowercase type and say what changes for the person using the island:

```
fix: keep one song clock, so reopening the island never jumps back to 0:00
feat: turn each lyrics source on or off in settings
```

Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs`, `build`, `chore`.

Keep one topic per pull request. In the description, say:

- **What** changes, as the person using the island would see it
- **Why** it's needed
- **Testing**: how you checked it, which tests you added, and screenshots for anything visual

## License

By contributing you agree that your work is released under the [MIT License](LICENSE), like the rest of the project.
