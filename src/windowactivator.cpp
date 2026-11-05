#include "windowactivator.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>

namespace
{
QDBusMessage scripting(const QString &method)
{
    return QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting"), QStringLiteral("org.kde.kwin.Scripting"), method);
}

QString quoted(const QString &s)
{
    // A one-element JSON array, minus the brackets: a safely escaped JavaScript string literal.
    const QByteArray json = QJsonDocument(QJsonArray{s}).toJson(QJsonDocument::Compact);
    return QString::fromUtf8(json.mid(1, json.size() - 2));
}

const QString kName = QStringLiteral("dynamic-island-activate");
const QString kPath = QStringLiteral("/WindowActivator");
}

WindowActivator::WindowActivator(QObject *parent)
    : QObject(parent)
{
    // Where the KWin script reports that the app has no window to bring forward.
    QDBusConnection::sessionBus().registerObject(kPath, this, QDBusConnection::ExportScriptableSlots);
}

void WindowActivator::noWindow(const QString &desktopEntry)
{
    static const QRegularExpression safe(QStringLiteral("^[\\w.-]+$"));
    if (!safe.match(desktopEntry).hasMatch())
        return;
    QProcess launcher;
    launcher.setProgram(QStringLiteral("gtk-launch"));
    launcher.setArguments({desktopEntry});
    // The app's own startup chatter stays out of the island's terminal.
    launcher.setStandardOutputFile(QProcess::nullDevice());
    launcher.setStandardErrorFile(QProcess::nullDevice());
    launcher.startDetached();
}

QString WindowActivator::hintFromOrigin(const QString &origin)
{
    const QStringList parts = origin.trimmed().toLower().split(QLatin1Char('.'), Qt::SkipEmptyParts);
    if (parts.size() < 2)
        return parts.value(0);
    // The name before the top-level domain: web.whatsapp.com -> whatsapp, mail.google.co.uk -> google.
    const bool countryPair = parts.size() >= 3 && parts.last().size() == 2 && (parts.at(parts.size() - 2) == QLatin1String("co") || parts.at(parts.size() - 2) == QLatin1String("com"));
    return parts.at(parts.size() - (countryPair ? 3 : 2));
}

QString WindowActivator::script(const QString &desktopEntry, const QString &titleHint, const QString &replyTo)
{
    const QString miss = replyTo.isEmpty() ? QString()
        : QStringLiteral("else {\n    callDBus(%1, %2, \"io.github.alnyz.DynamicIsland.WindowActivator\", \"noWindow\", %3);\n}\n")
              .arg(quoted(replyTo), quoted(kPath), quoted(desktopEntry));
    return QStringLiteral(
               "const entry = %1.toLowerCase();\n"
               "const hint = %2.toLowerCase();\n"
               // A browser's own web-app windows share its prefix: brave-browser -> brave-<app id>-Default.
               "const family = entry.replace(/-(browser|stable|beta)$/, \"\") + \"-\";\n"
               "let titled = null, own = null, related = null;\n"
               "for (const w of workspace.windowList()) {\n"
               "    if (!w.normalWindow) continue;\n"
               "    const name = (w.desktopFileName || w.resourceClass || \"\").toLowerCase();\n"
               "    const cls = (w.resourceClass || \"\").toLowerCase();\n"
               "    const exact = name === entry || cls === entry;\n"
               "    const kin = exact || name.indexOf(family) === 0 || cls.indexOf(family) === 0;\n"
               "    if (!kin) continue;\n"
               "    if (hint && !titled && (w.caption || \"\").toLowerCase().indexOf(hint) >= 0) titled = w;\n"
               "    if (exact && !own) own = w;\n"
               "    if (!related) related = w;\n"
               "}\n"
               // The tab or web app showing the site first, then the app itself, then its web apps.
               "const best = titled || own || related;\n"
               "if (best) {\n"
               "    if (best.minimized) best.minimized = false;\n"
               "    workspace.activeWindow = best;\n"
               "}\n")
               .arg(quoted(desktopEntry), quoted(titleHint))
        + miss;
}

void WindowActivator::activate(const QString &desktopEntry, const QString &titleHint, bool launch)
{
    static const QRegularExpression safe(QStringLiteral("^[\\w.-]+$"));
    if (!safe.match(desktopEntry).hasMatch())
        return;
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    QDir().mkpath(dir);
    const QString path = dir + QStringLiteral("/activate.js");
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return;
    file.write(script(desktopEntry, titleHint, launch ? QDBusConnection::sessionBus().baseService() : QString()).toUtf8());
    file.close();

    auto bus = QDBusConnection::sessionBus();
    // A previous one that's still loaded would block loading under the same name.
    bus.call(scripting(QStringLiteral("unloadScript")) << kName);
    auto *load = new QDBusPendingCallWatcher(bus.asyncCall(scripting(QStringLiteral("loadScript")) << path << kName), this);
    connect(load, &QDBusPendingCallWatcher::finished, this, [load] {
        load->deleteLater();
        const QDBusPendingReply<int> id = *load;
        if (!id.isValid() || id.value() < 0)
            return;
        auto bus = QDBusConnection::sessionBus();
        bus.asyncCall(QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/Scripting/Script") + QString::number(id.value()),
                                                     QStringLiteral("org.kde.kwin.Script"), QStringLiteral("run")));
        // It has done its job by then; unloading keeps KWin's script list clean.
        QTimer::singleShot(2000, [] { QDBusConnection::sessionBus().asyncCall(scripting(QStringLiteral("unloadScript")) << kName); });
    });
}
