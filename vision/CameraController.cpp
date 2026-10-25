#include "CameraController.h"
#include "FaceDetectionWorker.h"

CameraController::CameraController(QObject *parent)
    : QObject(parent), m_worker(new FaceDetectionWorker)
{
    m_predictionTimeout.setSingleShot(true);
    connect(&m_predictionTimeout, &QTimer::timeout, this, [this] {
        // A camera stalled in read() must not leave a predicted target alive.
        m_frame.tracking = false;
        m_frame.targetId = 0;
        m_frame.selectedIndex = -1;
        emit facePositionChanged();
        emit diagnosticsChanged();
    });
    m_worker->moveToThread(&m_workerThread);
    connect(&m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(this, &CameraController::startRequested, m_worker, &FaceDetectionWorker::start);
    connect(this, &CameraController::stopRequested, m_worker, &FaceDetectionWorker::stop);
    connect(m_worker, &FaceDetectionWorker::started, this, &CameraController::onCameraStarted);
    connect(m_worker, &FaceDetectionWorker::stopped, this, &CameraController::onCameraStopped);
    connect(m_worker, &FaceDetectionWorker::frameProcessed, this, &CameraController::onFrameProcessed);
    connect(this, &CameraController::diagnosticsRequested, m_worker, &FaceDetectionWorker::setDiagnosticsEnabled);
    connect(m_worker, &FaceDetectionWorker::errorOccurred, this, &CameraController::onCameraError);
    m_workerThread.start();
}

CameraController::~CameraController()
{
    // Release camera resources on their owning thread before ending its event loop.
    QMetaObject::invokeMethod(m_worker, &FaceDetectionWorker::stop, Qt::BlockingQueuedConnection);
    m_workerThread.quit();
    m_workerThread.wait();
}

void CameraController::start(int cameraIndex)
{
    if (m_state != Stopped && m_state != Error)
        return;

    if (cameraIndex < 0) {
        m_errorString = tr("Camera number must be zero or greater.");
        m_state = Error;
        emit stateChanged();
        return;
    }
    m_errorString.clear();
    setState(Starting);
    emit startRequested(cameraIndex);
}

void CameraController::stop()
{
    if (m_state != Starting && m_state != Running)
        return;

    setState(Stopping);
    setFaceCount(0);
    clearFrame();
    emit stopRequested();
}

void CameraController::setState(State state)
{
    if (m_state == state)
        return;
    m_state = state;
    emit stateChanged();
}

void CameraController::onCameraStarted()
{
    if (m_state == Starting)
        setState(Running);
}

void CameraController::onCameraStopped()
{
    setFaceCount(0);
    clearFrame();
    if (m_state == Stopping)
        setState(Stopped);
}

void CameraController::onFrameProcessed(const FaceFrame &frame)
{
    if (m_state != Running)
        return;

    m_frame = frame;
    if (frame.tracking)
        m_predictionTimeout.start(qMax(1, frame.predictionRemainingMs));
    else
        m_predictionTimeout.stop();
    if (!m_diagnosticsEnabled)
        m_frame.image = {};
    setFaceCount(static_cast<int>(frame.boxes.size()));
    emit facePositionChanged();
    emit diagnosticsChanged();
}

void CameraController::onCameraError(const QString &message)
{
    m_errorString = message;
    setFaceCount(0);
    setState(Error);
    clearFrame();
}

void CameraController::setFaceCount(int count)
{
    if (m_faceCount == count)
        return;
    m_faceCount = count;
    emit facesChanged();
}

QPointF CameraController::facePosition() const
{
    if (!m_frame.tracking)
        return {};
    const auto position = m_kalmanEnabled ? m_frame.estimated : m_frame.measured;
    return QPointF(2 * position.x() - 1, 2 * position.y() - 1);
}

void CameraController::clearFrame()
{
    m_predictionTimeout.stop();
    m_frame = {};
    emit facePositionChanged();
    emit diagnosticsChanged();
}

void CameraController::setDiagnosticsEnabled(bool enabled)
{
    if (m_diagnosticsEnabled == enabled)
        return;
    m_diagnosticsEnabled = enabled;
    if (!enabled) {
        m_frame.image = {};
        emit diagnosticsChanged();
    }
    emit diagnosticsRequested(enabled);
    emit diagnosticsEnabledChanged();
}

void CameraController::setKalmanEnabled(bool enabled)
{
    if (m_kalmanEnabled == enabled)
        return;
    m_kalmanEnabled = enabled;
    emit kalmanEnabledChanged();
    emit facePositionChanged();
}
