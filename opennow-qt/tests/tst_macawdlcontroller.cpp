#include "app/platform/MacAwdlController.h"

#include <QSignalSpy>
#include <QFile>
#include <QTemporaryDir>
#include <QTest>

class FakeMacAwdlBackend final : public MacAwdlBackend
{
public:
    MacAwdlController::State currentState = MacAwdlController::Installed;
    Payload payload{QStringLiteral("/private/tmp/opennow-awdl-Abc123"), QString(64, QLatin1Char('a')), {}, 8192};
    QString program;
    QStringList arguments;
    int starts = 0;
    int preparations = 0;
    int acquisitions = 0;
    int releases = 0;
    int kills = 0;
    int *externalReleases = nullptr;

    MacAwdlController::State readState() override { return currentState; }
    Payload preparePayload() override { ++preparations; return payload; }
    void start(const QString &path, const QStringList &args) override
    {
        ++starts;
        program = path;
        arguments = args;
    }
    void kill() override { ++kills; }
    void acquire() override { ++acquisitions; }
    void release() override
    {
        ++releases;
        if (externalReleases) ++*externalReleases;
    }
};

class MacAwdlControllerTest final : public QObject
{
    Q_OBJECT

    static QString administratorCommand(const QString &request)
    {
        const auto prefix = QStringLiteral("do shell script \"");
        const auto suffix = QStringLiteral("\" with administrator privileges");
        if (!request.startsWith(prefix) || !request.endsWith(suffix)) return {};
        const auto encoded = request.mid(prefix.size(), request.size() - prefix.size() - suffix.size());
        QString shell;
        for (qsizetype index = 0; index < encoded.size(); ++index) {
            if (encoded[index] == QLatin1Char('\\') && index + 1 < encoded.size()) ++index;
            shell += encoded[index];
        }
        return shell;
    }

private slots:
    void defaultBackendNeverRequestsAuthorization()
    {
        MacAwdlController controller;
        QVERIFY(!controller.enabled());
        QVERIFY(!controller.leased());
        controller.refresh();
        QVERIFY(!controller.busy());
#ifndef Q_OS_MACOS
        QCOMPARE(controller.state(), MacAwdlController::Unsupported);
        controller.install();
        controller.uninstall();
        controller.setEnabled(true);
        controller.setStreaming(true);
        QVERIFY(!controller.busy());
        QVERIFY(!controller.leased());
#endif
    }

    void leaseRequiresPreferenceAndActualStreaming()
    {
        auto backend = std::make_unique<FakeMacAwdlBackend>();
        auto *fake = backend.get();
        MacAwdlController controller(std::move(backend));
        controller.setStreaming(true);
        QCOMPARE(fake->acquisitions, 0);
        controller.setStreaming(false);
        controller.setEnabled(true);
        QCOMPARE(fake->acquisitions, 0);
        controller.setStreaming(true);
        QCOMPARE(fake->acquisitions, 1);
        QVERIFY(!controller.leased());
        emit fake->leaseAcquired();
        QVERIFY(controller.leased());
        controller.setStreaming(true);
        controller.refresh();
        QCOMPARE(fake->acquisitions, 1);
        controller.setStreaming(false);
        QCOMPARE(fake->releases, 1);
        QVERIFY(!controller.leased());
        controller.setStreaming(false);
        QCOMPARE(fake->releases, 1);
        controller.setStreaming(true);
        QCOMPARE(fake->acquisitions, 2);
        controller.setEnabled(false);
        QCOMPARE(fake->releases, 2);
        QCOMPARE(fake->starts, 0);
    }

    void canceledAcquisitionAndDestructionRelease()
    {
        int releases = 0;
        {
            auto backend = std::make_unique<FakeMacAwdlBackend>();
            auto *fake = backend.get();
            fake->externalReleases = &releases;
            MacAwdlController controller(std::move(backend));
            controller.setEnabled(true);
            controller.setStreaming(true);
            controller.setEnabled(false);
            emit fake->leaseAcquired();
            QVERIFY(!controller.leased());
            QCOMPARE(releases, 2);
            controller.setEnabled(true);
            emit fake->leaseAcquired();
            QVERIFY(controller.leased());
        }
        QCOMPARE(releases, 3);
    }

    void failureDoesNotLoopAndRefreshRetries()
    {
        auto backend = std::make_unique<FakeMacAwdlBackend>();
        auto *fake = backend.get();
        MacAwdlController controller(std::move(backend));
        controller.setEnabled(true);
        controller.setStreaming(true);
        emit fake->leaseFailed(QStringLiteral("helper disconnected"));
        QVERIFY(!controller.leased());
        QCOMPARE(controller.error(), QStringLiteral("helper disconnected"));
        QTest::qWait(10);
        controller.setStreaming(true);
        QCOMPARE(fake->acquisitions, 1);
        controller.refresh();
        QCOMPARE(fake->acquisitions, 2);
        QVERIFY(controller.error().isEmpty());
        emit fake->leaseAcquired();
        QVERIFY(controller.leased());
        controller.setStreaming(false);
        emit fake->leaseFailed(QStringLiteral("stale failure"));
        QVERIFY(controller.error().isEmpty());
    }

