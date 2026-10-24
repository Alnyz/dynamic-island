#pragma once

#include <QObject>
#include <qqmlintegration.h>

class Notifier : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // Critical urgency so it still shows (with sound) while do-not-disturb is on.
    Q_INVOKABLE void timerDone();
};
