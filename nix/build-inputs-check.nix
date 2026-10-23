{
  inputs,
  pkgs,
  system,
}:
let
  policy = builtins.fromJSON (builtins.readFile ../contracts/build-inputs.json);
  sources = {
    shelllist = inputs.self.outPath;
    daemon-framework = inputs.daemon-framework.outPath;
    app-daemon = inputs.app-daemon.outPath;
    bar-daemon = inputs.bar-daemon.outPath;
    bt-daemon = inputs.bt-daemon.outPath;
    clip-daemon = inputs.clip-daemon.outPath;
    nm-daemon = inputs.nm-daemon.outPath;
    update-daemon = inputs.update-worker.outPath;
  };
  sourceMap = pkgs.writeText "shelllist-build-sources.json" (builtins.toJSON sources);
  toolchain = inputs.daemon-framework.lib.toolchain pkgs;
  productFlakes = [
    inputs.self
    inputs.daemon-framework
    inputs.app-daemon
    inputs.bar-daemon
    inputs.bt-daemon
    inputs.clip-daemon
    inputs.nm-daemon
  ];
  platformOutputsMatch = builtins.all (
    flake:
    builtins.all (output: builtins.attrNames flake.${output} == policy.systems) [
      "packages"
      "checks"
      "apps"
      "devShells"
    ]
  ) productFlakes;
  ownedPackages = (map (flake: flake.packages.${system}.default) productFlakes) ++ [
    inputs.self.packages.${system}.shelllistSearch
    inputs.self.packages.${system}.shelllistTimezoneAssets
    inputs.self.packages.${system}.portalLauncher
    inputs.self.packages.${system}.shelllistConfig
    inputs.self.checks.${system}.updateWorkerPackage
  ];
  # These are scope/guard tests, not ARM builds. Host-supplied worker packages
  # must reject unsupported targets too, without importing privileged runtime.
  unsupportedPlatformsRejected =
    builtins.all
      (
        unsupported:
        let
          unsupportedPkgs = pkgs // {
            stdenv = pkgs.stdenv // {
              hostPlatform = pkgs.stdenv.hostPlatform // {
                system = unsupported;
              };
            };
          };
        in
        !(builtins.tryEval (inputs.daemon-framework.lib.toolchain unsupportedPkgs)).success
        && !(builtins.tryEval (
          inputs.update-worker.lib.mkPackage {
            pkgs = unsupportedPkgs;
            hostName = "unsupported-platform-test";
            username = "nobody";
            manualInputs = [ ];
            localBuildHelper = "/unused";
            piExtensions = pkgs.emptyDirectory;
            fallbacks = { };
          }
        )).success
      )
      [
        "aarch64-linux"
        "i686-linux"
        "x86_64-darwin"
      ];
  report = {
    inherit system;
    supportedSystems = policy.systems;
    primaryHardware = "Modern Intel/AMD x86-64 PCs; portable binaries, no host-native tuning";
    nixpkgs = inputs.nixpkgs.rev;
    nix = pkgs.nix.version;
    compiler = toolchain.actual;
    compilerPath = toString pkgs.rustc;
    cargoPath = toString pkgs.cargo;
    native = {
      pipewire = pkgs.pipewire.version;
      systemd = pkgs.systemd.version;
      dbus = pkgs.dbus.version;
      libclang = pkgs.llvmPackages.libclang.version;
      wayland = pkgs.wayland.version;
      cc = pkgs.stdenv.cc.version;
    };
  };
in
# Exercise the fail-closed Nix guard independently of rustup declarations.
assert
  !(builtins.tryEval (
    inputs.daemon-framework.lib.toolchain (
      pkgs
      // {
        rustc = pkgs.rustc // {
          version = "0.0.0";
        };
      }
    )
  )).success;
assert pkgs.lib.assertMsg (
  platformOutputsMatch
  && builtins.all (package: package.meta.platforms == policy.systems) ownedPackages
) "Shelllist platform outputs/package metadata differ from the supported-platform policy";
assert pkgs.lib.assertMsg unsupportedPlatformsRejected
  "Shelllist must reject unsupported host platforms";
assert pkgs.lib.assertMsg (
  report.nixpkgs == policy.nixpkgs.rev
  && toolchain.expected == policy.rust
  && builtins.elem system policy.systems
) "Shelllist evaluated build inputs differ from the approved product policy";
pkgs.runCommand "shelllist-build-inputs-${system}"
  { }
  ''
    ${inputs.self.packages.${system}.xtask}/bin/shelllist-xtask --root ${../.} build-inputs \
      --policy ${../contracts/build-inputs.json} --sources ${sourceMap}
    mkdir -p $out
    printf '%s\n' '${builtins.toJSON report}' > $out/build-inputs.json
    cp ${sourceMap} $out/sources.json
    cp -R ${toolchain.check} $out/toolchain
  ''
