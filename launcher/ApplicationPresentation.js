.pragma library

function runningWindowIcon(instanceCount) {
    return Number(instanceCount || 0) > 1 ? "󰖲" : "󰖯";
}

function categoryFilterOptions(categories) {
    return [
        {
            value: "",
            label: "All",
            icon: "󰀻"
        }
    ].concat(categories || []);
}

function categoryFilterOption(options, value) {
    return (options || []).find(function (option) {
        return option.value === value;
    }) || (options || [])[0] || ({
            value: "",
            label: "All",
            icon: "󰀻"
        });
}

function nextCategoryFilterOption(options, value) {
    const filters = options || [];
    if (filters.length === 0)
        return categoryFilterOption(filters, "");
    const current = categoryFilterOption(filters, value);
    const index = filters.indexOf(current);
    return filters[(index + 1) % filters.length];
}

function pageStatus(page) {
    const applications = page.applications || [];
    let status = applications.length + (applications.length === 1 ? " application" : " applications");
    if (page.has_more)
        status += " · more available";
    if (!page.hyprland_available)
        status += " · launch only";
    return status;
}
