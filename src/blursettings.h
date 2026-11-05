#pragma once

#include <QObject>
#include <QString>
#include <qqmlintegration.h>

// KWin's blur strength, for the island's settings. KWin has one strength for every blurred
// window (there is no per-window strength), so this edits that shared setting: Better Blur DX's
// when it's the running blur effect, else KWin's own.
class BlurSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // The running blur effect's id ("better_blur_dx", "forceblur" or "blur"), or "" when none is.
    Q_PROPERTY(QString effect READ effect NOTIFY changed)
    // 1..15, as KWin's own blur settings show it.
    Q_PROPERTY(int strength READ strength WRITE setStrength NOTIFY changed)

public:
    explicit BlurSettings(QObject *parent = nullptr);
    // A config file other than kwinrc and no KWin to ask: for tests.
    BlurSettings(const QString &configFile, const QString &effect, QObject *parent = nullptr);

    static constexpr int kDefaultStrength = 12;
    // The kwinrc group holding an effect's settings.
    static QString groupFor(const QString &effect);

    QString effect() const { return m_effect; }
    int strength() const { return m_strength; }
    void setStrength(int value);
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void changed();

private:
    QString m_config;
    QString m_effect;
    bool m_live = true;
    int m_strength = kDefaultStrength;
    void readStrength();
};
