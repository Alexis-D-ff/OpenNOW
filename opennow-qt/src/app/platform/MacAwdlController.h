#pragma once

#include <QObject>
#include <QProcess>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <memory>

class MacAwdlBackend;

class MacAwdlController final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY statusChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool leased READ leased NOTIFY leasedChanged)

public:
    enum State { Unsupported, NotInstalled, Installed };
    Q_ENUM(State)

    explicit MacAwdlController(QObject *parent = nullptr);
    explicit MacAwdlController(std::unique_ptr<MacAwdlBackend> backend,
                               int timeoutMs = 60'000, QObject *parent = nullptr);
    ~MacAwdlController() override;

    State state() const;
    bool busy() const;
    QString error() const;
    bool enabled() const;
    bool leased() const;
    void setEnabled(bool enabled);
    void setStreaming(bool streaming);

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void install();
    Q_INVOKABLE void uninstall();

signals:
    void statusChanged();
    void busyChanged();
    void errorChanged();
    void enabledChanged();
    void leasedChanged();

private:
    void requestInstallation(bool install);
    void reconcileLease();
    void setLeased(bool leased);
    void setError(const QString &error);
    void complete(int exitCode, QProcess::ExitStatus exitStatus);

    std::unique_ptr<MacAwdlBackend> m_backend;
    QTimer m_timeout;
    State m_state = Unsupported;
    bool m_busy = false;
    bool m_enabled = false;
    bool m_streaming = false;
    bool m_requested = false;
    bool m_leased = false;
    bool m_leaseFailed = false;
    bool m_installing = false;
    bool m_timedOut = false;
    QString m_error;
};

class MacAwdlBackend : public QObject
{
    Q_OBJECT

public:
    using QObject::QObject;
    struct Payload {
        QString path;
        QString sha256;
        QString error;
        qint64 bytes = 0;
    };
    virtual MacAwdlController::State readState() = 0;
    virtual Payload preparePayload() = 0;
    virtual void start(const QString &program, const QStringList &arguments) = 0;
    virtual void kill() = 0;
    virtual void acquire() = 0;
    virtual void release() = 0;

signals:
    void processError(QProcess::ProcessError error);
    void finished(int exitCode, QProcess::ExitStatus exitStatus);
    void leaseAcquired();
    void leaseFailed(const QString &error);
};
