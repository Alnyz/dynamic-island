#include "inputregion.h"

#include <LayerShellQt/Window>
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
