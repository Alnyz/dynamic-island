#include "inputregion.h"

#include <KWindowEffects>
#include <LayerShellQt/Window>
#include <QPainterPath>
#include <QRegion>

QRect InputRegion::maskRect(const QRectF &rect)
{
    const QRect r = rect.toAlignedRect();
    return r.isEmpty() ? QRect(r.topLeft(), QSize(1, 1)) : r;
}

void InputRegion::set(QWindow *window, const QRectF &rect)
{
    if (window)
        window->setMask(QRegion(maskRect(rect)));
}

void InputRegion::setKeyboard(QWindow *window, bool on, bool exclusive)
{
    if (window)
        LayerShellQt::Window::get(window)->setKeyboardInteractivity(!on      ? LayerShellQt::Window::KeyboardInteractivityNone
                                                                     : exclusive ? LayerShellQt::Window::KeyboardInteractivityExclusive
                                                                                 : LayerShellQt::Window::KeyboardInteractivityOnDemand);
}

void InputRegion::setLayer(QWindow *window, bool overlay)
{
    if (window)
        LayerShellQt::Window::get(window)->setLayer(overlay ? LayerShellQt::Window::LayerOverlay : LayerShellQt::Window::LayerTop);
}

QRegion InputRegion::roundedRegion(const QRectF &rect, qreal radius)
{
    if (rect.isEmpty())
        return {};
    QPainterPath path;
    path.addRoundedRect(rect, radius, radius);
    return QRegion(path.toFillPolygon().toPolygon());
}

void InputRegion::setBlur(QWindow *window, const QRectF &rect, qreal radius, bool on)
{
    if (!window)
        return;
    const QRegion region = roundedRegion(rect, radius);
    KWindowEffects::enableBlurBehind(window, on && !region.isEmpty(), region);
}
