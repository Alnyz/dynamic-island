#include "covercolor.h"

#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

class TestCoverColor : public QObject
{
    Q_OBJECT

    static QImage filled(const QColor &c)
    {
        QImage img(64, 64, QImage::Format_RGB32);
        img.fill(c);
        return img;
    }

private Q_SLOTS:
    void picksTheMainColour()
    {
        const QColor red = CoverColor::pick(filled(QColor(200, 30, 30)));
        QVERIFY(red.isValid());
        QVERIFY(red.hslHue() < 15 || red.hslHue() > 345);
        const QColor blue = CoverColor::pick(filled(QColor(20, 60, 220)));
        QVERIFY(blue.hslHue() > 200 && blue.hslHue() < 250);
    }

    void greyscaleGivesNothing()
    {
        QVERIFY(!CoverColor::pick(filled(Qt::gray)).isValid());
        QVERIFY(!CoverColor::pick(filled(Qt::black)).isValid());
        QVERIFY(!CoverColor::pick(filled(Qt::white)).isValid());
        QVERIFY(!CoverColor::pick(QImage()).isValid());
    }

    void darkCoversAreLiftedToBeReadable()
    {
        const QColor c = CoverColor::pick(filled(QColor(40, 10, 60)));
        QVERIFY(c.isValid());
        QVERIFY(c.lightnessF() >= 0.49);
        const QColor pale = CoverColor::pick(filled(QColor(255, 220, 230)));
        if (pale.isValid())
            QVERIFY(pale.lightnessF() <= 0.69);
    }

    void vividWinsOverLargeDullArea()
    {
        // Mostly dark grey with a vivid orange band: the band sets the colour.
        QImage img = filled(QColor(40, 40, 40));
        for (int y = 0; y < 16; ++y)
            for (int x = 0; x < 64; ++x)
                img.setPixel(x, y, qRgb(255, 140, 0));
        const QColor c = CoverColor::pick(img);
        QVERIFY(c.isValid());
        QVERIFY(c.hslHue() > 20 && c.hslHue() < 45);
    }

    void loadsLocalFiles()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("cover.png"));
        QVERIFY(filled(QColor(30, 180, 60)).save(path));
        CoverColor cc;
        QSignalSpy changed(&cc, &CoverColor::colorChanged);
        cc.setSource(QUrl::fromLocalFile(path));
        QCOMPARE(changed.count(), 1);
        QVERIFY(cc.valid());
        QVERIFY(cc.color().hslHue() > 100 && cc.color().hslHue() < 150);
        cc.setSource(QUrl());
        QVERIFY(!cc.valid());
    }
};

QTEST_GUILESS_MAIN(TestCoverColor)
#include "tst_covercolor.moc"
