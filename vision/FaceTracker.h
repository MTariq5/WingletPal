#ifndef FACETRACKER_H
#define FACETRACKER_H

#include <opencv2/core.hpp>
#include <vector>

// Coordinates are fractions of the image size, independent of camera resolution.
class FaceTracker
{
public:
    struct Result {
        int selectedIndex = -1;
        int targetId = 0;
        bool valid = false;
        cv::Point2d measured;
        cv::Point2d estimated;
        double predictionRemainingSeconds = 0;
    };

    Result update(const std::vector<cv::Rect2d> &faces, double seconds);
    void reset();

private:
    void acquire(const cv::Rect2d &face, double seconds);
    void predict(double dt);
    void correct(const cv::Point2d &measurement);
    int match(const std::vector<cv::Rect2d> &faces) const;

    cv::Vec4d m_state{}; // x, y, vx, vy
    cv::Matx44d m_covariance = cv::Matx44d::eye();
    cv::Rect2d m_lastBox;
    cv::Point2d m_measured;
    double m_lastSeen = 0;
    double m_lastUpdate = 0;
    int m_targetId = 0;
    bool m_valid = false;
};

#endif
