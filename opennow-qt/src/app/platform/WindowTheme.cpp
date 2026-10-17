#include "app/platform/WindowTheme.h"

#include <QGuiApplication>
#include <QPlatformSurfaceEvent>

#include <utility>

#ifdef Q_OS_WIN
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwmapi.h>
#endif

#ifdef OPENNOW_WAYLAND_DECORATIONS
#include <QtGui/qguiapplication_platform.h>
#include <wayland-client.h>
#endif

namespace {
void applyNativeTheme(QWindow *window, bool darkMode)
{
#ifdef Q_OS_WIN
    if (QGuiApplication::platformName() != QStringLiteral("windows")) return;
    const auto hwnd = reinterpret_cast<HWND>(window->winId());
    const BOOL dark = darkMode ? TRUE : FALSE;
    constexpr DWORD immersiveDarkMode = 20;
    constexpr DWORD immersiveDarkModeBefore20H1 = 19;
    auto result = DwmSetWindowAttribute(hwnd, immersiveDarkMode, &dark, sizeof(dark));
    if (result == E_INVALIDARG)
        result = DwmSetWindowAttribute(hwnd, immersiveDarkModeBefore20H1, &dark, sizeof(dark));
    if (FAILED(result) && result != E_INVALIDARG)
        qWarning("Could not update the native titlebar theme: HRESULT 0x%08lx", static_cast<unsigned long>(result));
#else
    Q_UNUSED(window);
    Q_UNUSED(darkMode);
#endif
}

#ifdef OPENNOW_WAYLAND_DECORATIONS
bool compositorOffersServerDecorations()
{
    auto *wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
    if (!wayland || !wayland->display()) return true;
    wl_display *display = wayland->display();
    wl_event_queue *queue = wl_display_create_queue(display);
    auto *wrapper = static_cast<wl_display *>(wl_proxy_create_wrapper(display));
    wl_proxy_set_queue(reinterpret_cast<wl_proxy *>(wrapper), queue);
    wl_registry *registry = wl_display_get_registry(wrapper);
    bool offered = false;
    static const wl_registry_listener listener{
        [](void *data, wl_registry *, uint32_t, const char *interface, uint32_t) {
            if (QByteArrayView(interface) == "zxdg_decoration_manager_v1")
                *static_cast<bool *>(data) = true;
        },
        [](void *, wl_registry *, uint32_t) {}};
    wl_registry_add_listener(registry, &listener, &offered);
    wl_display_roundtrip_queue(display, queue);
    wl_registry_destroy(registry);
    wl_proxy_wrapper_destroy(wrapper);
    wl_event_queue_destroy(queue);
    return offered;
}
#endif

bool needsClientDecorations(QWindow *window)
{
#ifdef OPENNOW_WAYLAND_DECORATIONS
    if (!QGuiApplication::platformName().startsWith(QStringLiteral("wayland"))
            || window->surfaceType() != QSurface::VulkanSurface
            || window->flags().testFlag(Qt::FramelessWindowHint))
        return false;
    static const bool serverDecorations = compositorOffersServerDecorations();
    return !serverDecorations;
#else
    Q_UNUSED(window);
    return false;
#endif
}
}

WindowTheme::WindowTheme(QObject *parent)
    : WindowTheme(applyNativeTheme, parent)
{
}

WindowTheme::WindowTheme(std::function<void(QWindow *, bool)> applyTheme, QObject *parent)
    : QObject(parent), m_applyTheme(std::move(applyTheme))
{
}

void WindowTheme::setTargetWindow(QWindow *window)
{
    if (m_window == window) return;
    if (m_window) m_window->removeEventFilter(this);
    m_window = window;
    if (m_window) m_window->installEventFilter(this);
    emit targetWindowChanged();
    apply();
}

void WindowTheme::setDarkMode(bool darkMode)
{
    if (m_darkMode == darkMode) return;
    m_darkMode = darkMode;
    emit darkModeChanged();
    apply();
}

bool WindowTheme::eventFilter(QObject *watched, QEvent *event)
{
    if (watched == m_window) {
        if (event->type() == QEvent::PlatformSurface
                && static_cast<QPlatformSurfaceEvent *>(event)->surfaceEventType()
                    == QPlatformSurfaceEvent::SurfaceCreated) {
            apply();
        } else if (event->type() == QEvent::ApplicationPaletteChange
                || event->type() == QEvent::ThemeChange) {
            QMetaObject::invokeMethod(this, &WindowTheme::apply, Qt::QueuedConnection);
        }
    }
    return QObject::eventFilter(watched, event);
}

void WindowTheme::apply()
{
    if (!m_window || !m_window->handle()) return;
    m_applyTheme(m_window, m_darkMode);
    const bool clientDecorations = needsClientDecorations(m_window);
    if (m_clientDecorations == clientDecorations) return;
    m_clientDecorations = clientDecorations;
    emit clientDecorationsChanged();
}
