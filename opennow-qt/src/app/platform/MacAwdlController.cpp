#include "app/platform/MacAwdlController.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QFile>
#include <QLocalSocket>
#include <QTemporaryFile>

#include <algorithm>

#ifdef Q_OS_MACOS
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

namespace {
constexpr auto SocketPath = "/var/run/opennow-awdl/control.sock";
constexpr auto HelperPath = "/Library/PrivilegedHelperTools/io.github.opencloudgaming.OpenNOW.awdl-helper";
constexpr auto PlistPath = "/Library/LaunchDaemons/io.github.opencloudgaming.OpenNOW.awdl.plist";

QString administratorScript(bool install, const MacAwdlBackend::Payload &payload)
{
    const auto digest = payload.sha256;
    if (install && (payload.bytes <= 0 || payload.bytes > 32 * 1024 * 1024)) return {};
    if (install && (digest.size() != 64 || std::any_of(digest.cbegin(), digest.cend(), [](QChar c) {
            return !((c >= QLatin1Char('0') && c <= QLatin1Char('9'))
                || (c >= QLatin1Char('a') && c <= QLatin1Char('f')));
        }))) return {};
    const auto prefix = QStringLiteral("/private/tmp/opennow-awdl-");
    if (install && (!payload.path.startsWith(prefix) || payload.path.size() != prefix.size() + 6
        || std::any_of(payload.path.cbegin() + prefix.size(), payload.path.cend(), [](QChar c) {
            return !((c >= QLatin1Char('a') && c <= QLatin1Char('z'))
                || (c >= QLatin1Char('A') && c <= QLatin1Char('Z'))
                || (c >= QLatin1Char('0') && c <= QLatin1Char('9')));
        }))) return {};
    const auto validation = QStringLiteral(
        "set -eu; "
        "secure() { [ ! -L \"$1\" ] && [ \"$(/usr/bin/stat -f %u \"$1\")\" = 0 ] "
        "&& [ $((0$(/usr/bin/stat -f %Lp \"$1\") & 022)) -eq 0 ]; }; "
        "secure /; secure /Library; "
        "for p in /Library/PrivilegedHelperTools /Library/LaunchDaemons; do "
        "if [ ! -e \"$p\" ] && [ ! -L \"$p\" ]; then /bin/mkdir -m 0755 \"$p\"; /usr/sbin/chown root:wheel \"$p\"; fi; "
        "secure \"$p\"; [ -d \"$p\" ]; done; "
        "for p in /Library/PrivilegedHelperTools/io.github.opencloudgaming.OpenNOW.awdl-helper "
        "/Library/LaunchDaemons/io.github.opencloudgaming.OpenNOW.awdl.plist; do "
        "if [ -e \"$p\" ] || [ -L \"$p\" ]; then secure \"$p\" || exit 1; [ -f \"$p\" ] || exit 1; fi; done; ");
    const auto command = install
        ? QStringLiteral(
            "stage=$(/usr/bin/mktemp -d /Library/PrivilegedHelperTools/.opennow-awdl.XXXXXX); "
            "trap '/bin/rm -rf \"$stage\"' EXIT; "
            "/usr/bin/perl -MFcntl=O_RDONLY,O_NOFOLLOW,O_NONBLOCK -e '"
            "alarm 5; sysopen(my $in,$ARGV[0],O_RDONLY|O_NOFOLLOW|O_NONBLOCK) or die; -f $in or die; "
            "binmode($in); open(my $out,\">\",$ARGV[1]) or die; binmode($out); my $total=0; "
            "while(1){my $n=sysread($in,my $buf,65536); defined($n) or die; last if $n==0; "
            "$total+=$n; $total<=33554432 or die; print {$out} $buf or die;} "
            "close($out) or die; $total==$ARGV[2] or die;' '%2' \"$stage/helper\" '%3'; "
            "[ \"$(/usr/bin/stat -f %z \"$stage/helper\")\" = '%3' ]; "
            "[ \"$(/usr/bin/shasum -a 256 \"$stage/helper\" | /usr/bin/cut -d ' ' -f 1)\" = '%1' ]; "
            "/usr/bin/printf '%s\\n' '<?xml version=\"1.0\" encoding=\"UTF-8\"?>' "
            "'<plist version=\"1.0\"><dict>' "
            "'<key>Label</key><string>io.github.opencloudgaming.OpenNOW.awdl</string>' "
            "'<key>ProgramArguments</key><array><string>/Library/PrivilegedHelperTools/io.github.opencloudgaming.OpenNOW.awdl-helper</string></array>' "
            "'<key>RunAtLoad</key><true/><key>KeepAlive</key><true/>' "
            "'<key>ProcessType</key><string>Background</string>' "
            "'<key>UserName</key><string>root</string><key>GroupName</key><string>wheel</string>' "
            "'<key>Umask</key><integer>63</integer><key>ExitTimeOut</key><integer>20</integer>' "
            "'<key>ThrottleInterval</key><integer>10</integer>' "
            "'</dict></plist>' > \"$stage/daemon.plist\"; "
            "if ! /bin/launchctl bootout system/io.github.opencloudgaming.OpenNOW.awdl 2>/dev/null; then "
            "if /bin/launchctl print system/io.github.opencloudgaming.OpenNOW.awdl >/dev/null 2>&1; then exit 1; fi; fi; "
            "/usr/bin/install -o root -g wheel -m 0755 \"$stage/helper\" "
            "/Library/PrivilegedHelperTools/io.github.opencloudgaming.OpenNOW.awdl-helper; "
            "/usr/bin/install -o root -g wheel -m 0644 \"$stage/daemon.plist\" "
            "/Library/LaunchDaemons/io.github.opencloudgaming.OpenNOW.awdl.plist; "
            "/bin/launchctl bootstrap system /Library/LaunchDaemons/io.github.opencloudgaming.OpenNOW.awdl.plist").arg(digest, payload.path, QString::number(payload.bytes))
        : QStringLiteral(
            "if ! /bin/launchctl bootout system/io.github.opencloudgaming.OpenNOW.awdl 2>/dev/null; then "
            "if /bin/launchctl print system/io.github.opencloudgaming.OpenNOW.awdl >/dev/null 2>&1; then exit 1; fi; fi; "
            "n=0; while [ -e /var/db/opennow-awdl/restore ] && [ \"$n\" -lt 50 ]; do "
            "/bin/sleep 0.1; n=$((n+1)); done; "
            "if [ -e /var/db/opennow-awdl/restore ] || [ -L /var/db/opennow-awdl/restore ]; then "
            "/bin/launchctl bootstrap system /Library/LaunchDaemons/io.github.opencloudgaming.OpenNOW.awdl.plist 2>/dev/null || true; "
            "exit 1; fi; "
            "/bin/rm -f /Library/LaunchDaemons/io.github.opencloudgaming.OpenNOW.awdl.plist "
            "/Library/PrivilegedHelperTools/io.github.opencloudgaming.OpenNOW.awdl-helper");
    auto shell = validation + command;
    shell.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
    shell = QStringLiteral("/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh -c '%1'").arg(shell);
    shell.replace(QLatin1Char('\\'), QStringLiteral("\\\\"));
    shell.replace(QLatin1Char('"'), QStringLiteral("\\\""));
    return QStringLiteral("do shell script \"%1\" with administrator privileges").arg(shell);
}

#ifdef Q_OS_MACOS
bool secureFile(const char *path, bool socket = false)
{
    struct stat info {};
    return lstat(path, &info) == 0 && info.st_uid == 0
        && (socket || (info.st_mode & 0022) == 0)
        && (socket ? S_ISSOCK(info.st_mode) : S_ISREG(info.st_mode));
}
#endif

class SystemMacAwdlBackend final : public MacAwdlBackend
{
public:
    SystemMacAwdlBackend()
    {
        m_process.setStandardOutputFile(QProcess::nullDevice());
        m_process.setStandardErrorFile(QProcess::nullDevice());
        connect(&m_process, &QProcess::errorOccurred, this, &MacAwdlBackend::processError);
        connect(&m_process, &QProcess::finished, this, &MacAwdlBackend::finished);
        m_timeout.setSingleShot(true);
        m_timeout.setInterval(1500);
        connect(&m_timeout, &QTimer::timeout, this, [this] {
            fail(tr("The AWDL helper did not respond. Streaming will continue without AWDL suppression."));
        });
        connect(&m_socket, &QLocalSocket::connected, this, [this] {
#ifdef Q_OS_MACOS
            uid_t uid = 1;
            gid_t gid = 1;
            if (getpeereid(static_cast<int>(m_socket.socketDescriptor()), &uid, &gid) != 0 || uid != 0) {
                fail(tr("The AWDL helper connection is not owned by root."));
                return;
            }
#endif
            if (m_wanted && m_socket.write("A", 1) != 1)
                fail(tr("Could not acquire the AWDL helper lease."));
        });
        connect(&m_socket, &QLocalSocket::readyRead, this, [this] {
            const auto response = m_socket.read(2);
            if (!m_wanted) return;
            if (response != QByteArrayLiteral("+") || m_acknowledged) {
                fail(tr("The AWDL helper rejected the lease."));
                return;
            }
            m_timeout.stop();
            m_acknowledged = true;
            emit leaseAcquired();
        });
        connect(&m_socket, &QLocalSocket::disconnected, this, [this] {
            if (m_wanted)
                fail(tr("The AWDL helper disconnected. Streaming will continue without AWDL suppression."));
        });
        connect(&m_socket, &QLocalSocket::errorOccurred, this, [this] {
            if (m_wanted)
                fail(tr("Could not connect to the AWDL helper. Check its installation and try again."));
        });
    }

