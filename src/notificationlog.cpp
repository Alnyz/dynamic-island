#include "notificationlog.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QStandardPaths>

NotificationLog::NotificationLog(QObject *parent)
    : NotificationLog(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/dynamic-island/notifications.json"), parent)
{
}

NotificationLog::NotificationLog(const QString &file, QObject *parent)
    : QObject(parent)
    , m_file(file)
{
    QFile f(m_file);
    // A broken file reads as an empty array, and the next save replaces it.
    if (f.open(QIODevice::ReadOnly))
        m_items = QJsonDocument::fromJson(f.readAll()).array().toVariantList();
}

void NotificationLog::save(const QVariantList &items)
{
    m_items = items;
    QDir().mkpath(QFileInfo(m_file).absolutePath());
    QFile f(m_file);
    // Bodies hold private messages, so only the owner may read the file.
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        QFile::setPermissions(m_file, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
        f.write(QJsonDocument(QJsonArray::fromVariantList(m_items)).toJson(QJsonDocument::Compact));
    }
    Q_EMIT itemsChanged();
}
