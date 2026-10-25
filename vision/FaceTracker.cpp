#include "FaceTracker.h"

#include <algorithm>
#include <cmath>

namespace {
constexpr double kPredictionSeconds = 0.6;
constexpr double kMeasurementVariance = 0.0004;
cv::Point2d center(const cv::Rect2d &box)
{
    return {box.x + box.width / 2, box.y + box.height / 2};
}
}

void FaceTracker::reset()
{
    *this = FaceTracker();
}

void FaceTracker::acquire(const cv::Rect2d &face, double seconds)
{
    m_measured = center(face);
    m_state = {m_measured.x, m_measured.y, 0, 0};
    m_covariance = cv::Matx44d::diag(cv::Vec4d(0.0025, 0.0025, 0.1, 0.1));
    m_lastBox = face;
    m_lastSeen = seconds;
    m_valid = true;
    ++m_targetId;
}

void FaceTracker::predict(double dt)
{
    const cv::Matx44d transition(1, 0, dt, 0, 0, 1, 0, dt,
                                0, 0, 1, 0, 0, 0, 0, 1);
    // Constant velocity with uncertain acceleration (sigma = 0.5 image widths/s²).
    const cv::Matx<double, 4, 2> acceleration(dt * dt / 2, 0, 0, dt * dt / 2,
                                            dt, 0, 0, dt);
    m_state = transition * m_state;
    m_covariance = transition * m_covariance * transition.t()
                   + 0.25 * acceleration * acceleration.t();
}

void FaceTracker::correct(const cv::Point2d &measurement)
{
    const cv::Matx<double, 2, 4> observation(1, 0, 0, 0, 0, 1, 0, 0);
    const auto noise = cv::Matx22d::eye() * kMeasurementVariance;
    const auto innovation = observation * m_covariance * observation.t() + noise;
    const auto gain = m_covariance * observation.t() * innovation.inv();
    m_state += gain * (cv::Vec2d(measurement.x, measurement.y) - observation * m_state);
    const auto residual = cv::Matx44d::eye() - gain * observation;
    // Joseph form keeps the covariance numerically well behaved.
    m_covariance = residual * m_covariance * residual.t() + gain * noise * gain.t();
}

int FaceTracker::match(const std::vector<cv::Rect2d> &faces) const
{
    const double gate = std::clamp(std::hypot(m_lastBox.width, m_lastBox.height) * 0.6, 0.08, 0.25);
    double bestDistance = gate;
    int best = -1;
    for (size_t i = 0; i < faces.size(); ++i) {
        const double ratio = faces[i].area() / m_lastBox.area();
        const double distance = cv::norm(center(faces[i]) - cv::Point2d(m_state[0], m_state[1]));
        if (ratio >= 0.4 && ratio <= 2.5 && distance < bestDistance) {
            bestDistance = distance;
            best = static_cast<int>(i);
        }
    }
    return best;
}

FaceTracker::Result FaceTracker::update(const std::vector<cv::Rect2d> &faces, double seconds)
{
    if (m_valid && (seconds - m_lastSeen > kPredictionSeconds || seconds < m_lastUpdate))
        m_valid = false;
    int selected = -1;
    if (m_valid) {
        predict(seconds - m_lastUpdate);
        selected = match(faces);
        if (selected >= 0) {
            m_lastBox = faces[selected];
            m_measured = center(m_lastBox);
            correct(m_measured);
            m_lastSeen = seconds;
        }
    } else if (!faces.empty()) {
        selected = static_cast<int>(std::max_element(faces.begin(), faces.end(),
            [](const cv::Rect2d &a, const cv::Rect2d &b) { return a.area() < b.area(); }) - faces.begin());
        acquire(faces[selected], seconds);
    }
    m_lastUpdate = seconds;
    if (!m_valid)
        return {};
    return {selected, m_targetId, true, m_measured,
            {std::clamp(m_state[0], 0.0, 1.0), std::clamp(m_state[1], 0.0, 1.0)},
            std::max(0.0, kPredictionSeconds - (seconds - m_lastSeen))};
}
