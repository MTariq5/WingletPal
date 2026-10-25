#ifndef FACEFRAME_H
#define FACEFRAME_H

#include <QImage>
#include <QMetaType>
#include <QPointF>
#include <QRectF>
#include <QVector>

struct FaceFrame {
    QVector<QRectF> boxes; // normalized [0, 1], unmirrored camera coordinates
    QPointF measured;
    QPointF estimated;
    int selectedIndex = -1;
    int targetId = 0;
    bool tracking = false;
    double processingMs = 0;
    double fps = 0;
    int predictionRemainingMs = 0;
    QImage image; // owned copy, only present when preview is requested
};
Q_DECLARE_METATYPE(FaceFrame)

#endif
