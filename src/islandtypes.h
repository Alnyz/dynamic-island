#pragma once

// The C++ types the QML uses, under "Island" 1.0. Shared by the app and the QML test runner,
// since Qt 5 has no qt_add_qml_module to register them.

#include <QtQml/qqml.h>

#include "appconfig.h"
#include "bluetoothwatcher.h"
#include "blursettings.h"
#include "calendarsource.h"
#include "camerawatcher.h"
#include "capslockwatcher.h"
#include "clipboardhistory.h"
#include "covercolor.h"
#include "fullscreenwatcher.h"
#include "inputregion.h"
#include "islandpalette.h"
#include "jobwatcher.h"
#include "mprisplayers.h"
#include "mpriseeks.h"
#include "notesstore.h"
#include "notificationlog.h"
#include "notificationwatcher.h"
#include "notifier.h"
#include "panelshortcut.h"
#include "plasmasettings.h"
#include "systemstatus.h"
#include "todostore.h"
#include "updateswatcher.h"
#include "windowactivator.h"

template<typename T>
static void registerSingleton(const char *name)
{
    qmlRegisterSingletonType<T>("Island", 1, 0, name, [](QQmlEngine *, QJSEngine *) -> QObject * {
        return new T;
    });
}

inline void registerIslandTypes()
{
    const char *uri = "Island";
    qmlRegisterType<CameraWatcher>(uri, 1, 0, "CameraWatcher");
    qmlRegisterType<BluetoothWatcher>(uri, 1, 0, "BluetoothWatcher");
    qmlRegisterType<CalendarSource>(uri, 1, 0, "CalendarSource");
    qmlRegisterType<PanelShortcut>(uri, 1, 0, "PanelShortcut");
    qmlRegisterType<NotificationLog>(uri, 1, 0, "NotificationLog");
    qmlRegisterType<CoverColor>(uri, 1, 0, "CoverColor");
    qmlRegisterType<TodoStore>(uri, 1, 0, "TodoStore");
    qmlRegisterType<JobWatcher>(uri, 1, 0, "JobWatcher");
    qmlRegisterType<CapsLockWatcher>(uri, 1, 0, "CapsLockWatcher");
    qmlRegisterType<ClipboardHistory>(uri, 1, 0, "ClipboardHistory");
    qmlRegisterType<NotesStore>(uri, 1, 0, "NotesStore");
    qmlRegisterType<FullScreenWatcher>(uri, 1, 0, "FullScreenWatcher");
    qmlRegisterType<UpdatesWatcher>(uri, 1, 0, "UpdatesWatcher");
    qmlRegisterType<BlurSettings>(uri, 1, 0, "BlurSettings");
    qmlRegisterType<NotificationWatcher>(uri, 1, 0, "NotificationWatcher");
    qmlRegisterType<MprisPlayers>(uri, 1, 0, "MprisPlayers");
    qmlRegisterUncreatableType<MprisPlayer>(uri, 1, 0, "MprisPlayer", QStringLiteral("Made by MprisPlayers"));
    registerSingleton<Notifier>("Notifier");
    registerSingleton<InputRegion>("InputRegion");
    registerSingleton<WindowActivator>("WindowActivator");
    registerSingleton<AppConfig>("AppConfig");
    registerSingleton<PlasmaSettings>("PlasmaSettings");
    registerSingleton<SystemStatus>("SystemStatus");
    registerSingleton<MprisSeeks>("MprisSeeks");
}
