#include "covercolor.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <array>

CoverColor::CoverColor(QObject *parent)
    : QObject(parent)
{
}

void CoverColor::setSource(const QUrl &url)
{
    if (url == m_source)
        return;
    m_source = url;
    Q_EMIT sourceChanged();
    if (m_reply) {
        m_reply->disconnect(this);
        m_reply->abort();
        m_reply->deleteLater();
        m_reply = nullptr;
    }
    if (url.isLocalFile()) {
        setImage(QImage(url.toLocalFile()));
    } else if (url.scheme() == QLatin1String("https") || url.scheme() == QLatin1String("http")) {
        if (!m_net)
            m_net = new QNetworkAccessManager(this);
        m_reply = m_net->get(QNetworkRequest(url));
        QNetworkReply *reply = m_reply;
        connect(reply, &QNetworkReply::finished, this, [this, reply] {
            if (reply == m_reply) {
                m_reply = nullptr;
                setImage(reply->error() == QNetworkReply::NoError ? QImage::fromData(reply->readAll()) : QImage());
            }
            reply->deleteLater();
        });
    } else {
        setImage(QImage());
    }
}

void CoverColor::setImage(const QImage &image)
{
    const QColor c = image.isNull() ? QColor() : pick(image);
    if (c == m_color)
        return;
    m_color = c;
    Q_EMIT colorChanged();
}

QColor CoverColor::pick(const QImage &image)
{
    if (image.isNull())
        return {};
    const QImage small = image.scaled(32, 32, Qt::IgnoreAspectRatio, Qt::SmoothTransformation).convertToFormat(QImage::Format_RGB32);
    // Twelve hue families; each pixel votes with how colourful and bright it is.
    struct Bucket {
        double weight = 0, r = 0, g = 0, b = 0;
    };
    std::array<Bucket, 12> buckets;
    double total = 0;
    const int pixels = small.width() * small.height();
    for (int y = 0; y < small.height(); ++y) {
        for (int x = 0; x < small.width(); ++x) {
            const QColor p = QColor::fromRgb(small.pixel(x, y));
            const double s = p.hsvSaturationF(), v = p.valueF();
            if (s < 0.2 || v < 0.15)
                continue;
            const double w = s * s * v;
            Bucket &bk = buckets[qBound(0, p.hsvHue(), 359) / 30];
            bk.weight += w;
            bk.r += p.redF() * w;
            bk.g += p.greenF() * w;
            bk.b += p.blueF() * w;
            total += w;
        }
    }
    // Under ~4% of the picture in colour: treat it as a greyscale cover.
    if (total < pixels * 0.04)
        return {};
    const Bucket &best = *std::max_element(buckets.begin(), buckets.end(), [](const Bucket &a, const Bucket &b) { return a.weight < b.weight; });
    QColor c = QColor::fromRgbF(float(best.r / best.weight), float(best.g / best.weight), float(best.b / best.weight));
    // Readable as a fill and as text on black: not too dark, not washed out.
    float h, s, l;
    c.getHslF(&h, &s, &l);
    c.setHslF(h, qBound(0.45f, s, 0.9f), qBound(0.5f, l, 0.68f));
    return c;
}
