.pragma library

function payloadField(qrPayload, requestedKey) {
    const value = String(qrPayload || "").replace(/^WIFI:/, "");
    const fields = [];
    let field = "";
    let escaped = false;
    for (let index = 0; index < value.length; index++) {
        const character = value[index];
        if (escaped) {
            field += character;
            escaped = false;
        } else if (character === "\\") {
            escaped = true;
        } else if (character === ";") {
            fields.push(field);
            field = "";
        } else {
            field += character;
        }
    }
    const prefix = requestedKey + ":";
    const match = fields.find(function (item) { return item.indexOf(prefix) === 0; });
    return match ? match.slice(prefix.length) : "";
}
