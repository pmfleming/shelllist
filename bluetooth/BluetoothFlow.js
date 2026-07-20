.pragma library

function pairingTransition(currentPrompt, envelope) {
    const event = envelope || ({});
    const prompt = event.data || ({});
    if (event.event === "cancelled") {
        if (currentPrompt && currentPrompt.request_id === prompt.request_id)
            return { changed: true, prompt: null };
        return { changed: false, prompt: currentPrompt || null };
    }
    if (event.event === "requested" || event.event === "display")
        return { changed: true, prompt: prompt };
    return { changed: false, prompt: currentPrompt || null };
}

function isTerminalOperation(operation) {
    return !!operation && ["completed", "failed", "cancelled"].includes(operation.state);
}

function isTerminalTransfer(transfer) {
    return !!transfer && ["complete", "cancelled", "error"].includes(transfer.status);
}