    MacAwdlController::State readState() override
    {
#ifdef Q_OS_MACOS
        return secureFile(HelperPath) && secureFile(PlistPath)
            ? MacAwdlController::Installed : MacAwdlController::NotInstalled;
#else
        return MacAwdlController::Unsupported;
#endif
    }

    Payload preparePayload() override
    {
        m_payload.reset();
        QFile source(QCoreApplication::applicationDirPath()
                     + QStringLiteral("/../Helpers/opennow-awdl-helper"));
        if (!source.open(QIODevice::ReadOnly) || source.size() <= 0 || source.size() > 32 * 1024 * 1024)
            return {{}, {}, tr("The bundled AWDL helper is missing or invalid. Reinstall OpenNOW.")};
        auto snapshot = std::make_unique<QTemporaryFile>(QStringLiteral("/private/tmp/opennow-awdl-XXXXXX"));
        if (!snapshot->open())
            return {{}, {}, tr("Could not prepare the AWDL helper for installation.")};
        QCryptographicHash hash(QCryptographicHash::Sha256);
        qint64 copied = 0;
        while (!source.atEnd()) {
            const auto bytes = source.read(64 * 1024);
            copied += bytes.size();
            if (bytes.isEmpty() || copied > 32 * 1024 * 1024 || snapshot->write(bytes) != bytes.size())
                return {{}, {}, tr("Could not prepare the AWDL helper for installation.")};
            hash.addData(bytes);
        }
        if (!snapshot->flush())
            return {{}, {}, tr("Could not prepare the AWDL helper for installation.")};
        snapshot->close();
        const auto path = snapshot->fileName();
        m_payload = std::move(snapshot);
        return {path, QString::fromLatin1(hash.result().toHex()), {}, copied};
    }

