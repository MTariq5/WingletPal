#include "CitySearch.h"
#include "LocationProvider.h"
#include <QtTest>
#include <QTcpServer>
#include <QTcpSocket>
#include <QTemporaryDir>
#include <QUrlQuery>
#include <functional>

class CitySearchTests : public QObject {
    Q_OBJECT
private slots:
    void selectionPersistsReturnedCoordinates();
    void arabicQueryResolvesEnglishName_data();
    void arabicQueryResolvesEnglishName();
    void invalidResponseAndEmptyResults_data();
    void invalidResponseAndEmptyResults();
    void newerQueryDiscardsOlderResult();
};

static void serveRequests(QTcpServer &server, const std::function<QByteArray(const QUrl &)> &respond)
{
    QObject::connect(&server, &QTcpServer::newConnection, &server, [&server, respond] {
        auto *socket = server.nextPendingConnection();
        QObject::connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
        QObject::connect(socket, &QTcpSocket::readyRead, socket, [socket, respond] {
            const auto request = socket->readAll();
            const auto payload = respond(QUrl::fromEncoded(request.split(' ').value(1)));
            socket->write("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "
                          + QByteArray::number(payload.size()) + "\r\nConnection: close\r\n\r\n" + payload);
            socket->disconnectFromHost();
        });
    });
}

static void serve(QTcpServer &server, const QByteArray &payload)
{
    serveRequests(server, [payload](const QUrl &) { return payload; });
}

static QUrl endpoint(const QTcpServer &server)
{
    return QUrl(QString("http://127.0.0.1:%1/search").arg(server.serverPort()));
}

void CitySearchTests::selectionPersistsReturnedCoordinates()
{
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost));
    serve(server, R"({"results":[{"name":"Test City","admin1":"Region","country":"Country","latitude":30.31,"longitude":31.74}]})");
    CitySearch search(endpoint(server));
    search.search("Test City");
    QTRY_VERIFY_WITH_TIMEOUT(!search.searching(), 2000);
    QVERIFY(search.error().isEmpty());
    QCOMPARE(search.results().size(), 1);
    const auto selected = search.results().first().toMap();
    QCOMPARE(selected.value("region").toString(), QString("Region"));
    QTemporaryDir folder;
    QVERIFY(folder.isValid());
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, folder.path());
    LocationProvider location;
    QVERIFY(location.saveManualLocation(selected.value("name").toString(), selected.value("latitude").toDouble(), selected.value("longitude").toDouble()));
    LocationProvider restored;
    QCOMPARE(restored.getCity(), QString("Test City"));
    QCOMPARE(restored.getLatitude(), 30.31);
    QCOMPARE(restored.getLongitude(), 31.74);
}

void CitySearchTests::arabicQueryResolvesEnglishName_data()
{
    QTest::addColumn<bool>("lookupFails");
    QTest::newRow("english-name-saved") << false;
    QTest::newRow("failed-lookup-no-arabic-fallback") << true;
}

void CitySearchTests::arabicQueryResolvesEnglishName()
{
    QFETCH(bool, lookupFails);
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost));
    QStringList languages, ids;
    serveRequests(server, [&](const QUrl &url) {
        QUrlQuery query(url);
        languages.append(query.queryItemValue("language"));
        if (url.path().endsWith("/search"))
            return QString::fromUtf8(R"({"results":[{"id":360630,"name":"القاهرة","latitude":30,"longitude":31}]})").toUtf8();
        ids.append(query.queryItemValue("id"));
        return lookupFails ? QByteArray("invalid")
                           : QByteArray(R"({"id":360630,"name":"Cairo","admin1":"Cairo","country":"Egypt","latitude":30.06,"longitude":31.25})");
    });
    CitySearch search(endpoint(server));
    search.search(QString::fromUtf8("القاهرة"));
    QTRY_VERIFY_WITH_TIMEOUT(!search.searching(), 3000);
    QCOMPARE(languages, QStringList({"ar", "en"}));
    QCOMPARE(ids, QStringList({"360630"}));
    if (lookupFails) {
        QVERIFY(search.results().isEmpty());
        QVERIFY(!search.error().isEmpty());
        return;
    }
    QCOMPARE(search.results().size(), 1);
    const auto selected = search.results().first().toMap();
    QCOMPARE(selected.value("name").toString(), QString("Cairo"));
    QTemporaryDir folder;
    QVERIFY(folder.isValid());
    QSettings::setPath(QSettings::IniFormat, QSettings::UserScope, folder.path());
    LocationProvider location;
    QVERIFY(location.saveManualLocation(selected.value("name").toString(), selected.value("latitude").toDouble(), selected.value("longitude").toDouble()));
    LocationProvider restored;
    QCOMPARE(restored.getCity(), QString("Cairo"));
    QCOMPARE(restored.getLatitude(), 30.06);
}

void CitySearchTests::invalidResponseAndEmptyResults_data()
{
    QTest::addColumn<QByteArray>("payload");
    QTest::addColumn<bool>("expectError");
    QTest::newRow("invalid-json") << QByteArray("bad json") << true;
    QTest::newRow("wrong-results-type") << QByteArray(R"({"results":42})") << true;
    QTest::newRow("untranslated-name") << QString::fromUtf8(R"({"results":[{"name":"القاهرة","latitude":30,"longitude":31}]})").toUtf8() << true;
    QTest::newRow("no-matches") << QByteArray("{}") << false;
    QTest::newRow("missing-coordinates") << QByteArray(R"({"results":[{"name":"Invalid"}]})") << false;
}

void CitySearchTests::invalidResponseAndEmptyResults()
{
    QFETCH(QByteArray, payload);
    QFETCH(bool, expectError);
    QTcpServer server;
    QVERIFY(server.listen(QHostAddress::LocalHost));
    serve(server, payload);
    CitySearch search(endpoint(server));
    search.search("Anything");
    QTRY_VERIFY_WITH_TIMEOUT(!search.searching(), 2000);
    QVERIFY(search.results().isEmpty());
    QCOMPARE(!search.error().isEmpty(), expectError);
}

void CitySearchTests::newerQueryDiscardsOlderResult()
{
    QTcpServer oldServer;
    QVERIFY(oldServer.listen(QHostAddress::LocalHost));
    CitySearch search(endpoint(oldServer));
    search.search("Old");
    QTRY_VERIFY_WITH_TIMEOUT(oldServer.hasPendingConnections(), 2000);
    auto *oldSocket = oldServer.nextPendingConnection();
    search.clear();
    QVERIFY(!search.searching());
    QVERIFY(!search.searched());
    serve(oldServer, R"({"results":[{"name":"New","latitude":1,"longitude":2}]})");
    search.search("New");
    QTRY_VERIFY_WITH_TIMEOUT(!search.searching(), 2000);
    QCOMPARE(search.results().first().toMap().value("name").toString(), QString("New"));
    oldSocket->deleteLater();
    search.clear();
    QVERIFY(search.results().isEmpty());
}
QTEST_GUILESS_MAIN(CitySearchTests)
#include "CitySearchTests.moc"
