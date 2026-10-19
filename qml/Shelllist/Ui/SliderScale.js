.pragma library

// The ruler is fixed; dependent bounds restrict choices, never stretch it.
function position(values, value) {
    if (!values.length || !Number.isFinite(value)) return 0;
    if (value <= values[0]) return 0;
    for (let i = 1; i < values.length; ++i) {
        if (value <= values[i])
            return (i - 1 + (value - values[i - 1]) / (values[i] - values[i - 1])) / (values.length - 1);
    }
    return 1;
}
function choices(values, minimum, maximum) {
    return values.filter(value => value >= minimum && value <= maximum);
}
function adjacent(values, value, direction, minimum, maximum) {
    const allowed = choices(values, minimum, maximum);
    if (direction > 0) return allowed.find(candidate => candidate > value) ?? value;
    return allowed.filter(candidate => candidate < value).pop() ?? value;
}
function at(values, fraction, minimum, maximum) {
    const allowed = choices(values, minimum, maximum);
    if (!allowed.length) return NaN;
    return allowed.reduce((best, value) => Math.abs(position(values, value) - fraction) < Math.abs(position(values, best) - fraction) ? value : best);
}
function chargeValues() {
    return [50, 55, 60, 65, 70].concat(Array.from({length: 26}, (_, i) => 75 + i));
}
function sleepValues() {
    return [5, 10, 15, 20, 25, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720];
}
