#pragma once

#include <QObject>
#include <QPointer>
#include <QRectF>
#include <QWindow>
#include <QtQml/qqml.h>

class InputRegion : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Whether the pointer is over the island window's input area, from the window's own enter and
    // leave events. Qt 5.15's HoverHandler sometimes misses the leave (the pointer stepping off
    // while the pill grows), so the island checks this too. Follows the window given to set().
    Q_PROPERTY(bool pointerInside READ pointerInside NOTIFY pointerInsideChanged)

public:
    explicit InputRegion(QObject *parent = nullptr);

    // Sets the X11 input shape, so clicks outside the visible pill fall through to whatever is underneath.
    Q_INVOKABLE void set(QWindow *window, const QRectF &rect);
    // The mask for rect; an empty one becomes 1x1, since an empty mask lets the whole window take clicks.
    static QRect maskRect(const QRectF &rect);
    // Lets the window take keyboard focus when clicked, or never.
    // Exclusive takes it straight away, for the panel opened with the shortcut.
    Q_INVOKABLE void setKeyboard(QWindow *window, bool on, bool exclusive = false);
    // Overlay sits above full-screen windows; the usual layer sits below them.
    Q_INVOKABLE void setLayer(QWindow *window, bool overlay);
    // Without a compositor X11 can't show see-through pixels, so the whole window would be a black
    // box: then clip the window itself to the pill's rounded shape. With one, the shape is removed
    // again, since it would also cut off the glow and the pill while it grows.
    Q_INVOKABLE void setShape(QWindow *window, const QRectF &rect, qreal radius);
    // KWin blurs what's behind the island's rounded shape (for the see-through look), or nothing.
    Q_INVOKABLE void setBlur(QWindow *window, const QRectF &rect, qreal radius, bool on);
    // The blur region: rect with rounded corners, as KWin takes it.
    static QRegion roundedRegion(const QRectF &rect, qreal radius);
    // KWin window type and states for the island window.
    static void applyWindowType(QWindow *window, bool overlay);

    bool pointerInside() const { return m_pointerInside; }

Q_SIGNALS:
    void pointerInsideChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void applyShape();

    QPointer<QWindow> m_shapeWindow;
    QRectF m_shapeRect;
    qreal m_shapeRadius = 0;
    bool m_composited = true;
    bool m_keyboard = false;
    bool m_overlay = false;
    QPointer<QWindow> m_pointerWindow;
    bool m_pointerInside = false;
};
