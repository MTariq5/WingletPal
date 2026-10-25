#include "FaceDetectionWorker.h"
#include "FaceDetections.h"

#include <QFile>
#include <QTimer>
#include <algorithm>
#include <utility>
#include <opencv2/imgproc.hpp>

namespace {
constexpr int kFrameIntervalMs = 100;
constexpr int kFrameWidth = 640;
constexpr int kFrameHeight = 480;

cv::CascadeClassifier bundledCascade(const QString &path)
{
    QFile model(path);
    cv::CascadeClassifier cascade;
    if (!model.open(QIODevice::ReadOnly))
        return cascade;

    // OpenCV cannot open Qt resource paths; parse the bundled XML in memory.
    cv::FileStorage storage(model.readAll().toStdString(),
                            cv::FileStorage::READ | cv::FileStorage::MEMORY);
    if (!storage.isOpened() || !cascade.read(storage.getFirstTopLevelNode()))
        return {};
    return cascade;
}
}

FaceDetectionWorker::FaceDetectionWorker(QObject *parent)
    : QObject(parent), m_frameTimer(new QTimer(this))
{
    qRegisterMetaType<FaceFrame>();
    // As a child, the timer moves to the worker thread along with this object.
    m_frameTimer->setSingleShot(true);
    m_frameTimer->setInterval(kFrameIntervalMs);
    connect(m_frameTimer, &QTimer::timeout, this, &FaceDetectionWorker::processNextFrame);
}

bool FaceDetectionWorker::loadCascade()
{
    if (!m_faceCascade.empty())
        return true;

    m_faceCascade = bundledCascade(QStringLiteral(":/AvionicsClock/Resources/models/haarcascade_frontalface_default.xml"));
    return !m_faceCascade.empty();
}

bool FaceDetectionWorker::loadProfileCascade()
{
    if (m_profileCascade.empty())
        m_profileCascade = bundledCascade(QStringLiteral(":/AvionicsClock/Resources/models/haarcascade_profileface.xml"));
    return !m_profileCascade.empty();
}

void FaceDetectionWorker::start(int cameraIndex)
{
    if (m_camera.isOpened())
        return;

    try {
        if (!loadCascade() || !loadProfileCascade()) {
            fail(tr("Could not load the frontal/profile face detection models."));
            return;
        }
        openCamera(cameraIndex);
    } catch (const cv::Exception &exception) {
        fail(tr("Camera startup failed: %1").arg(QString::fromUtf8(exception.what())));
    }
}

void FaceDetectionWorker::openCamera(int cameraIndex)
{
#ifdef Q_OS_WIN
    constexpr int backend = cv::CAP_DSHOW;
#else
    constexpr int backend = cv::CAP_ANY;
#endif
    if (!m_camera.open(cameraIndex, backend)) {
        fail(tr("Cannot open camera %1. Check camera access or try another camera number.").arg(cameraIndex));
        return;
    }
    // These are requests: camera drivers may choose another supported size.
    m_camera.set(cv::CAP_PROP_FRAME_WIDTH, kFrameWidth);
    m_camera.set(cv::CAP_PROP_FRAME_HEIGHT, kFrameHeight);
    m_clock.start();
    m_previousFrameSeconds = 0;
    emit started();
    m_frameTimer->start();
}

void FaceDetectionWorker::processNextFrame()
{
    try {
        const double processingStart = m_clock.nsecsElapsed() / 1e9;
        if (!m_camera.read(m_frame) || m_frame.empty()) {
            fail(tr("The camera stopped providing images. Stop other camera apps and try again."));
            return;
        }
        detectFaces();
        publishFrame(processingStart);
        // Yield to the event loop between frames so queued stop requests can run.
        m_frameTimer->start();
    } catch (const cv::Exception &exception) {
        fail(tr("Face detection failed: %1").arg(QString::fromUtf8(exception.what())));
    }
}

void FaceDetectionWorker::detectFaces()
{
    // Bound detection cost even when a driver ignores the requested size.
    if (m_frame.cols > kFrameWidth) {
        const double scale = double(kFrameWidth) / m_frame.cols;
        cv::resize(m_frame, m_frame, cv::Size(), scale, scale, cv::INTER_AREA);
    }
    cv::cvtColor(m_frame, m_grayFrame, cv::COLOR_BGR2GRAY);
    m_faces.clear();
    m_faceCascade.detectMultiScale(m_grayFrame, m_faces, 1.1, 5, 0, cv::Size(40, 40));
    detectProfiles();
}

void FaceDetectionWorker::detectProfiles()
{
    std::vector<cv::Rect> profiles;
    m_profileCascade.detectMultiScale(m_grayFrame, profiles, 1.1, 5, 0, cv::Size(40, 40));
    m_faces = FaceDetections::merge(std::move(m_faces), profiles);

    // A one-sided profile model needs a mirrored pass for the opposite turn.
    cv::flip(m_grayFrame, m_mirroredFrame, 1);
    profiles.clear();
    m_profileCascade.detectMultiScale(m_mirroredFrame, profiles, 1.1, 5, 0, cv::Size(40, 40));
    for (auto &face : profiles)
        face = FaceDetections::unmirror(face, m_grayFrame.cols);
    m_faces = FaceDetections::merge(std::move(m_faces), profiles);
}

void FaceDetectionWorker::publishFrame(double processingStartSeconds)
{
    FaceFrame frame;
    std::vector<cv::Rect2d> normalized;
    for (const auto &box : m_faces) {
        normalized.emplace_back(double(box.x) / m_frame.cols, double(box.y) / m_frame.rows,
                                double(box.width) / m_frame.cols, double(box.height) / m_frame.rows);
        const auto &rect = normalized.back();
        frame.boxes.append(QRectF(rect.x, rect.y, rect.width, rect.height));
    }
    const double seconds = m_clock.nsecsElapsed() / 1e9;
    const auto target = m_tracker.update(normalized, seconds);
    frame.selectedIndex = target.selectedIndex;
    frame.targetId = target.targetId;
    frame.tracking = target.valid;
    frame.measured = QPointF(target.measured.x, target.measured.y);
    frame.estimated = QPointF(target.estimated.x, target.estimated.y);
    frame.predictionRemainingMs = int(target.predictionRemainingSeconds * 1000);
    if (m_diagnosticsEnabled)
        frame.image = QImage(m_frame.data, m_frame.cols, m_frame.rows,
                             static_cast<int>(m_frame.step), QImage::Format_BGR888).copy();
    frame.processingMs = m_clock.nsecsElapsed() / 1e6 - processingStartSeconds * 1000;
    frame.fps = m_previousFrameSeconds > 0 ? 1.0 / (seconds - m_previousFrameSeconds) : 0;
    m_previousFrameSeconds = seconds;
    emit frameProcessed(frame);
}

void FaceDetectionWorker::stop()
{
    releaseCamera();
    emit stopped();
}

void FaceDetectionWorker::releaseCamera()
{
    m_frameTimer->stop();
    m_camera.release();
    m_frame.release();
    m_grayFrame.release();
    m_mirroredFrame.release();
    m_faces.clear();
    m_tracker.reset();
}

void FaceDetectionWorker::fail(const QString &message)
{
    releaseCamera();
    emit errorOccurred(message);
}
