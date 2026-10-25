#ifndef FACEDETECTIONWORKER_H
#define FACEDETECTIONWORKER_H

#include <QObject>
#include <QPointF>
#include <QElapsedTimer>
#include "FaceFrame.h"
#include "FaceTracker.h"
#include <opencv2/core.hpp>
#include <opencv2/objdetect.hpp>
#include <opencv2/videoio.hpp>

class QTimer;

class FaceDetectionWorker : public QObject
{
    Q_OBJECT

public:
    explicit FaceDetectionWorker(QObject *parent = nullptr);

public slots:
    void start(int cameraIndex);
    void stop();
    void setDiagnosticsEnabled(bool enabled) { m_diagnosticsEnabled = enabled; }

signals:
    void started();
    void stopped();
    void frameProcessed(const FaceFrame &frame);
    void errorOccurred(const QString &message);

private:
    bool loadCascade();
    bool loadProfileCascade();
    void openCamera(int cameraIndex);
    void processNextFrame();
    void detectFaces();
    void detectProfiles();
    void publishFrame(double processingStartSeconds);
    void releaseCamera();
    void fail(const QString &message);

    QTimer *m_frameTimer;
    cv::VideoCapture m_camera;
    cv::CascadeClassifier m_faceCascade;
    cv::CascadeClassifier m_profileCascade;
    cv::Mat m_frame;
    cv::Mat m_grayFrame;
    cv::Mat m_mirroredFrame;
    std::vector<cv::Rect> m_faces;
    FaceTracker m_tracker;
    QElapsedTimer m_clock;
    double m_previousFrameSeconds = 0;
    bool m_diagnosticsEnabled = false;
};

#endif // FACEDETECTIONWORKER_H
