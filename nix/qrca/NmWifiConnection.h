// Qrca delegates credential/profile policy to nm-daemon, never to a second
// independent NetworkManager writer. Credentials travel on stdin, not argv.
#pragma once
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QProcess>
#include <QStandardPaths>
#include <QTimer>
#include <functional>
#include <memory>

inline void nmWifiConnect(QObject *parent, const QString &payload, bool remember,
                          std::function<void(bool)> completion)
{
    struct State {
        QByteArray input;
        QString request;
        QJsonArray early;
        bool submitted = false;
        bool done = false;
        bool published = false;
        bool success = false;
    };
    const auto state = std::make_shared<State>();
    auto *job = new QObject(parent);
    auto *process = new QProcess(job);
    auto *deadline = new QTimer(job);
    deadline->setSingleShot(true);
    process->setStandardErrorFile(QProcess::nullDevice());
    auto publish = [state, job, completion] {
        if (state->published) return;
        state->published = true;
        job->deleteLater();
        completion(state->success);
    };
    auto finish = [state, job, process, publish](bool success) {
        if (state->done) return;
        state->done = true;
        state->success = success;
        // Exiting the owner-scoped client cancels outstanding work. Never replay.
        // Reap asynchronously before publishing; bound even process cleanup.
        process->kill();
        if (process->state() == QProcess::NotRunning) publish();
        else QTimer::singleShot(1000, job, publish);
    };
    auto send = [process](const QJsonObject &request) {
        process->write(QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n');
    };
    auto terminal = [state, finish](const QJsonObject &event) {
        if (event.value(QStringLiteral("request_id")).toString() != state->request) return;
        if (event.value(QStringLiteral("protocol")).toString() != QStringLiteral("nm-api") || event.value(QStringLiteral("version")).toInt() != 2) { finish(false); return; }
        const auto kind = event.value(QStringLiteral("event")).toString();
        if (kind == QStringLiteral("succeeded")) finish(true);
        else if (kind == QStringLiteral("failed") || kind == QStringLiteral("cancelled")) finish(false);
    };
    // Payload lives only until the single request is submitted, not in a timer
    // or process arguments. No transport/backend text is logged or echoed.
    auto pending = std::make_shared<QString>(payload);
    QObject::connect(process, &QProcess::readyReadStandardOutput, job,
        [state, pending, remember, process, send, finish, terminal] {
        state->input += process->readAllStandardOutput();
        if (state->input.size() > 1024 * 1024) { finish(false); return; }
        while (!state->done && state->input.contains('\n')) {
            const auto end = state->input.indexOf('\n');
            const auto line = state->input.left(end);
            state->input.remove(0, end + 1);
            QJsonParseError error;
            const auto document = QJsonDocument::fromJson(line, &error);
            if (error.error != QJsonParseError::NoError || !document.isObject()) { finish(false); return; }
            const auto message = document.object();
            const auto kind = message.value(QStringLiteral("kind")).toString();
            if (kind == QStringLiteral("response")) {
                const auto id = message.value(QStringLiteral("id")).toString();
                if (id != QStringLiteral("subscribe") && id != QStringLiteral("connect")) continue;
                const auto response = message.value(QStringLiteral("response")).toObject();
                if (!message.value(QStringLiteral("ok")).toBool() || !response.value(QStringLiteral("ok")).toBool()
                    || response.value(QStringLiteral("protocol")).toString() != QStringLiteral("nm-api") || response.value(QStringLiteral("version")).toInt() != 2) { finish(false); return; }
                if (id == QStringLiteral("subscribe") && !state->submitted) {
                    state->submitted = true;
                    send({{QStringLiteral("op"), QStringLiteral("call")}, {QStringLiteral("id"), QStringLiteral("connect")}, {QStringLiteral("method"), QStringLiteral("wifi.qr.connect")},
                          {QStringLiteral("params"), QJsonObject{{QStringLiteral("payload"), *pending}, {QStringLiteral("remember"), remember}}}});
                    pending->clear();
                } else if (id == QStringLiteral("connect") && state->request.isEmpty()) {
                    state->request = response.value(QStringLiteral("data")).toObject().value(QStringLiteral("result")).toObject().value(QStringLiteral("request_id")).toString();
                    if (state->request.isEmpty()) { finish(false); return; }
                    for (const auto &event : state->early) terminal(event.toObject());
                    state->early = {};
                }
            } else if (kind == QStringLiteral("event") && message.value(QStringLiteral("stream")).toString() == QStringLiteral("wifi.connect")) {
                const auto event = message.value(QStringLiteral("event")).toObject();
                const auto type = event.value(QStringLiteral("event")).toString();
                if (type != QStringLiteral("succeeded") && type != QStringLiteral("failed") && type != QStringLiteral("cancelled")) continue;
                if (state->request.isEmpty()) {
                    if (state->early.size() >= 8) { finish(false); return; }
                    state->early.append(event);
                } else terminal(event);
            } else if (kind == QStringLiteral("protocol-error") || kind == QStringLiteral("transport-error") || kind == QStringLiteral("disconnected")) finish(false);
        }
    });
    QObject::connect(parent, &QObject::destroyed, job, [state, process] {
        state->done = true;
        state->published = true;
        process->kill();
    });
    QObject::connect(process, &QProcess::started, job, [send] {
        send({{QStringLiteral("op"), QStringLiteral("subscribe")}, {QStringLiteral("id"), QStringLiteral("subscribe")}, {QStringLiteral("streams"), QJsonArray{QStringLiteral("wifi.connect")}}});
    });
    QObject::connect(process, &QProcess::errorOccurred, job, [finish](QProcess::ProcessError) { finish(false); });
    QObject::connect(process, &QProcess::finished, job, [finish, publish](int, QProcess::ExitStatus) { finish(false); publish(); });
    QObject::connect(deadline, &QTimer::timeout, job, [finish] { finish(false); });
    deadline->start(120000);
    const auto program = QStandardPaths::findExecutable(QStringLiteral("nm-daemon"));
    if (program.isEmpty()) { finish(false); return; }
    process->start(program, {QStringLiteral("client")});
}
