#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>

#include <KWindowSystem>

#include "inputregion.h"
#include "islandpalette.h"
#include "islandtypes.h"

// X11 has no layer shell: the island is a frameless, borderless window kept centred at the top
// of the primary screen, above panels, on every desktop and out of the task manager.
static void placeIsland(QQuickWindow *window)
{
    QScreen *screen = QGuiApplication::primaryScreen();
    if (!screen)
        return;
    const QRect geo = screen->geometry();
    const QPoint pos(geo.x() + (geo.width() - window->width()) / 2, geo.y());
    if (window->position() != pos)
        window->setPosition(pos);
}

int main(int argc, char *argv[])
{
    // Plasma 5 on Wayland would need the layer shell this port replaces, so always use X11.
    qputenv("QT_QPA_PLATFORM", "xcb");
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
    QApplication::setAttribute(Qt::AA_UseHighDpiPixmaps);
    // QApplication, not QGuiApplication: the settings window uses the desktop style, which needs QtWidgets.
    QApplication app(argc, argv);
    // KGlobalAccel files the shortcut under this app in System Settings → Shortcuts.
    app.setDesktopFileName(QStringLiteral("dynamic-island"));
    app.setOrganizationName(QStringLiteral("dynamic-island"));
    app.setOrganizationDomain(QStringLiteral("alnyz.github.io"));
    app.setApplicationDisplayName(QStringLiteral("Dynamic Island"));

    // Closing the settings window must not quit the island.
    app.setQuitOnLastWindowClosed(false);

    registerIslandTypes();

    QQmlApplicationEngine engine;
    // Qt 6 lets every item read and override `palette`; Qt 5 has no such thing on plain items,
    // so the island reads its colours from this shared object instead.
    auto *palette = new IslandPalette(&app);
    engine.rootContext()->setContextProperty(QStringLiteral("ipal"), palette);
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    window->setFlags(window->flags() | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::WindowDoesNotAcceptFocus);
    placeIsland(window);
    QObject::connect(window, &QWindow::widthChanged, window, [window] { placeIsland(window); });
    // KWin pushes windows out of the area a panel reserves whenever that area changes (Latte Dock
    // reconfigured, a panel added at the top), which would leave the island hanging below it.
    QObject::connect(window, &QWindow::xChanged, window, [window] { placeIsland(window); }, Qt::QueuedConnection);
    QObject::connect(window, &QWindow::yChanged, window, [window] { placeIsland(window); }, Qt::QueuedConnection);
    QObject::connect(qApp, &QGuiApplication::primaryScreenChanged, window, [window] { placeIsland(window); });
    if (QScreen *screen = QGuiApplication::primaryScreen())
        QObject::connect(screen, &QScreen::geometryChanged, window, [window] { placeIsland(window); });
    window->create();
    InputRegion::applyWindowType(window, false);
    window->show();
    InputRegion::applyWindowType(window, false);
    placeIsland(window);

    return app.exec();
}
