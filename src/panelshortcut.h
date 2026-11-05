#pragma once

#include <QObject>
#include <qqmlintegration.h>

class QAction;

// The global shortcuts, registered with Plasma so they can be changed in System Settings →
// Shortcuts: open or close the panel (Meta+N), and open clipboard history (Meta+Shift+V; Meta+V
// is Plasma's own clipboard popup unless the user moves it).
class PanelShortcut : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit PanelShortcut(QObject *parent = nullptr);

Q_SIGNALS:
    void activated();
    void clipboardActivated();

private:
    QAction *m_action;
    QAction *m_clipboard;
};
