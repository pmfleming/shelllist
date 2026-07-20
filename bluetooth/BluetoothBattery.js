.pragma library

const componentOrder = ({ left: 0, right: 1, case: 2, main: 3 });

function isValid(report) {
    return !!report
        && typeof report.percentage === "number"
        && isFinite(report.percentage)
        && report.percentage >= 0
        && report.percentage <= 100;
}

function orderValue(report) {
    const component = String((report && report.component) || "").toLowerCase();
    return componentOrder[component] === undefined ? 100 : componentOrder[component];
}

function ordered(reports) {
    return (reports || [])
        .filter(isValid)
        .map(function (report, index) { return { report: report, index: index }; })
        .sort(function (left, right) {
            const componentDifference = orderValue(left.report) - orderValue(right.report);
            return componentDifference !== 0 ? componentDifference : left.index - right.index;
        })
        .map(function (entry) { return entry.report; });
}

function compactLabel(report) {
    const component = String((report && report.component) || "").toLowerCase();
    if (component === "left")
        return "L";
    if (component === "right")
        return "R";
    if (component === "case")
        return "Case";
    if (component === "main")
        return "";
    return (report && (report.label || report.component)) || "Battery";
}

function summary(reports) {
    return ordered(reports).map(function (report) {
        const label = compactLabel(report);
        return (label.length > 0 ? label + " " : "") + report.percentage + "%";
    }).join(" · ");
}

function sourceLabel(reports) {
    const values = ordered(reports);
    if (values.some(function (report) { return report.source === "google-fast-pair-message-stream"; }))
        return "Fast Pair component data";
    if (values.some(function (report) { return report.source === "bluez"; }))
        return "BlueZ aggregate data";
    const source = values.length > 0 ? values[0].source : "";
    return source ? source : "";
}
