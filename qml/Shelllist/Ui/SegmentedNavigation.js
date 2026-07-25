.pragma library

function optionEnabled(options, index) {
    return index >= 0 && index < options.length && options[index].enabled !== false;
}

function nextEnabledIndex(options, currentIndex, delta) {
    if (!options || options.length === 0 || delta === 0)
        return -1;
    let index = currentIndex >= 0 ? currentIndex : (delta > 0 ? -1 : options.length);
    for (let remaining = options.length; remaining > 0; --remaining) {
        index += delta;
        if (index < 0 || index >= options.length)
            return -1;
        if (optionEnabled(options, index))
            return index;
    }
    return -1;
}
