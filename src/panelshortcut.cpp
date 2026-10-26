#include "panelshortcut.h"

#include <KGlobalAccel>
#include <QAction>

PanelShortcut::PanelShortcut(QObject *parent)
    : QObject(parent)
    , m_action(new QAction(this))
{
    m_action->setObjectName(QStringLiteral("toggle-panel"));
    m_action->setText(QStringLiteral("Open or close the panel"));
    const QList<QKeySequence> keys{QKeySequence(Qt::META | Qt::Key_N)};
    KGlobalAccel::self()->setDefaultShortcut(m_action, keys);
    // Autoloading keeps a key the user picked in System Settings instead of resetting it.
    KGlobalAccel::self()->setShortcut(m_action, keys, KGlobalAccel::Autoloading);
    connect(m_action, &QAction::triggered, this, &PanelShortcut::activated);
}
