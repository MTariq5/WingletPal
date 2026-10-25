#ifndef CAMERAPREVIEW_H
#define CAMERAPREVIEW_H

#include <QQuickPaintedItem>
#include <QPointer>
#include "CameraController.h"

class CameraPreview : public QQuickPaintedItem
{
    Q_OBJECT
    Q_PROPERTY(CameraController *camera READ camera WRITE setCamera NOTIFY cameraChanged)
public:
    explicit CameraPreview(QQuickItem *parent = nullptr);
    CameraController *camera() const { return m_camera; }
    void setCamera(CameraController *camera);
    void paint(QPainter *painter) override;
signals:
    void cameraChanged();
private:
    QPointer<CameraController> m_camera;
};

#endif
