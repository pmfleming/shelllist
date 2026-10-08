.pragma library

function dateKey(value) {
    const year = value.getFullYear();
    const month = String(value.getMonth() + 1).padStart(2, "0");
    const day = String(value.getDate()).padStart(2, "0");
    return year + "-" + month + "-" + day;
}

function startOfDay(value) {
    return new Date(value.getFullYear(), value.getMonth(), value.getDate());
}
