cmake_minimum_required(VERSION 3.24)
project(dynamic-island LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Gui Quick QuickTest DBus Network Widgets ShaderTools)
find_package(KF6CalendarCore REQUIRED)
find_package(KF6GuiAddons REQUIRED)
find_package(KF6Config REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(DBUS1 REQUIRED IMPORTED_TARGET dbus-1)
find_package(LayerShellQt REQUIRED)
qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(dynamic-island src/main.cpp)
qt_add_qml_module(dynamic-island
    URI Island
    SOURCES src/inputregion.h src/inputregion.cpp src/notifier.h src/notifier.cpp src/systemstatus.h src/systemstatus.cpp src/appconfig.h src/appconfig.cpp src/calendarsource.h src/calendarsource.cpp src/clipboardhistory.h src/clipboardhistory.cpp src/notesstore.h src/notesstore.cpp src/notificationwatcher.h src/notificationwatcher.cpp src/bluetoothwatcher.h src/bluetoothwatcher.cpp src/plasmasettings.h src/plasmasettings.cpp src/camerawatcher.h src/camerawatcher.cpp
    QML_FILES qml/Main.qml qml/logic.js qml/PlayerSource.qml qml/MprisPlayers.qml qml/Bars.qml qml/Island.qml qml/ControlButton.qml qml/CoverArt.qml qml/MusicPlayer.qml qml/HomePanel.qml qml/TimerModel.qml qml/TimerCard.qml qml/QuickButtons.qml qml/weather.js qml/WeatherSource.qml qml/WeatherCard.qml qml/MonthCalendar.qml qml/UpNext.qml qml/MusicCard.qml qml/Prefs.qml qml/Tape.qml qml/TimerTab.qml qml/Pill.qml qml/PixelCat.qml qml/IdleArt.qml qml/VolumeSlider.qml qml/Mixer.qml qml/SoundSource.qml qml/SettingsWindow.qml qml/ClipboardTab.qml qml/NotesTab.qml qml/AlertView.qml qml/ShelfTab.qml qml/QuickLinksTab.qml qml/ColorTab.qml
)
target_include_directories(dynamic-island PRIVATE src)
qt_add_shaders(dynamic-island "shaders" PREFIX "/" FILES shaders/aurora.frag shaders/wave.frag shaders/fireflies.frag)
target_link_libraries(dynamic-island PRIVATE Qt6::Widgets Qt6::Quick Qt6::DBus Qt6::Network KF6::CalendarCore KF6::GuiAddons KF6::ConfigCore PkgConfig::DBUS1 LayerShellQt::Interface)

include(GNUInstallDirs)
install(TARGETS dynamic-island)

enable_testing()
find_program(QMLTESTRUNNER qmltestrunner HINTS ${QT6_INSTALL_PREFIX}/${QT6_INSTALL_BINS} /usr/lib/qt6/bin REQUIRED)
add_test(NAME qml COMMAND ${QMLTESTRUNNER} -input ${CMAKE_SOURCE_DIR}/tests -import ${CMAKE_BINARY_DIR})

configure_file(data/dynamic-island.desktop.in dynamic-island.desktop @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/dynamic-island.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

find_package(Qt6 REQUIRED COMPONENTS Test)
qt_add_executable(tst_systemstatus tests/cpp/tst_systemstatus.cpp src/systemstatus.cpp src/systemstatus.h)
target_include_directories(tst_systemstatus PRIVATE src)
target_link_libraries(tst_systemstatus PRIVATE Qt6::Test Qt6::Gui Qt6::DBus Qt6::Qml)
add_test(NAME cpp_systemstatus COMMAND tst_systemstatus)

qt_add_executable(tst_calendar tests/cpp/tst_calendar.cpp src/calendarsource.cpp src/calendarsource.h)
target_include_directories(tst_calendar PRIVATE src)
target_link_libraries(tst_calendar PRIVATE Qt6::Test Qt6::Network Qt6::Qml KF6::CalendarCore)
add_test(NAME cpp_calendar COMMAND tst_calendar)

qt_add_executable(tst_appconfig tests/cpp/tst_appconfig.cpp src/appconfig.cpp src/appconfig.h)
target_include_directories(tst_appconfig PRIVATE src)
target_link_libraries(tst_appconfig PRIVATE Qt6::Test Qt6::Qml)
add_test(NAME cpp_appconfig COMMAND tst_appconfig)

qt_add_executable(tst_clipboard tests/cpp/tst_clipboard.cpp src/clipboardhistory.cpp src/clipboardhistory.h)
target_include_directories(tst_clipboard PRIVATE src)
target_link_libraries(tst_clipboard PRIVATE Qt6::Test Qt6::Gui Qt6::Qml KF6::GuiAddons)
add_test(NAME cpp_clipboard COMMAND tst_clipboard)

qt_add_executable(tst_notes tests/cpp/tst_notes.cpp src/notesstore.cpp src/notesstore.h)
target_include_directories(tst_notes PRIVATE src)
target_link_libraries(tst_notes PRIVATE Qt6::Test Qt6::Qml)
add_test(NAME cpp_notes COMMAND tst_notes)

qt_add_executable(tst_watchers tests/cpp/tst_watchers.cpp src/notificationwatcher.cpp src/notificationwatcher.h src/bluetoothwatcher.cpp src/bluetoothwatcher.h
    src/plasmasettings.cpp src/plasmasettings.h src/camerawatcher.cpp src/camerawatcher.h)
target_include_directories(tst_watchers PRIVATE src)
target_link_libraries(tst_watchers PRIVATE Qt6::Test Qt6::Gui Qt6::DBus Qt6::Qml KF6::ConfigCore PkgConfig::DBUS1)
add_test(NAME cpp_watchers COMMAND tst_watchers)
set_tests_properties(cpp_watchers PROPERTIES ENVIRONMENT QT_QPA_PLATFORM=offscreen)
