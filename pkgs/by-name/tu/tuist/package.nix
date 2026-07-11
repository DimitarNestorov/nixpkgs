{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
  nix-update-script,
  versionCheckHook,
  runCommandCC,
  git,
  xcbuild,
  darwin,
  pkgs,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "tuist";
  version = "4.202.1";

  src = fetchurl {
    url = "https://github.com/tuist/tuist/releases/download/${finalAttrs.version}/tuist.zip";
    hash = "sha256-J/xlwRRW3zLr03jA6Xpa5frlRQGHa/nmzzlj35/30tw=";
  };

  dontUnpack = true;
  dontPatch = true;
  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/tuist/
    unzip $src -d $out/opt/tuist/

    mkdir -p $out/bin/
    ln -s $out/opt/tuist/tuist $out/bin/tuist

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = "version";
  versionCheckKeepEnvironment = [
    "HOME"
    "XDG_CACHE_HOME"
    "XDG_CONFIG_HOME"
    "XDG_STATE_HOME"
  ];
  preVersionCheck = ''
    export HOME=$(mktemp -d)
    export XDG_CACHE_HOME=$HOME/.cache
    export XDG_CONFIG_HOME=$HOME/.config
    export XDG_STATE_HOME=$HOME/.local/state
  '';

  passthru = {
    updateScript = nix-update-script { extraArgs = [ "--version-regex=^([0-9.]+)$" ]; };

    tests = {
      # FIXME: Test cannot run in sandbox because Tuist is executing /usr/bin/xcrun as absolute path
      # FIXME: Test requires unfree Xcode because apple-sdk in Nixpkgs doesn't have Swift in it and the mock-developer-dir uses Swift 5

      generate-basic-project =
        # FIXME: Tuist requires Swift 6
        let
          mockDeveloperDir = pkgs.runCommand "mock-developer-dir" { } ''
            mkdir -p $out/usr/bin
            mkdir -p $out/Toolchains/XcodeDefault.xctoolchain/usr
            mkdir -p $out/Platforms

            ln -s ${pkgs.xcbuild.xcrun}/bin/xcrun $out/usr/bin/xcrun

            cp ${pkgs.apple-sdk}/Toolchains/XcodeDefault.xctoolchain/ToolchainInfo.plist $out/Toolchains/XcodeDefault.xctoolchain

            ln -s ${pkgs.swiftPackages.swift-unwrapped}/bin $out/Toolchains/XcodeDefault.xctoolchain/usr/bin
            ln -s ${pkgs.swiftPackages.swift-unwrapped}/lib $out/Toolchains/XcodeDefault.xctoolchain/usr/lib
            ln -s ${pkgs.swiftPackages.swift-unwrapped}/include $out/Toolchains/XcodeDefault.xctoolchain/usr/include

            ln -s ${pkgs.apple-sdk}/Platforms/MacOSX.platform $out/Platforms/MacOSX.platform
          '';
        in
        runCommandCC "tuist-generate-basic-project-test"
          {
            nativeBuildInputs = [
              finalAttrs.finalPackage
              git
              xcbuild
            ];
          }
          ''
            export HOME=$(mktemp -d)
            export XDG_CACHE_HOME=$HOME/.cache
            export XDG_CONFIG_HOME=$HOME/.config
            export XDG_STATE_HOME=$HOME/.local/state
            export DEVELOPER_DIR=${mockDeveloperDir}
            export DEVELOPER_DIR=${darwin.xcode_26_3_Apple_silicon}/Contents/Developer

            /usr/bin/xcrun swift --version

            ls -1a

            mkdir TuistTest
            printf "import ProjectDescription\nlet project = Project(name: \\\"Test\\\", targets: [])" > TuistTest/Project.swift
            cd TuistTest
            git init
            tuist generate --no-open > stdout

            cat stdout

            grep -q "Project generated" stdout

            ls -1a

            touch $out
          '';
    };
  };

  meta = {
    description = "Command line tool that helps you generate, maintain and interact with Xcode projects";
    homepage = "https://tuist.dev";
    changelog = "https://github.com/tuist/tuist/blob/${finalAttrs.version}/cli/CHANGELOG.md";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = [ lib.maintainers.DimitarNestorov ];
    platforms = lib.platforms.darwin;
    mainProgram = "tuist";
  };
})
