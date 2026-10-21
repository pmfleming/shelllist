pragma Singleton
import QtQuick
import "IpEdit.js" as IpEdit

// Domain adapters consume the same complete-value parser as the shared field.
// Neither this codec nor the editor owns backend readiness or acknowledgement.
QtObject {
    function inspect(value: string, family: string, mode: string, subnetNotation: string, allowEmpty: bool): var {
        return IpEdit.inspect(value, {family: family, mode: mode, subnetNotation: subnetNotation, allowEmpty: allowEmpty});
    }
}
