#include "notesstore.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QStandardPaths>

NotesStore::NotesStore(QObject *parent)
    : NotesStore(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/dynamic-island/notes"), parent)
{
}

NotesStore::NotesStore(const QString &directory, QObject *parent)
    : QObject(parent)
    , m_dir(directory)
{
    QDir().mkpath(m_dir);
    scan();
}

QString NotesStore::newId() const
{
    QString id = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss-zzz"));
    for (int n = 2; QFile::exists(pathFor(id)); ++n)
        id = QDateTime::currentDateTime().toString(QStringLiteral("yyyyMMdd-HHmmss-zzz-")) + QString::number(n);
    return id;
}

QString NotesStore::pathFor(const QString &id) const
{
    static const QRegularExpression safe(QStringLiteral("^[0-9-]+$"));
    return safe.match(id).hasMatch() ? m_dir + QLatin1Char('/') + id + QStringLiteral(".txt") : QString();
}

QString NotesStore::read(const QString &id) const
{
    QFile file(pathFor(id));
    if (!file.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(file.readAll());
}

void NotesStore::write(const QString &id, const QString &text)
{
    const QString path = pathFor(id);
    if (path.isEmpty())
        return;
    if (text.trimmed().isEmpty()) {
        QFile::remove(path);
    } else {
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
            return;
        file.write(text.toUtf8());
    }
    scan();
}

void NotesStore::scan()
{
    QList<QVariantMap> found;
    const QFileInfoList files = QDir(m_dir).entryInfoList({QStringLiteral("*.txt")}, QDir::Files);
    for (const QFileInfo &info : files) {
        QFile file(info.filePath());
        if (!file.open(QIODevice::ReadOnly))
            continue;
        QStringList lines = QString::fromUtf8(file.readAll()).split(QLatin1Char('\n'));
        for (QString &line : lines)
            line = line.trimmed();
        lines.removeAll(QString());
        QVariantMap note;
        note[QStringLiteral("id")] = info.completeBaseName();
        note[QStringLiteral("title")] = lines.value(0);
        note[QStringLiteral("preview")] = lines.mid(1).join(QLatin1Char(' '));
        note[QStringLiteral("modified")] = info.lastModified().toMSecsSinceEpoch();
        found.append(note);
    }
    std::sort(found.begin(), found.end(), [](const QVariantMap &a, const QVariantMap &b) {
        return a.value(QStringLiteral("modified")).toLongLong() > b.value(QStringLiteral("modified")).toLongLong();
    });
    m_notes.clear();
    for (const QVariantMap &note : found)
        m_notes.append(note);
    Q_EMIT notesChanged();
}
