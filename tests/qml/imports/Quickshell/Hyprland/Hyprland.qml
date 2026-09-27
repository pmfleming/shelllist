pragma Singleton
import QtQuick

// Platform event boundary only; controls and restoration use the native engine.
QtObject {
    signal rawEvent(var event)
}
