#include "clipboardhistory.h"

#include <KSystemClipboard>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QMimeData>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUrl>
#include <QUuid>

ClipboardHistory::ClipboardHistory(QObject *parent)
    : ClipboardHistory(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/dynamic-island/clipboard"), true, parent)
{
}

ClipboardHistory::ClipboardHistory(const QString &directory, bool watchSystem, QObject *parent)
    : QObject(parent)
    , m_dir(directory)
    , m_watch(watchSystem)
{
    QDir().mkpath(m_dir);
    QFile::setPermissions(m_dir, QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ExeOwner);
    load();
    if (m_watch) {
        // KSystemClipboard uses the Wayland data-control protocol, so it sees copies made while the island isn't focused.
        auto *clip = KSystemClipboard::instance();
        connect(clip, &KSystemClipboard::changed, this, [this, clip](QClipboard::Mode mode) {
            if (mode == QClipboard::Clipboard)
                handleMime(clip->mimeData(QClipboard::Clipboard));
        });
    }
}

void ClipboardHistory::handleMime(const QMimeData *mime)
{
    if (!mime || mime->data(QStringLiteral("x-kde-passwordManagerHint")) == "secret")
        return;

    const QString text = mime->text().trimmed();
    if (!text.isEmpty()) {
        static const QRegularExpression link(QStringLiteral("^https?://\\S+$"));
        QVariantMap item;
        item[QStringLiteral("kind")] = link.match(text).hasMatch() ? QStringLiteral("link") : QStringLiteral("text");
        item[QStringLiteral("text")] = text;
        prepend(item, QStringLiteral("text"), text);
        return;
    }

    QImage image = qvariant_cast<QImage>(mime->imageData());
    if (image.isNull() && mime->hasFormat(QStringLiteral("image/png")))
        image = QImage::fromData(mime->data(QStringLiteral("image/png")));
    if (image.isNull())
        return;
    image = image.convertToFormat(QImage::Format_ARGB32);
    const QString hash = QString::fromLatin1(
        QCryptographicHash::hash(QByteArrayView(image.constBits(), image.sizeInBytes()), QCryptographicHash::Sha1).toHex());
    const int existing = [&] {
        for (int i = 0; i < m_items.size(); ++i)
            if (m_items.at(i).toMap().value(QStringLiteral("hash")) == hash)
                return i;
        return -1;
    }();
    QVariantMap item;
    if (existing >= 0) {
        item = m_items.at(existing).toMap();
    } else {
        const QString file = m_dir + QLatin1Char('/') + hash + QStringLiteral(".png");
        if (!image.save(file, "PNG"))
            return;
        QFile::setPermissions(file, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        item[QStringLiteral("kind")] = QStringLiteral("image");
        item[QStringLiteral("image")] = QUrl::fromLocalFile(file).toString();
        item[QStringLiteral("width")] = image.width();
        item[QStringLiteral("height")] = image.height();
    }
    item[QStringLiteral("hash")] = hash;
    prepend(item, QStringLiteral("hash"), hash);
}

int ClipboardHistory::indexOf(const QString &id) const
{
    for (int i = 0; i < m_items.size(); ++i)
        if (m_items.at(i).toMap().value(QStringLiteral("id")).toString() == id)
            return i;
    return -1;
}

void ClipboardHistory::prepend(QVariantMap item, const QString &matchKey, const QString &matchValue)
{
    // The clipboard reports its current content again at startup; that isn't a new copy.
    if (!m_items.isEmpty() && m_items.first().toMap().value(matchKey).toString() == matchValue)
        return;
    bool pinned = false;
    QString id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    for (int i = 0; i < m_items.size(); ++i) {
        const QVariantMap old = m_items.at(i).toMap();
        if (old.value(matchKey).toString() == matchValue) {
            pinned = old.value(QStringLiteral("pinned")).toBool();
            id = old.value(QStringLiteral("id")).toString();
            m_items.removeAt(i);
            break;
        }
    }
    item[QStringLiteral("id")] = id;
    item[QStringLiteral("pinned")] = pinned;
    item[QStringLiteral("time")] = QDateTime::currentMSecsSinceEpoch();
    m_items.prepend(item);

    int unpinned = 0;
    for (int i = 0; i < m_items.size();) {
        const QVariantMap it = m_items.at(i).toMap();
        if (!it.value(QStringLiteral("pinned")).toBool() && ++unpinned > kMaxUnpinned) {
            dropFiles(it);
            m_items.removeAt(i);
        } else {
            ++i;
        }
    }
    save();
}

void ClipboardHistory::copy(const QString &id)
{
    const int i = indexOf(id);
    if (i < 0 || !m_watch)
        return;
    const QVariantMap item = m_items.at(i).toMap();
    auto *mime = new QMimeData;
    if (item.value(QStringLiteral("kind")) == QLatin1String("image"))
        mime->setImageData(QImage(QUrl(item.value(QStringLiteral("image")).toString()).toLocalFile()));
    else
        mime->setText(item.value(QStringLiteral("text")).toString());
    // The change comes back through handleMime, which moves the item to the top.
    KSystemClipboard::instance()->setMimeData(mime, QClipboard::Clipboard);
}

void ClipboardHistory::copyText(const QString &text)
{
    auto *mime = new QMimeData;
    mime->setText(text);
    KSystemClipboard::instance()->setMimeData(mime, QClipboard::Clipboard);
}

void ClipboardHistory::pin(const QString &id, bool on)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    QVariantMap item = m_items.at(i).toMap();
    item[QStringLiteral("pinned")] = on;
    m_items[i] = item;
    save();
}

void ClipboardHistory::remove(const QString &id)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    dropFiles(m_items.at(i).toMap());
    m_items.removeAt(i);
    save();
}

void ClipboardHistory::clear()
{
    for (int i = m_items.size() - 1; i >= 0; --i) {
        const QVariantMap item = m_items.at(i).toMap();
        if (!item.value(QStringLiteral("pinned")).toBool()) {
            dropFiles(item);
            m_items.removeAt(i);
        }
    }
    save();
}

void ClipboardHistory::dropFiles(const QVariantMap &item)
{
    if (item.contains(QStringLiteral("image")))
        QFile::remove(QUrl(item.value(QStringLiteral("image")).toString()).toLocalFile());
}

void ClipboardHistory::load()
{
    QFile file(m_dir + QStringLiteral("/history.json"));
    if (file.open(QIODevice::ReadOnly))
        m_items = QJsonDocument::fromJson(file.readAll()).array().toVariantList();
}

void ClipboardHistory::save()
{
    const QString path = m_dir + QStringLiteral("/history.json");
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QFile::setPermissions(path, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        file.write(QJsonDocument(QJsonArray::fromVariantList(m_items)).toJson(QJsonDocument::Compact));
    }
    Q_EMIT itemsChanged();
}
