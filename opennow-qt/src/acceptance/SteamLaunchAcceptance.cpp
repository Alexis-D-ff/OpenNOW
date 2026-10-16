#include "acceptance/AcceptanceSession.h"
#include "app/AppController.h"

#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>
#include <QVariantMap>

#include <cstdlib>
#include <memory>

using namespace Qt::StringLiterals;

int AcceptanceSession::startSteamLaunchWorkload()
{
    auto *window = m_engine.rootObjects().isEmpty() ? nullptr
        : qobject_cast<QQuickWindow *>(m_engine.rootObjects().first());
    auto *store = m_engine.singletonInstance<QObject *>(u"OpenNOW"_s, u"ShellStore"_s);
    if (!window || !store) return EXIT_FAILURE;
    if (window->visibility() != QWindow::FullScreen) {
        qCritical("--fullscreen did not open the window fullscreen");
        return EXIT_FAILURE;
    }
    const auto quitExpected = std::make_shared<bool>(false);
    connect(&m_controller, &AppController::applicationExitCommitted, this, [this, quitExpected] {
        if (*quitExpected) return;
        qCritical("--quit-after-session quit before the session finished stopping");
        m_application.exit(EXIT_FAILURE);
    });
    store->setProperty("activeSession", QVariantMap{{u"sessionId"_s, u"steam-launch-fixture"_s}});
    const auto step = std::make_shared<int>(0);
    auto *timer = new QTimer(this);
    timer->setInterval(200);
    connect(timer, &QTimer::timeout, this, [this, window, store, quitExpected, step, timer] {
        const auto current = (*step)++;
        const auto fail = [this, current, timer](const char *message) {
            qCritical("Steam launch step %d: %s", current, message);
            timer->stop();
            m_application.exit(EXIT_FAILURE);
        };
        if (m_qmlWarningOccurred) return fail("QML warning");
        switch (current) {
        case 0:
            store->setProperty("streamStopRequestId", u"steam-launch-stop"_s);
            store->setProperty("activeSession", QVariant{});
            return;
        case 1:
            if (window->visibility() != QWindow::FullScreen) return fail("the window left fullscreen");
            *quitExpected = true;
            store->setProperty("streamStopRequestId", QString{});
            return;
        default:
            return fail("OpenNOW stayed open after the session stopped");
        }
    });
    timer->start();
    return EXIT_SUCCESS;
}
