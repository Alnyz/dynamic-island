#include "fullscreenwatcher.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

namespace
{
const QString kService = QStringLiteral("io.github.alnyz.DynamicIsland");
const QString kPath = QStringLiteral("/FullScreen");
const QString kScriptName = QStringLiteral("dynamic-island-fullscreen");

QDBusMessage scripting(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"), QStringLiteral("org.kde.kwin.Scripting"), method);
}
}

FullScreenWatcher::FullScreenWatcher(QObject *parent)
    : QObject(parent)
{
}

FullScreenWatcher::~FullScreenWatcher()
{
    if (m_enabled)
        unloadScript();
}

void FullScreenWatcher::setEnabled(bool on)
{
    if (on == m_enabled)
        return;
    m_enabled = on;
    if (on)
        loadScript();
    else
        unloadScript();
    Q_EMIT enabledChanged();
}

void FullScreenWatcher::setScreenName(const QString &name)
{
    if (name == m_screen)
        return;
    m_screen = name;
    Q_EMIT screenNameChanged();
    update();
}

void FullScreenWatcher::reportActivated(const QString &output, bool fullScreen, const QString &resourceClass)
{
    if (resourceClass.isEmpty() || resourceClass == QLatin1String("dynamic-island"))
        return;
    m_output = output;
    m_fullScreen = fullScreen;
    update();
    Q_EMIT switched();
}

void FullScreenWatcher::reportFullScreen(const QString &output, bool fullScreen)
{
    m_output = output;
    m_fullScreen = fullScreen;
    update();
}

void FullScreenWatcher::update()
{
    const bool on = m_fullScreen && (m_screen.isEmpty() || m_output == m_screen);
    if (on == m_active)
        return;
    m_active = on;
    Q_EMIT activeChanged();
}

void FullScreenWatcher::loadScript()
{
    auto bus = QDBusConnection::sessionBus();
    if (!bus.registerService(kService) || !bus.registerObject(kPath, this, QDBusConnection::ExportScriptableSlots)) {
        qWarning("FullScreenWatcher: could not take %s on the session bus", qPrintable(kService));
        return;
    }
    // KWin loads scripts from a file, so the bundled one is copied out first.
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    const QString path = dir + QStringLiteral("/fullscreen.js");
    QFile::remove(path);
    if (!QFile::copy(QStringLiteral(":/data/kwin/fullscreen.js"), path)) {
        qWarning("FullScreenWatcher: could not write %s", qPrintable(path));
        return;
    }
    // A script left over from a crash would still call the old instance.
    bus.call(scripting(QStringLiteral("unloadScript")) << kScriptName);
    const QDBusReply<int> id = bus.call(scripting(QStringLiteral("loadScript")) << path << kScriptName);
    if (!id.isValid() || id.value() < 0) {
        qWarning("FullScreenWatcher: KWin did not load the script");
        return;
    }
    bus.call(QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting/Script") + QString::number(id.value()),
                                            QStringLiteral("org.kde.kwin.Script"), QStringLiteral("run")));
}

void FullScreenWatcher::unloadScript()
{
    auto bus = QDBusConnection::sessionBus();
    bus.call(scripting(QStringLiteral("unloadScript")) << kScriptName);
    bus.unregisterObject(kPath);
    bus.unregisterService(kService);
}
