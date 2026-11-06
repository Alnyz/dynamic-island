#pragma once

#include <QObject>
#include <QString>
#include <qqmlintegration.h>

// Brings an app's window to the front through a one-off KWin script. On Wayland an app may only
// raise itself with an activation token; Plasma's own popups pass one along with a notification's
// action, but nothing else can get one, so a browser woken by the island's click stays behind.
// KWin scripts may activate any window.
class WindowActivator : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "io.github.alnyz.DynamicIsland.WindowActivator")
    QML_ELEMENT
    QML_SINGLETON

public:
    explicit WindowActivator(QObject *parent = nullptr);

    // Activates (and un-minimises) a window of the app with this desktop entry, preferring one whose
    // title contains titleHint ("whatsapp" for a WhatsApp Web tab). With none open, starts the app
    // when launch is true, else does nothing.
    Q_INVOKABLE void activate(const QString &desktopEntry, const QString &titleHint = QString(), bool launch = false);

    // The KWin script for activate(); the strings are JSON-quoted, never pasted in raw. With
    // replyTo (this process's bus name), a miss calls back noWindow() so the app can be started.
    static QString script(const QString &desktopEntry, const QString &titleHint, const QString &replyTo = QString());

    // "web.whatsapp.com" -> "whatsapp": the part of a site's name its tab title usually shows.
    static QString hintFromOrigin(const QString &origin);
    // The same for QML, which can't call static functions.
    Q_INVOKABLE QString originHint(const QString &origin) const { return hintFromOrigin(origin); }

public Q_SLOTS:
    // Called by the KWin script when no window matched.
    Q_SCRIPTABLE void noWindow(const QString &desktopEntry);

private:
    // Loads and runs a one-off KWin script under name, unloading it again afterwards.
    void runScript(const QString &name, const QString &source);
};
