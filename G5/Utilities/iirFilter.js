/*
 * iir_filter.js
 *
 * Implements a simple 1st-order Infinite Impulse Response (IIR) low-pass filter.
 * This is also known as an Exponential Moving Average (EMA).
 *
 * Formula:
 *   y[n] = (1 - alpha) * y[n-1] + alpha * x[n]
 *
 * Where:
 *   - x[n] = current input sample
 *   - y[n] = filtered output
 *   - alpha = filter coefficient (0 < alpha <= 1)
 *
 * Notes:
 *   - Smaller alpha → more smoothing, but slower response
 *   - Larger alpha → less smoothing, faster response
 *   - Alpha can be set directly, or derived from a time constant
 */

class IIRFilter {
    /**
     * Constructor
     * @param {number} alpha - filter coefficient (default 0.1)
     */
    constructor(alpha = 0.1) {
        this.alpha = alpha;   // smoothing factor
        this.y = NaN;         // last filtered value, starts uninitialized
    }

    /**
     * Set the filter coefficient directly.
     * @param {number} alpha - value between 0 and 1
     */
    setAlpha(alpha) {
        if (typeof alpha !== "number") return;
        if (alpha <= 0) alpha = 1e-6;  // avoid zero (no update)
        if (alpha > 1) alpha = 1;      // clamp to 1
        this.alpha = alpha;
    }

    /**
     * Set alpha based on sample period (dt) and time constant (tau).
     * Formula: alpha = dt / (tau + dt)
     *
     * @param {number} dtSec - sample period in seconds
     * @param {number} tauSec - filter time constant in seconds
     */
    setTimeConstant(dtSec, tauSec) {
        if (dtSec > 0 && tauSec >= 0) {
            this.setAlpha(dtSec / (tauSec + dtSec));
        }
    }

    /**
     * Reset the filter to an initial value.
     * @param {number} initialValue - optional initial value
     */
    reset(initialValue) {
        this.y = (typeof initialValue === "number") ? initialValue : NaN;
    }

    /**
     * Update the filter with a new input sample.
     * @param {number} x - current input sample
     * @returns {number} filtered output
     */
    update(x) {
        if (isNaN(this.y)) {
            // First sample: initialize directly
            this.y = x;
            return this.y;
        }
        // Apply IIR filter equation
        this.y = this.y * (1 - this.alpha) + x * this.alpha;
        return this.y;
    }
}

/*
 * Export a default instance for QML use.
 * You can also create multiple filters if needed:
 *    var myFilter = new IIRFilter(0.2);
 */
var airspeedFilter = new IIRFilter(0.15);

function update(value) {
    return airspeedFilter.update(value);
}

function setAlpha(alpha) {
    airspeedFilter.setAlpha(alpha);
}

function setTimeConstant(dt, tau) {
    airspeedFilter.setTimeConstant(dt, tau);
}

function reset(initialValue) {
    airspeedFilter.reset(initialValue);
}
