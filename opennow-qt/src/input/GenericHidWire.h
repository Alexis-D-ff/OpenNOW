#pragma once

#include <QByteArray>
#include <QList>
#include <QMetaType>
#include <QtGlobal>

enum class GenericHidAdmission : quint8 { Pending, Admitted, Declined };

struct GenericHidInterface
{
    quint8 number = 0;
    QByteArray descriptor;
};

struct GenericHidDeviceClaim
{
    quint8 slot = 0;
    quint64 incarnation = 0;
    quint16 vendor = 0;
    quint16 product = 0;
    quint16 revision = 0;
    QList<GenericHidInterface> interfaces;
};

struct GenericHidReport
{
    quint8 slot = 0;
    quint64 incarnation = 0;
    quint8 interfaceNumber = 0;
    quint8 operation = 0;
    bool error = false;
    QByteArray bytes;
};

Q_DECLARE_METATYPE(GenericHidInterface)
Q_DECLARE_METATYPE(GenericHidDeviceClaim)
Q_DECLARE_METATYPE(QList<GenericHidDeviceClaim>)
Q_DECLARE_METATYPE(GenericHidReport)
Q_DECLARE_METATYPE(GenericHidAdmission)
