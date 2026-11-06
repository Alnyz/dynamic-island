#include "todostore.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QUuid>

TodoStore::TodoStore(QObject *parent)
    : TodoStore(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/dynamic-island/todo.json"), parent)
{
}

TodoStore::TodoStore(const QString &file, QObject *parent)
    : QObject(parent)
    , m_file(file)
{
    QDir().mkpath(QFileInfo(m_file).absolutePath());
    load();
}

QVariantMap TodoStore::nextOpen() const
{
    for (const QVariant &v : m_items) {
        const QVariantMap item = v.toMap();
        if (!item.value(QStringLiteral("done")).toBool())
            return item;
    }
    return {};
}

int TodoStore::openCount() const
{
    int n = 0;
    for (const QVariant &v : m_items)
        n += v.toMap().value(QStringLiteral("done")).toBool() ? 0 : 1;
    return n;
}

QString TodoStore::newId() const
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces).left(8) + QString::number(QDateTime::currentMSecsSinceEpoch(), 36);
}

int TodoStore::indexOf(const QString &id) const
{
    for (int i = 0; i < m_items.size(); ++i)
        if (m_items.at(i).toMap().value(QStringLiteral("id")).toString() == id)
            return i;
    return -1;
}

QString TodoStore::add(const QString &text)
{
    const QString t = text.simplified();
    if (t.isEmpty())
        return {};
    const QString id = newId();
    m_items.append(QVariantMap{{QStringLiteral("id"), id},
                               {QStringLiteral("text"), t},
                               {QStringLiteral("done"), false},
                               {QStringLiteral("created"), QDateTime::currentMSecsSinceEpoch()}});
    save();
    return id;
}

void TodoStore::setDone(const QString &id, bool done)
{
    const int i = indexOf(id);
    if (i < 0)
        return;
    QVariantMap item = m_items.at(i).toMap();
    if (item.value(QStringLiteral("done")).toBool() == done)
        return;
    item.insert(QStringLiteral("done"), done);
    m_items[i] = item;
    save();
}

QVariantMap TodoStore::remove(const QString &id)
{
    const int i = indexOf(id);
    if (i < 0)
        return {};
    const QVariantMap removed{{QStringLiteral("item"), m_items.takeAt(i)}, {QStringLiteral("index"), i}};
    save();
    return removed;
}

void TodoStore::restore(const QVariantMap &removed)
{
    const QVariantMap item = removed.value(QStringLiteral("item")).toMap();
    const QString id = item.value(QStringLiteral("id")).toString();
    if (id.isEmpty() || item.value(QStringLiteral("text")).toString().isEmpty() || indexOf(id) >= 0)
        return;
    const int at = qBound(0, removed.value(QStringLiteral("index")).toInt(), int(m_items.size()));
    m_items.insert(at, item);
    save();
}

void TodoStore::clearDone()
{
    const int before = m_items.size();
    m_items.erase(std::remove_if(m_items.begin(), m_items.end(), [](const QVariant &v) { return v.toMap().value(QStringLiteral("done")).toBool(); }),
                  m_items.end());
    if (m_items.size() != before)
        save();
}

int TodoStore::importJson(const QString &json)
{
    const QJsonArray list = QJsonDocument::fromJson(json.toUtf8()).array();
    int n = 0;
    for (const QJsonValue &v : list) {
        const QString t = v.toObject().value(QStringLiteral("text")).toString().simplified();
        if (t.isEmpty())
            continue;
        m_items.append(QVariantMap{{QStringLiteral("id"), newId() + QString::number(n)},
                                   {QStringLiteral("text"), t},
                                   {QStringLiteral("done"), v.toObject().value(QStringLiteral("done")).toBool()},
                                   {QStringLiteral("created"), QDateTime::currentMSecsSinceEpoch()}});
        ++n;
    }
    if (n > 0)
        save();
    return n;
}

void TodoStore::load()
{
    QFile file(m_file);
    m_items.clear();
    if (file.open(QIODevice::ReadOnly)) {
        const QJsonArray list = QJsonDocument::fromJson(file.readAll()).array();
        for (const QJsonValue &v : list) {
            const QJsonObject o = v.toObject();
            if (o.value(QStringLiteral("id")).toString().isEmpty() || o.value(QStringLiteral("text")).toString().isEmpty())
                continue;
            m_items.append(o.toVariantMap());
        }
    }
    Q_EMIT itemsChanged();
}

void TodoStore::save()
{
    QSaveFile file(m_file);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(QJsonDocument(QJsonArray::fromVariantList(m_items)).toJson(QJsonDocument::Compact));
        file.commit();
    }
    Q_EMIT itemsChanged();
}

QString TodoStore::legacyPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/Unknown Organization/dynamic-island.conf");
}

int TodoStore::importLegacy(const QString &path)
{
    const QString file = path.isEmpty() ? legacyPath() : path;
    // Never creates the file: only reads one that's there.
    if (!QFile::exists(file))
        return 0;
    QSettings old(file, QSettings::IniFormat);
    const QString key = QStringLiteral("TodoList/tasksJson");
    if (!old.contains(key))
        return 0;
    const QString json = old.value(key).toString();
    const int n = m_items.isEmpty() ? importJson(json) : 0;
    old.remove(key);
    old.sync();
    return n;
}
