#ifndef CAMERACONTROLLER_H
#define CAMERACONTROLLER_H

#include <QObject>
#include <QPointF>
#include <QThread>
#include <QTimer>
#include "FaceFrame.h"

class FaceDetectionWorker;

class CameraController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool running READ running NOTIFY stateChanged)
    Q_PROPERTY(int faceCount READ faceCount NOTIFY facesChanged)
    Q_PROPERTY(bool facePresent READ facePresent NOTIFY facesChanged)
    Q_PROPERTY(QPointF facePosition READ facePosition NOTIFY facePositionChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY stateChanged)
    Q_PROPERTY(bool diagnosticsEnabled READ diagnosticsEnabled WRITE setDiagnosticsEnabled NOTIFY diagnosticsEnabledChanged)
    Q_PROPERTY(bool kalmanEnabled READ kalmanEnabled WRITE setKalmanEnabled NOTIFY kalmanEnabledChanged)
    Q_PROPERTY(bool trackingValid READ trackingValid NOTIFY diagnosticsChanged)
    Q_PROPERTY(bool predicting READ predicting NOTIFY diagnosticsChanged)
    Q_PROPERTY(int targetId READ targetId NOTIFY diagnosticsChanged)
    Q_PROPERTY(double processingMs READ processingMs NOTIFY diagnosticsChanged)
    Q_PROPERTY(double fps READ fps NOTIFY diagnosticsChanged)

public:
    enum State { Stopped, Starting, Running, Stopping, Error };
    Q_ENUM(State)

    explicit CameraController(QObject *parent = nullptr);
    ~CameraController() override;

    State state() const { return m_state; }
    bool running() const { return m_state == Running; }
    int faceCount() const { return m_faceCount; }
    bool facePresent() const { return m_faceCount > 0; }
    QPointF facePosition() const;
    QString errorString() const { return m_errorString; }
    bool diagnosticsEnabled() const { return m_diagnosticsEnabled; }
    bool kalmanEnabled() const { return m_kalmanEnabled; }
    bool trackingValid() const { return m_frame.tracking; }
    bool predicting() const { return m_frame.tracking && m_frame.selectedIndex < 0; }
    int targetId() const { return m_frame.targetId; }
    double processingMs() const { return m_frame.processingMs; }
    double fps() const { return m_frame.fps; }
    const FaceFrame &diagnosticFrame() const { return m_frame; }
    void setDiagnosticsEnabled(bool enabled);
    void setKalmanEnabled(bool enabled);

    Q_INVOKABLE void start(int cameraIndex);
    Q_INVOKABLE void stop();

signals:
    void stateChanged();
    void facesChanged();
    void facePositionChanged();
    void startRequested(int cameraIndex);
    void stopRequested();
    void diagnosticsEnabledChanged();
    void kalmanEnabledChanged();
    void diagnosticsChanged();
    void diagnosticsRequested(bool enabled);

private:
    void onCameraStarted();
    void onCameraStopped();
    void onFrameProcessed(const FaceFrame &frame);
    void onCameraError(const QString &message);
    void setState(State state);
    void setFaceCount(int count);
    void clearFrame();

    QThread m_workerThread;
    FaceDetectionWorker *m_worker;
    State m_state = Stopped;
    int m_faceCount = 0;
    FaceFrame m_frame;
    bool m_diagnosticsEnabled = false;
    bool m_kalmanEnabled = true;
    QTimer m_predictionTimeout;
    QString m_errorString;
};

#endif // CAMERACONTROLLER_H
