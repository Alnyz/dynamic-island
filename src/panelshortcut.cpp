#include "panelshortcut.h"

#include <KGlobalAccel>
#include <QAction>
#include <algorithm>

PanelShortcut::PanelShortcut(QObject *parent)
    : QObject(parent)
    , m_action(new QAction(this))
    , m_clipboard(new QAction(this))
{
    m_action->setObjectName(QStringLiteral("toggle-panel"));
    m_action->setText(QStringLiteral("Open or close the panel"));
    // Meta+Alt+N as well: Meta+N is often taken on Plasma 5 (Latte Dock uses it for its 16th entry).
    const QList<QKeySequence> keys{QKeySequence(Qt::META | Qt::Key_N), QKeySequence(Qt::META | Qt::ALT | Qt::Key_N)};
    KGlobalAccel::self()->setDefaultShortcut(m_action, keys);
    // Autoloading keeps a key the user picked in System Settings instead of resetting it.
    KGlobalAccel::self()->setShortcut(m_action, keys, KGlobalAccel::Autoloading);
    // A clash on first run leaves it saved with no key at all; try the defaults again then.
    const QList<QKeySequence> saved = KGlobalAccel::self()->shortcut(m_action);
    if (std::all_of(saved.begin(), saved.end(), [](const QKeySequence &k) { return k.isEmpty(); }))
        KGlobalAccel::self()->setShortcut(m_action, {keys.last()}, KGlobalAccel::NoAutoloading);
    connect(m_action, &QAction::triggered, this, &PanelShortcut::activated);

    m_clipboard->setObjectName(QStringLiteral("show-clipboard"));
    m_clipboard->setText(QStringLiteral("Open clipboard history"));
    const QList<QKeySequence> clipKeys{QKeySequence(Qt::META | Qt::SHIFT | Qt::Key_V)};
    KGlobalAccel::self()->setDefaultShortcut(m_clipboard, clipKeys);
    KGlobalAccel::self()->setShortcut(m_clipboard, clipKeys, KGlobalAccel::Autoloading);
    connect(m_clipboard, &QAction::triggered, this, &PanelShortcut::clipboardActivated);
}
