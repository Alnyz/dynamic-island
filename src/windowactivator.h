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
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // Activates (and un-minimises) a window of the app with this desktop entry, preferring one whose
    // title contains titleHint ("whatsapp" for a WhatsApp Web tab). Does nothing when none is open.
    Q_INVOKABLE void activate(const QString &desktopEntry, const QString &titleHint = QString());

    // The KWin script for activate(); the strings are JSON-quoted, never pasted in raw.
    static QString script(const QString &desktopEntry, const QString &titleHint);
    // "web.whatsapp.com" -> "whatsapp": the part of a site's name its tab title usually shows.
    static QString hintFromOrigin(const QString &origin);
};
