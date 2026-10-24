#pragma once

#include <QObject>
#include <QVariantList>
#include <qqmlintegration.h>

// One plain text file per note in ~/.local/share/dynamic-island/notes.
class NotesStore : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QVariantList notes READ notes NOTIFY notesChanged)

public:
    explicit NotesStore(QObject *parent = nullptr);
    explicit NotesStore(const QString &directory, QObject *parent = nullptr);

    // Newest first: {id, title, preview, modified (ms)}.
    QVariantList notes() const { return m_notes; }

    // The note file only appears once something is written to it.
    Q_INVOKABLE QString newId() const;
    Q_INVOKABLE QString read(const QString &id) const;
    // Blank text deletes the note.
    Q_INVOKABLE void write(const QString &id, const QString &text);

Q_SIGNALS:
    void notesChanged();

private:
    QString pathFor(const QString &id) const;
    void scan();

    QString m_dir;
    QVariantList m_notes;
};
