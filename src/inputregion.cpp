#include "inputregion.h"

#include <KWindowEffects>
#include <KWindowSystem>
#include <QPainterPath>
#include <QRegion>
#include <QX11Info>

#include <X11/Xlib.h>
#include <X11/extensions/shape.h>

QRect InputRegion::maskRect(const QRectF &rect)
{
    const QRect r = rect.toAlignedRect();
    return r.isEmpty() ? QRect(r.topLeft(), QSize(1, 1)) : r;
}

void InputRegion::set(QWindow *window, const QRectF &rect)
{
    if (!window || !QX11Info::isPlatformX11())
        return;
    // Only the input shape: QWindow::setMask on X11 also clips what is drawn, which would cut off
    // the pill while it grows. Device pixels, so scale by the window's ratio.
    const QRect r = maskRect(rect);
    const qreal dpr = window->devicePixelRatio();
    XRectangle xr;
    xr.x = short(r.x() * dpr);
    xr.y = short(r.y() * dpr);
    xr.width = ushort(qMax(1.0, r.width() * dpr));
    xr.height = ushort(qMax(1.0, r.height() * dpr));
    XShapeCombineRectangles(QX11Info::display(), window->winId(), ShapeInput, 0, 0, &xr, 1, ShapeSet, Unsorted);
    XFlush(QX11Info::display());
}

void InputRegion::setKeyboard(QWindow *window, bool on, bool exclusive)
{
    if (!window)
        return;
    window->setFlag(Qt::WindowDoesNotAcceptFocus, !on);
    m_keyboard = on;
    applyWindowType(window, m_overlay);
    // KWin won't focus a notification-type window on click, so take focus whenever the panel
    // wants the keyboard (Wayland's "on demand" has no X11 equivalent).
    Q_UNUSED(exclusive)
    if (on) {
        KWindowSystem::forceActiveWindow(window->winId());
        window->requestActivate();
    }
}

void InputRegion::setLayer(QWindow *window, bool overlay)
{
    if (!window || m_overlay == overlay)
        return;
    m_overlay = overlay;
    applyWindowType(window, overlay);
}

void InputRegion::applyWindowType(QWindow *window, bool overlay)
{
    if (!window || !QX11Info::isPlatformX11())
        return;
    const WId id = window->winId();
    // Notifications sit above Plasma's panels; on-screen displays also above full-screen windows.
    KWindowSystem::setType(id, overlay ? NET::OnScreenDisplay : NET::Notification);
    KWindowSystem::setState(id, NET::SkipTaskbar | NET::SkipPager | NET::SkipSwitcher | NET::KeepAbove | NET::Sticky);
    KWindowSystem::setOnAllDesktops(id, true);
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
