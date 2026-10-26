#include <LayerShellQt/Window>
#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>

int main(int argc, char *argv[])
{
    // QApplication, not QGuiApplication: the settings window uses the desktop style, which needs QtWidgets.
    QApplication app(argc, argv);
    // KGlobalAccel files the shortcut under this app in System Settings → Shortcuts.
    app.setDesktopFileName(QStringLiteral("dynamic-island"));
    app.setApplicationDisplayName(QStringLiteral("Dynamic Island"));

    // Closing the settings window must not quit the island.
    app.setQuitOnLastWindowClosed(false);

    QQmlApplicationEngine engine;
    engine.loadFromModule("Island", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;

    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
    auto *layer = LayerShellQt::Window::get(window);
    // KWin maps unknown scopes to a normal window, which Show Desktop hides.
    layer->setScope(QStringLiteral("dock"));
    layer->setLayer(LayerShellQt::Window::LayerTop);
    layer->setAnchors(LayerShellQt::Window::AnchorTop);
    layer->setExclusiveZone(0);
    layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    layer->setMargins({0, 0, 0, 0});
    window->show();

    return app.exec();
}
