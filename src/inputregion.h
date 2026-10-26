#pragma once

#include <QObject>
#include <QRectF>
#include <QWindow>
#include <qqmlintegration.h>

class InputRegion : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

public:
    using QObject::QObject;

    // On Qt Wayland, QWindow::setMask sets the surface input region, so clicks
    // outside the visible pill fall through to the panel underneath.
    Q_INVOKABLE void set(QWindow *window, const QRectF &rect);
    // Lets the layer-shell surface take keyboard focus when clicked (OnDemand), or never.
    Q_INVOKABLE void setKeyboard(QWindow *window, bool on);
    // Overlay sits above full-screen windows; Top, the usual layer, sits below them.
    Q_INVOKABLE void setLayer(QWindow *window, bool overlay);
};
