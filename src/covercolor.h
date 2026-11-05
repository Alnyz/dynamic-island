#pragma once

#include <QColor>
#include <QImage>
#include <QObject>
#include <QUrl>
#include <qqmlintegration.h>

class QNetworkAccessManager;
class QNetworkReply;

// The most vivid colour of a song's cover, made readable on the island's black, for tinting
// the music controls. Covers without much colour (greyscale, mostly black) give no colour.
class CoverColor : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QUrl source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QColor color READ color NOTIFY colorChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY colorChanged)

public:
    explicit CoverColor(QObject *parent = nullptr);

    QUrl source() const { return m_source; }
    void setSource(const QUrl &url);
    QColor color() const { return m_color; }
    bool valid() const { return m_color.isValid(); }

    // The pick itself: an invalid colour when the image has too little colour to choose from.
    static QColor pick(const QImage &image);

Q_SIGNALS:
    void sourceChanged();
    void colorChanged();

private:
    void setImage(const QImage &image);

    QUrl m_source;
    QColor m_color;
    QNetworkAccessManager *m_net = nullptr;
    QNetworkReply *m_reply = nullptr;
};
