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
    // The mask for rect; an empty one becomes 1x1, since an empty mask lets the whole window take clicks.
    static QRect maskRect(const QRectF &rect);
    // Lets the layer-shell surface take keyboard focus when clicked (OnDemand), or never.
    // Exclusive takes it straight away, for the panel opened with the shortcut.
    Q_INVOKABLE void setKeyboard(QWindow *window, bool on, bool exclusive = false);
    // Overlay sits above full-screen windows; Top, the usual layer, sits below them.
    Q_INVOKABLE void setLayer(QWindow *window, bool overlay);
};
