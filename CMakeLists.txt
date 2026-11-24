cmake_minimum_required(VERSION 3.16)
project(dynamic-island LANGUAGES CXX)

# Port for Plasma 5 on X11 (Qt 5.15 / KDE Frameworks 5).
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt5 5.15 REQUIRED COMPONENTS Gui Quick DBus Network Widgets Concurrent X11Extras)
find_package(KF5CalendarCore REQUIRED)
find_package(KF5GuiAddons REQUIRED)
find_package(KF5Config REQUIRED)
find_package(KF5IdleTime REQUIRED)
find_package(KF5GlobalAccel REQUIRED)
find_package(KF5WindowSystem REQUIRED)
find_package(X11 REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(DBUS1 REQUIRED IMPORTED_TARGET dbus-1)

# Everything but main.cpp, shared by the app and the QML test runner.
set(SOURCES
    src/mprisplayers.cpp src/islandpalette.cpp
    src/inputregion.cpp src/notifier.cpp src/systemstatus.cpp src/appconfig.cpp src/calendarsource.cpp
    src/clipboardhistory.cpp src/notesstore.cpp src/todostore.cpp src/covercolor.cpp src/blursettings.cpp
    src/windowactivator.cpp src/notificationwatcher.cpp src/notificationlog.cpp src/bluetoothwatcher.cpp
    src/plasmasettings.cpp src/camerawatcher.cpp src/capslockwatcher.cpp src/updateswatcher.cpp
    src/jobwatcher.cpp src/fullscreenwatcher.cpp src/panelshortcut.cpp src/mpriseeks.cpp)
file(GLOB HEADERS src/*.h)

add_library(island-core STATIC ${SOURCES} ${HEADERS})
target_include_directories(island-core PUBLIC src)
target_link_libraries(island-core PUBLIC Qt5::Widgets Qt5::Quick Qt5::DBus Qt5::Network Qt5::Concurrent Qt5::X11Extras
    KF5::CalendarCore KF5::GuiAddons KF5::ConfigCore KF5::IdleTime KF5::GlobalAccel KF5::WindowSystem
    PkgConfig::DBUS1 ${X11_LIBRARIES} ${X11_Xext_LIB})

add_executable(dynamic-island src/main.cpp resources.qrc)
target_link_libraries(dynamic-island PRIVATE island-core)

option(BUILD_TESTING "Build the QML tests (needs Qt 5's QuickTest and qml-module-qttest)" ON)
if(BUILD_TESTING)
    find_package(Qt5 5.15 REQUIRED COMPONENTS QuickTest)
    enable_testing()
    add_executable(tst_qml tests/qmltest.cpp)
    target_link_libraries(tst_qml PRIVATE island-core Qt5::QuickTest)
    target_compile_definitions(tst_qml PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_SOURCE_DIR}/tests")
    # The runner hides its windows itself (offscreen), so it also runs without a display.
    add_test(NAME qml COMMAND tst_qml)
endif()

include(GNUInstallDirs)
install(TARGETS dynamic-island DESTINATION ${CMAKE_INSTALL_BINDIR})

configure_file(data/dynamic-island.desktop.in dynamic-island.desktop @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/dynamic-island.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
