// QML test runner for the Plasma 5 port. Qt 6 builds an "Island" QML module and runs the stock
// qmltestrunner; Qt 5 has neither, so this runner registers the same C++ types and the shared
// `ipal` colours the app sets up in main.cpp, then runs every tests/tst_*.qml.

#include <QQmlContext>
#include <QQmlEngine>
#include <QStandardPaths>
#include <QtQuickTest>

#include "islandpalette.h"
#include "islandtypes.h"

class Setup : public QObject
{
    Q_OBJECT
public slots:
    void applicationAvailable()
    {
        // Nothing a test touches may read or write the real ~/.config or ~/.local/share
        // (settings, notes, saved notifications), so results don't depend on whose machine it is.
        QStandardPaths::setTestModeEnabled(true);
        registerIslandTypes();
    }
    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->rootContext()->setContextProperty(QStringLiteral("ipal"), new IslandPalette(engine));
    }
};

int main(int argc, char **argv)
{
    // Hidden windows: the tests simulate the mouse, and visible ones pop up on screen and catch the
    // real pointer. Setting QT_QPA_PLATFORM=xcb shows them instead.
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM"))
        qputenv("QT_QPA_PLATFORM", "offscreen");
    // Qt 5's offscreen windows still draw with OpenGL through the X display. Without one (SSH, CI),
    // Qt Quick's software renderer runs the tests just the same.
    if (qEnvironmentVariableIsEmpty("DISPLAY") && qEnvironmentVariableIsEmpty("QT_QUICK_BACKEND"))
        qputenv("QT_QUICK_BACKEND", "software");
    Setup setup;
    return quick_test_main_with_setup(argc, argv, "island", QUICK_TEST_SOURCE_DIR, &setup);
}

#include "qmltest.moc"
