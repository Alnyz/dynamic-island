#pragma once

#include <QObject>
#include <qqmlintegration.h>

class QAction;

// The global shortcut that opens and closes the panel (Meta+N by default), registered with
// Plasma so it can be changed in System Settings → Shortcuts.
class PanelShortcut : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit PanelShortcut(QObject *parent = nullptr);

Q_SIGNALS:
    void activated();

private:
    QAction *m_action;
};
