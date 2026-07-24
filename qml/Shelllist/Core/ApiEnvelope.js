.pragma library

function compatibilityError(envelope, protocol, version, daemonName) {
    return (!envelope || envelope.protocol !== protocol || envelope.version !== version)
        ? daemonName + " returned an incompatible response" : "";
}

function responseError(envelope, transportError, protocol, version, daemonName, fallback) {
    if (transportError)
        return transportError;
    return compatibilityError(envelope, protocol, version, daemonName)
        || (envelope.ok ? "" : ((envelope.error && envelope.error.message) || fallback));
}
