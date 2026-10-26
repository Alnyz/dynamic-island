#pragma once

#include <QObject>
#include <QString>
#include <qqmlintegration.h>

// Whether a full-screen window covers the island's screen, as reported by a KWin script
// (data/kwin/fullscreen.js) that calls the scriptable slots below over D-Bus.
class FullScreenWatcher : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "io.github.alnyz.DynamicIsland.FullScreen")
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(QString screenName READ screenName WRITE setScreenName NOTIFY screenNameChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)

public:
    explicit FullScreenWatcher(QObject *parent = nullptr);
    ~FullScreenWatcher() override;

    bool enabled() const { return m_enabled; }
    void setEnabled(bool on);
    QString screenName() const { return m_screen; }
    void setScreenName(const QString &name);
    bool active() const { return m_active; }
    // Whether this instance owns the D-Bus name and its script is loaded into KWin.
    bool loaded() const { return m_loaded; }

public Q_SLOTS:
    // Another window became active. No window, or the island's own surface taking the
    // keyboard, is ignored so the open panel neither closes nor drops behind a game.
    Q_SCRIPTABLE void reportActivated(const QString &output, bool fullScreen, const QString &resourceClass);
    // The active window entered or left full screen, or moved to another screen.
    Q_SCRIPTABLE void reportFullScreen(const QString &output, bool fullScreen);

Q_SIGNALS:
    void enabledChanged();
    void screenNameChanged();
    void activeChanged();
    // The user switched to another app's window.
    void switched();

private:
    void update();
    void loadScript();
    void unloadScript();

    bool m_enabled = false;
    bool m_loaded = false;
    QString m_screen;
    QString m_output;
    bool m_fullScreen = false;
    bool m_active = false;
};
