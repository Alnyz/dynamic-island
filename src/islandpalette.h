#pragma once

#include <QColor>
#include <QObject>

// Stands in for Qt 6's per-item `palette`: the island's colour roles, written by Island.qml
// from its theme and read everywhere as `ipal.<role>`.
class IslandPalette : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QColor window MEMBER m_window NOTIFY changed)
    Q_PROPERTY(QColor windowText MEMBER m_windowText NOTIFY changed)
    Q_PROPERTY(QColor text MEMBER m_text NOTIFY changed)
    Q_PROPERTY(QColor placeholderText MEMBER m_placeholderText NOTIFY changed)
    Q_PROPERTY(QColor mid MEMBER m_mid NOTIFY changed)
    Q_PROPERTY(QColor base MEMBER m_base NOTIFY changed)
    Q_PROPERTY(QColor alternateBase MEMBER m_alternateBase NOTIFY changed)
    Q_PROPERTY(QColor button MEMBER m_button NOTIFY changed)
    Q_PROPERTY(QColor buttonText MEMBER m_buttonText NOTIFY changed)
    Q_PROPERTY(QColor dark MEMBER m_dark NOTIFY changed)
    Q_PROPERTY(QColor light MEMBER m_light NOTIFY changed)
    Q_PROPERTY(QColor brightText MEMBER m_brightText NOTIFY changed)
    Q_PROPERTY(QColor highlight MEMBER m_highlight NOTIFY changed)
    Q_PROPERTY(QColor highlightedText MEMBER m_highlightedText NOTIFY changed)
    Q_PROPERTY(QColor accent MEMBER m_accent NOTIFY changed)

public:
    explicit IslandPalette(QObject *parent = nullptr);

    QColor m_window;
    QColor m_windowText;
    QColor m_text;
    QColor m_placeholderText;
    QColor m_mid;
    QColor m_base;
    QColor m_alternateBase;
    QColor m_button;
    QColor m_buttonText;
    QColor m_dark;
    QColor m_light;
    QColor m_brightText;
    QColor m_highlight;
    QColor m_highlightedText;
    QColor m_accent;

Q_SIGNALS:
    void changed();
};
