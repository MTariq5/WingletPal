#ifndef FACEDETECTIONS_H
#define FACEDETECTIONS_H

#include <algorithm>
#include <vector>
#include <opencv2/core.hpp>

namespace FaceDetections {

inline cv::Rect unmirror(const cv::Rect &face, int frameWidth)
{
    return {frameWidth - face.x - face.width, face.y, face.width, face.height};
}

inline std::vector<cv::Rect> merge(std::vector<cv::Rect> accepted,
                                    const std::vector<cv::Rect> &candidates)
{
    // Keep frontal boxes when both cascades see one face. Intersection over the
    // smaller area also catches nested profile/frontal boxes with different sizes.
    for (const auto &candidate : candidates) {
        const bool duplicate = std::any_of(accepted.begin(), accepted.end(),
                                          [&candidate](const cv::Rect &face) {
            return (face & candidate).area() > 0.5 * std::min(face.area(), candidate.area());
        });
        if (!duplicate)
            accepted.push_back(candidate);
    }
    return accepted;
}
}

#endif // FACEDETECTIONS_H
