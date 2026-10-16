{ kdePackages, dbus, python3, pkg-config, makeFontsConf, dejavu_fonts, nmDaemon }:

# Keep the scanner UI; delegate connection/credential policy to nm-daemon.
# Patches are maintained against Qrca 26.04.3.
kdePackages.qrca.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [
    ./qrca/remember-network.patch
    ./qrca/native-credentials.patch
    ./qrca/scanner-contrast.patch
  ];
  postPatch = (old.postPatch or "") + ''
    cp ${./qrca/ScannerButton.qml} src/qml/ScannerButton.qml
    cp ${./qrca/NmWifiConnection.h} src/NmWifiConnection.h
  '';
  qtWrapperArgs = (old.qtWrapperArgs or [ ]) ++ [ "--prefix" "PATH" ":" "${nmDaemon}/bin" ];
  doInstallCheck = true;
  nativeInstallCheckInputs = (old.nativeInstallCheckInputs or [ ]) ++ [ dbus python3 pkg-config ];
  postInstallCheck = (old.postInstallCheck or "") + ''
    python3 ${../tests/check-qrca-credentials.py} ${./qrca/NmWifiConnection.h}
    FONTCONFIG_FILE=${makeFontsConf { fontDirectories = [ dejavu_fonts ]; }} python3 ${../tests/check-qrca-startup.py} --isolated "$out/bin/qrca"
  '';
})
