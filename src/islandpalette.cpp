#include "islandpalette.h"

#include <QGuiApplication>
#include <QPalette>

IslandPalette::IslandPalette(QObject *parent)
    : QObject(parent)
{
    const QPalette p = QGuiApplication::palette();
    m_window = p.color(QPalette::Window);
    m_windowText = p.color(QPalette::WindowText);
    m_text = p.color(QPalette::Text);
    m_placeholderText = p.color(QPalette::PlaceholderText);
    m_mid = p.color(QPalette::Mid);
    m_base = p.color(QPalette::Base);
    m_alternateBase = p.color(QPalette::AlternateBase);
    m_button = p.color(QPalette::Button);
    m_buttonText = p.color(QPalette::ButtonText);
    m_dark = p.color(QPalette::Dark);
    m_light = p.color(QPalette::Light);
    m_brightText = p.color(QPalette::BrightText);
    m_highlight = p.color(QPalette::Highlight);
    m_highlightedText = p.color(QPalette::HighlightedText);
    m_accent = m_highlight;
}
