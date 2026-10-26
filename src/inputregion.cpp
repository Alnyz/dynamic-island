#include "inputregion.h"

#include <LayerShellQt/Window>
#include <QRegion>

void InputRegion::set(QWindow *window, const QRectF &rect)
{
    if (window)
        window->setMask(QRegion(rect.toAlignedRect()));
}

void InputRegion::setKeyboard(QWindow *window, bool on)
{
    if (window)
        LayerShellQt::Window::get(window)->setKeyboardInteractivity(on ? LayerShellQt::Window::KeyboardInteractivityOnDemand
                                                                       : LayerShellQt::Window::KeyboardInteractivityNone);
}

void InputRegion::setLayer(QWindow *window, bool overlay)
{
    if (window)
        LayerShellQt::Window::get(window)->setLayer(overlay ? LayerShellQt::Window::LayerOverlay : LayerShellQt::Window::LayerTop);
}