    void start(const QString &program, const QStringList &arguments) override
    {
#ifdef Q_OS_MACOS
        m_process.start(program, arguments);
#else
        Q_UNUSED(program);
        Q_UNUSED(arguments);
        emit processError(QProcess::FailedToStart);
#endif
    }
    void kill() override { m_process.kill(); }

    void acquire() override
    {
        release();
#ifdef Q_OS_MACOS
        struct stat directory {};
        if (lstat("/var/run/opennow-awdl", &directory) != 0
            || !S_ISDIR(directory.st_mode) || directory.st_uid != 0
            || (directory.st_mode & 0022) != 0 || !secureFile(SocketPath, true)) {
            emit leaseFailed(tr("The AWDL helper socket is missing or insecure. Reinstall the helper."));
            return;
        }
        m_socket.abort();
        m_wanted = true;
        m_timeout.start();
        m_socket.connectToServer(QString::fromLatin1(SocketPath));
#else
        emit leaseFailed(tr("AWDL suppression is supported only on macOS."));
#endif
    }

    void release() override
    {
        m_wanted = false;
        m_acknowledged = false;
        m_timeout.stop();
        if (m_socket.state() == QLocalSocket::ConnectedState) {
            m_socket.write("R", 1);
            m_socket.disconnectFromServer();
        } else {
            m_socket.abort();
        }
    }

private:
    void fail(const QString &error)
    {
        const bool wanted = m_wanted;
        m_wanted = false;
        m_acknowledged = false;
        m_timeout.stop();
        m_socket.abort();
        if (wanted) emit leaseFailed(error);
    }

    QProcess m_process;
    std::unique_ptr<QTemporaryFile> m_payload;
    QLocalSocket m_socket;
    QTimer m_timeout;
    bool m_wanted = false;
    bool m_acknowledged = false;
};
}

