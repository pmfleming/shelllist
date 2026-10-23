import QtQml

QtObject {
    property string path: ""
    property bool connected: false
    property SplitParser parser: null
    property var writes: []
    signal connectionStateChanged()
    signal error(int error)
    onConnectedChanged: connectionStateChanged()
    function write(data) { writes = writes.concat([data]); }
    function flush() {}
    function deliver(line) { parser.read(line); }
}
