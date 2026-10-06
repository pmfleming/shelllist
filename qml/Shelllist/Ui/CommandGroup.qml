import QtQuick

// Command-only content may contain dynamic delegates, but never editable
// fields. Navigation discovers commands/headers without waiting for those
// delegates to decide whether a field page is ready or changing its Tab order.
Column {}
