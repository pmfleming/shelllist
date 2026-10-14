{ kdePackages }:

# Keep Qrca's scanner/connection workflow; patch only the explicit remember
# policy and presentation. Patches are maintained against Qrca 26.04.3.
kdePackages.qrca.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./qrca/remember-network.patch
    ./qrca/scanner-contrast.patch
  ];
  postPatch = (old.postPatch or "") + ''
    cp ${./qrca/ScannerButton.qml} src/qml/ScannerButton.qml
  '';
})
