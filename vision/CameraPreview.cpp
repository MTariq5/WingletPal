#include "CameraPreview.h"

#include <QPainter>

CameraPreview::CameraPreview(QQuickItem *parent) : QQuickPaintedItem(parent)
{
    setAntialiasing(true);
}

void CameraPreview::setCamera(CameraController *camera)
{
    if (m_camera == camera)
        return;
    if (m_camera)
        disconnect(m_camera, nullptr, this, nullptr);
    m_camera = camera;
    if (m_camera) {
        connect(m_camera, &CameraController::diagnosticsChanged, this, [this] { update(); });
        connect(m_camera, &QObject::destroyed, this, [this] { update(); });
    }
    emit cameraChanged();
    update();
}

void CameraPreview::paint(QPainter *painter)
{
    painter->fillRect(boundingRect(), QColor("#080D12"));
    if (!m_camera || m_camera->diagnosticFrame().image.isNull()) {
        painter->setPen(Qt::white);
        painter->drawText(boundingRect(), Qt::AlignCenter, tr("Waiting for camera…"));
        return;
    }
    const auto &frame = m_camera->diagnosticFrame();
    const QSizeF size = frame.image.size().scaled(QSize(int(width()), int(height())), Qt::KeepAspectRatio);
    const QRectF view((width() - size.width()) / 2, (height() - size.height()) / 2,
                       size.width(), size.height());
    painter->save();
    painter->translate(view.right(), view.top());
    painter->scale(-1, 1);
    painter->drawImage(QRectF(QPointF(), size), frame.image);
    painter->restore();
    for (int i = 0; i < frame.boxes.size(); ++i) {
        const auto &box = frame.boxes[i];
        painter->setPen(QPen(i == frame.selectedIndex ? QColor("#80ED99") : QColor("#F1C75B"), 2));
        painter->drawRect(QRectF(view.left() + (1 - box.right()) * view.width(),
            view.top() + box.top() * view.height(), box.width() * view.width(), box.height() * view.height()));
    }
    if (!frame.tracking)
        return;
    const auto pixel = [&view](const QPointF &p) {
        return QPointF(view.left() + (1 - p.x()) * view.width(), view.top() + p.y() * view.height());
    };
    // Missing measurements are not drawn as if freshly observed.
    if (frame.selectedIndex >= 0) {
        painter->setPen(QPen(Qt::white, 2));
        painter->drawEllipse(pixel(frame.measured), 3, 3);
    }
    painter->setPen(QPen(QColor("#49D6FF"), 2, frame.selectedIndex < 0 ? Qt::DashLine : Qt::SolidLine));
    painter->drawEllipse(pixel(frame.estimated), 6, 6);
}
