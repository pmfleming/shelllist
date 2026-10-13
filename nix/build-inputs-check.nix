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
  report = {
    inherit system;
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
  report.nixpkgs == policy.nixpkgs.rev
  && toolchain.expected == policy.rust
  && builtins.elem system policy.systems
) "Shelllist evaluated build inputs differ from the approved product policy";
pkgs.runCommand "shelllist-build-inputs-${system}"
  {
    nativeBuildInputs = [ pkgs.python3 ];
  }
  ''
    python3 ${../tools/check-build-inputs.py} \
      --policy ${../contracts/build-inputs.json} --sources ${sourceMap}
    mkdir -p $out
    printf '%s\n' '${builtins.toJSON report}' > $out/build-inputs.json
    cp ${sourceMap} $out/sources.json
    cp -R ${toolchain.check} $out/toolchain
  ''