MacAwdlController::MacAwdlController(QObject *parent)
    : MacAwdlController(std::make_unique<SystemMacAwdlBackend>(), 60'000, parent)
{
}

MacAwdlController::MacAwdlController(std::unique_ptr<MacAwdlBackend> backend,
                                   int timeoutMs, QObject *parent)
    : QObject(parent), m_backend(std::move(backend))
{
    m_timeout.setSingleShot(true);
    m_timeout.setInterval(std::max(1, timeoutMs));
    connect(&m_timeout, &QTimer::timeout, this, [this] {
        m_timedOut = true;
        setError(tr("The administrator request timed out. Refresh helper status after authorization finishes."));
        m_backend->kill();
    });
    connect(m_backend.get(), &MacAwdlBackend::processError, this, [this](QProcess::ProcessError error) {
        if (m_busy && error == QProcess::FailedToStart)
            complete(-1, QProcess::NormalExit);
    });
    connect(m_backend.get(), &MacAwdlBackend::finished, this, &MacAwdlController::complete);
    connect(m_backend.get(), &MacAwdlBackend::leaseAcquired, this, [this] {
        if (m_requested) setLeased(true);
        else m_backend->release();
    });
    connect(m_backend.get(), &MacAwdlBackend::leaseFailed, this, [this](const QString &error) {
        if (!m_requested) return;
        m_leaseFailed = true;
        setLeased(false);
        setError(error);
    });
    refresh();
}

MacAwdlController::~MacAwdlController()
{
    disconnect(m_backend.get(), nullptr, this, nullptr);
    m_backend->release();
}

MacAwdlController::State MacAwdlController::state() const { return m_state; }
bool MacAwdlController::busy() const { return m_busy; }
QString MacAwdlController::error() const { return m_error; }
bool MacAwdlController::enabled() const { return m_enabled; }
bool MacAwdlController::leased() const { return m_leased; }

void MacAwdlController::setEnabled(bool enabled)
{
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    emit enabledChanged();
    reconcileLease();
}

void MacAwdlController::setStreaming(bool streaming)
{
    if (m_streaming == streaming) return;
    m_streaming = streaming;
    reconcileLease();
}

void MacAwdlController::setLeased(bool leased)
{
    if (m_leased == leased) return;
    m_leased = leased;
    emit leasedChanged();
}

void MacAwdlController::setError(const QString &error)
{
    if (m_error == error) return;
    m_error = error;
    if (!error.isEmpty())
        qWarning("AWDL helper: %s", qUtf8Printable(error.left(1024)));
    emit errorChanged();
}

void MacAwdlController::reconcileLease()
{
    const bool wanted = m_enabled && m_streaming && m_state == Installed && !m_busy;
    if (wanted == m_requested) return;
    m_requested = wanted;
    setLeased(false);
    if (wanted) {
        m_leaseFailed = false;
        setError({});
        m_backend->acquire();
    } else {
        m_backend->release();
    }
}

void MacAwdlController::refresh()
{
    if (m_busy) return;
    if (m_requested && m_leaseFailed) {
        m_backend->release();
        m_requested = false;
    }
    const auto state = m_backend->readState();
    if (state != m_state) {
        m_state = state;
        emit statusChanged();
    }
    reconcileLease();
}

void MacAwdlController::install() { requestInstallation(true); }
void MacAwdlController::uninstall() { requestInstallation(false); }

void MacAwdlController::requestInstallation(bool install)
{
    if (m_busy || m_state == Unsupported) return;
    const auto payload = install ? m_backend->preparePayload() : MacAwdlBackend::Payload{};
    if (!payload.error.isEmpty()) {
        setError(payload.error);
        return;
    }
    const auto script = administratorScript(install, payload);
    if (script.isEmpty()) {
        setError(tr("Could not prepare a verified AWDL helper installation request."));
        return;
    }
    m_installing = install;
    m_timedOut = false;
    setError({});
    m_busy = true;
    reconcileLease();
    emit busyChanged();
    m_timeout.start();
    m_backend->start(QStringLiteral("/usr/bin/osascript"),
                     {QStringLiteral("-e"), script});
}

void MacAwdlController::complete(int exitCode, QProcess::ExitStatus exitStatus)
{
    if (!m_busy) return;
    m_timeout.stop();
    m_busy = false;
    refresh();
    if (!m_timedOut && (exitCode != 0 || exitStatus != QProcess::NormalExit
            || m_state != (m_installing ? Installed : NotInstalled))) {
        setError(m_installing
            ? tr("Helper installation failed or authorization was canceled. Refresh its status and try again.")
            : tr("Helper removal failed or authorization was canceled. AWDL restoration may still be pending; the helper was kept installed. Refresh its status and try again."));
    }
    emit busyChanged();
}
