{ kdePackages, dbus, python3, makeFontsConf, dejavu_fonts }:

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
  doInstallCheck = true;
  nativeInstallCheckInputs = (old.nativeInstallCheckInputs or [ ]) ++ [ dbus python3 ];
  postInstallCheck = (old.postInstallCheck or "") + ''
    FONTCONFIG_FILE=${makeFontsConf { fontDirectories = [ dejavu_fonts ]; }} python3 ${../tests/check-qrca-startup.py} --isolated "$out/bin/qrca"
  '';
})