    void installationUsesVerifiedSnapshotAndFixedPlist()
    {
        auto backend = std::make_unique<FakeMacAwdlBackend>();
        auto *fake = backend.get();
        fake->currentState = MacAwdlController::NotInstalled;
        MacAwdlController controller(std::move(backend));
        controller.setEnabled(true);
        controller.setStreaming(true);
        QCOMPARE(fake->acquisitions, 0);
        controller.install();
        QVERIFY(controller.busy());
        QCOMPARE(fake->preparations, 1);
        QCOMPARE(fake->program, QStringLiteral("/usr/bin/osascript"));
        QCOMPARE(fake->arguments.size(), 2);
        const auto script = fake->arguments[1];
        QVERIFY(script.contains(fake->payload.path));
        QVERIFY(script.contains(fake->payload.sha256));
        QVERIFY(script.contains(QStringLiteral("/usr/bin/shasum -a 256")));
        QVERIFY(script.contains(QStringLiteral("/usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin /bin/sh -c")));
        QVERIFY(script.contains(QStringLiteral("O_RDONLY|O_NOFOLLOW|O_NONBLOCK")));
        QVERIFY(script.contains(QStringLiteral("-f $in or die")));
        QVERIFY(script.contains(QStringLiteral("alarm 5")));
        QVERIFY(script.contains(QStringLiteral("$total<=33554432")));
        QVERIFY(script.contains(QStringLiteral("8192")));
        QVERIFY(script.contains(QStringLiteral("<key>ExitTimeOut</key><integer>20</integer>")));
        QVERIFY(script.contains(QStringLiteral("<key>ProgramArguments</key>")));
        QVERIFY(script.contains(QStringLiteral("/Library/PrivilegedHelperTools/io.github.opencloudgaming.OpenNOW.awdl-helper")));
        QVERIFY(!script.contains(QStringLiteral("Contents/Resources")));
        QVERIFY(!script.contains(QStringLiteral("/sbin/ifconfig")));
        controller.install();
        controller.uninstall();
        QCOMPARE(fake->starts, 1);
        fake->currentState = MacAwdlController::Installed;
        emit fake->finished(0, QProcess::NormalExit);
        QVERIFY(!controller.busy());
        QVERIFY(controller.error().isEmpty());
        QCOMPARE(fake->acquisitions, 1);
        emit fake->leaseAcquired();
        controller.uninstall();
        QVERIFY(!controller.leased());
        QCOMPARE(fake->releases, 1);
        QCOMPARE(fake->preparations, 1);
        QVERIFY(!fake->arguments[1].contains(fake->payload.path));
        QVERIFY(fake->arguments[1].contains(QStringLiteral("/var/db/opennow-awdl/restore")));
        QVERIFY(fake->arguments[1].contains(QStringLiteral("exit 1; fi;")));
        fake->currentState = MacAwdlController::NotInstalled;
        emit fake->finished(0, QProcess::NormalExit);
        QVERIFY(controller.error().isEmpty());
        QCOMPARE(fake->acquisitions, 1);
    }

    void unsafePayloadsAreRejected_data()
    {
        QTest::addColumn<QString>("path");
        QTest::addColumn<QString>("digest");
        QTest::newRow("shell-path") << QStringLiteral("/private/tmp/opennow-awdl-';id;") << QString(64, QLatin1Char('a'));
        QTest::newRow("other-path") << QStringLiteral("/tmp/opennow-awdl-Abc123") << QString(64, QLatin1Char('a'));
        QTest::newRow("shell-digest") << QStringLiteral("/private/tmp/opennow-awdl-Abc123") << QStringLiteral("';id");
    }

    void administratorRequestUsesCleanEnvironmentAndValidShellQuoting()
    {
#ifndef Q_OS_UNIX
        QSKIP("POSIX installer syntax validation requires a Unix shell.");
#endif
        auto backend = std::make_unique<FakeMacAwdlBackend>();
        auto *fake = backend.get();
        fake->currentState = MacAwdlController::NotInstalled;
        MacAwdlController controller(std::move(backend));
        const auto validSyntax = [](const QString &request) {
            auto shell = administratorCommand(request);
            if (!shell.startsWith(QStringLiteral("/usr/bin/env -i PATH="))) return false;
            shell.replace(QStringLiteral("/bin/sh -c"), QStringLiteral("/bin/sh -n -c"));
            QProcess parser;
            parser.start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), shell});
            return parser.waitForFinished(2'000) && parser.exitStatus() == QProcess::NormalExit
                && parser.exitCode() == 0;
        };
        controller.install();
        QVERIFY(validSyntax(fake->arguments[1]));
        fake->currentState = MacAwdlController::Installed;
        emit fake->finished(0, QProcess::NormalExit);
        controller.uninstall();
        QVERIFY(validSyntax(fake->arguments[1]));
    }

    void privilegedCopyUsesTheOpenedDescriptorAndRejectsSpecialFiles()
    {
#ifndef Q_OS_UNIX
        QSKIP("POSIX descriptor-copy validation requires a Unix host.");
#endif
        auto backend = std::make_unique<FakeMacAwdlBackend>();
        auto *fake = backend.get();
        fake->currentState = MacAwdlController::NotInstalled;
        MacAwdlController controller(std::move(backend));
        controller.install();
        auto command = administratorCommand(fake->arguments[1]);
        QVERIFY(command.contains(QStringLiteral("/bin/sh -c")));
        command.replace(QStringLiteral("/bin/sh -c"), QStringLiteral("/usr/bin/printf %s"));
        QProcess extract;
        extract.start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), command});
        QVERIFY(extract.waitForFinished(2'000));
        QCOMPARE(extract.exitCode(), 0);
        const auto script = QString::fromUtf8(extract.readAllStandardOutput());
        const auto begin = script.indexOf(QStringLiteral("-e '"));
        QVERIFY(begin >= 0);
        const auto end = script.indexOf(QStringLiteral("' "), begin + 4);
        QVERIFY(end > begin);
        const auto copyProgram = script.mid(begin + 4, end - begin - 4);
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const auto source = directory.filePath(QStringLiteral("source"));
        QFile input(source);
        QVERIFY(input.open(QIODevice::WriteOnly));
        const QByteArray data(8192, 'x');
        QCOMPARE(input.write(data), data.size());
        input.close();
        const auto destination = directory.filePath(QStringLiteral("destination"));
        const auto copy = [&](const QString &path, const QString &target, int expectedExit) {
            QProcess process;
            process.start(QStringLiteral("/usr/bin/perl"), {
                QStringLiteral("-MFcntl=O_RDONLY,O_NOFOLLOW,O_NONBLOCK"), QStringLiteral("-e"),
                copyProgram, path, target, QString::number(data.size())});
            if (!process.waitForFinished(2'000)) return false;
            return process.exitStatus() == QProcess::NormalExit
                && (expectedExit == 0 ? process.exitCode() == 0 : process.exitCode() != 0);
        };
        QVERIFY(copy(source, destination, 0));
        QFile output(destination);
        QVERIFY(output.open(QIODevice::ReadOnly));
        QCOMPARE(output.readAll(), data);
        const auto link = directory.filePath(QStringLiteral("link"));
        QVERIFY(QFile::link(source, link));
        const auto rejected = directory.filePath(QStringLiteral("rejected"));
        QVERIFY(copy(link, rejected, 1));
        QVERIFY(!QFile::exists(rejected));
        const auto fifo = directory.filePath(QStringLiteral("fifo"));
        QCOMPARE(QProcess::execute(QStringLiteral("/usr/bin/mkfifo"), {fifo}), 0);
        QVERIFY(copy(fifo, rejected, 1));
        QVERIFY(!QFile::exists(rejected));
    }

    void unsafePayloadsAreRejected()
    {
        QFETCH(QString, path);
        QFETCH(QString, digest);
        auto backend = std::make_unique<FakeMacAwdlBackend>();
        auto *fake = backend.get();
        fake->payload = {path, digest, {}, 8192};
        MacAwdlController controller(std::move(backend));
        controller.install();
        QCOMPARE(fake->starts, 0);
        QVERIFY(!controller.busy());
        QVERIFY(!controller.error().isEmpty());
    }

    void processFailuresAndTimeout()
    {
        auto backend = std::make_unique<FakeMacAwdlBackend>();
        auto *fake = backend.get();
        fake->currentState = MacAwdlController::NotInstalled;
        MacAwdlController controller(std::move(backend), 10);
        controller.install();
        emit fake->processError(QProcess::FailedToStart);
        QVERIFY(!controller.busy());
        QVERIFY(!controller.error().isEmpty());
        controller.install();
        emit fake->finished(1, QProcess::NormalExit);
        QVERIFY(!controller.busy());
        QVERIFY(!controller.error().isEmpty());
        controller.install();
        QTRY_COMPARE(fake->kills, 1);
        QVERIFY(controller.busy());
        QVERIFY(controller.error().contains(QStringLiteral("timed out")));
        emit fake->finished(9, QProcess::CrashExit);
        QVERIFY(!controller.busy());
        QVERIFY(controller.error().contains(QStringLiteral("timed out")));
    }
};

QTEST_GUILESS_MAIN(MacAwdlControllerTest)
#include "tst_macawdlcontroller.moc"
