{
  lib,
  stdenv,
  fetchFromGitHub,
  callPackage,
  zig_0_15,
  gettext,
  libuv,
  lua,
  pkg-config,
  unibilium,
  utf8proc,
  tree-sitter,
  buildPackages,
  fixDarwinDylibNames,
  glibcLocales ? null,
  procps ? null,
  versionCheckHook,
  nix-update-script,

  # now defaults to false because some tests can be flaky (clipboard etc), see
  # also: https://github.com/neovim/neovim/issues/16233
  nodejs ? null,
  fish ? null,
  python3 ? null,
}:
let
  # Use buildPackages to ensure zig is available as a build tool during cross-compilation
  zig = buildPackages.zig_0_15;
  zig_hook = zig.hook.overrideAttrs {
    zig_default_flags = "-Doptimize=ReleaseSafe --color off";
  };

  # Convert Nix target triple to Zig target triple
  # Nix uses: aarch64-unknown-linux-gnu
  # Zig uses: aarch64-linux-gnu
  zigTarget =
    if stdenv.hostPlatform == stdenv.buildPlatform then
      null
    else
      let
        cpu = stdenv.hostPlatform.parsed.cpu.name;
        os = stdenv.hostPlatform.parsed.kernel.name;
        abi = if stdenv.hostPlatform.parsed.abi.name == "unknown" then "gnu" else stdenv.hostPlatform.parsed.abi.name;
      in
      "${cpu}-${os}-${abi}";

  # When cross-compiling, we need to provide native (build platform) LuaJIT
  # for build-time tools like nlua0, buildvm, etc.
  nativeLua = if stdenv.hostPlatform != stdenv.buildPlatform then buildPackages.luajit else null;
in
stdenv.mkDerivation (
  finalAttrs:
  let
    nvim-lpeg-dylib =
      luapkgs:
      if stdenv.hostPlatform.isDarwin then
        let
          luaLibDir = "$out/lib/lua/${lib.versions.majorMinor luapkgs.lua.luaversion}";
        in
        (luapkgs.lpeg.overrideAttrs (oa: {
          preConfigure = ''
            # neovim wants clang .dylib
            substituteInPlace Makefile \
              --replace-fail "CC = gcc" "CC = clang" \
              --replace-fail "-bundle" "-dynamiclib" \
              --replace-fail "lpeg.so" "lpeg.dylib"
          '';
          preBuild = ''
            # there seems to be implicit calls to Makefile from luarocks, we need to
            # add a stage to build our dylib
            make macosx
            mkdir -p ${luaLibDir}
            mv lpeg.dylib ${luaLibDir}/lpeg.dylib
          '';
          postInstall = ''
            rm -f ${luaLibDir}/lpeg.so
          '';
          nativeBuildInputs =
            oa.nativeBuildInputs ++ (lib.optional stdenv.hostPlatform.isDarwin fixDarwinDylibNames);
        }))
      else
        luapkgs.lpeg;
    requiredLuaPkgs =
      ps:
      (
        with ps;
        [
          (nvim-lpeg-dylib ps)
          luabitop
          mpack
        ]
        ++ lib.optionals finalAttrs.finalPackage.doCheck [
          luv
          coxpcall
          busted
          luafilesystem
          penlight
          inspect
        ]
      );
    neovimLuaEnv = lua.withPackages requiredLuaPkgs;
    neovimLuaEnvOnBuild = lua.luaOnBuild.withPackages requiredLuaPkgs;
    codegenLua =
      if lua.luaOnBuild.pkgs.isLuaJIT then
        let
          deterministicLuajit = lua.luaOnBuild.override {
            deterministicStringIds = true;
            self = deterministicLuajit;
          };
        in
        deterministicLuajit.withPackages (ps: [
          ps.mpack
          (nvim-lpeg-dylib ps)
        ])
      else
        lua.luaOnBuild;

  in
  {
    pname = "neovim-unwrapped";
    version = "0.12.0-dev";

    __structuredAttrs = true;

    src = fetchFromGitHub {
      owner = "neovim";
      repo = "neovim";
      rev = "e62dd13f83a200105a2b8466e729c39485fa766d";
      hash = "sha256-2M2e0NGkkAtZGc9IhC9+wbcQ5xyUVKgB9oN+WUteeeI=";
    };

    patches = [
      # introduce a system-wide rplugin.vim in addition to the user one
      # necessary so that nix can handle `UpdateRemotePlugins` for the plugins
      # it installs. See https://github.com/neovim/neovim/issues/9413.
      ./system_rplugin_manifest.patch
    ];

    inherit lua;

    deps = callPackage ./deps.nix {
      zig_0_15 = buildPackages.zig_0_15;
    };

    buildInputs = [
      libuv
      # This is actually a c library, hence it's not included in neovimLuaEnv,
      # see:
      # https://github.com/luarocks/luarocks/issues/1402#issuecomment-1080616570
      # and it's definition at: pkgs/development/lua-modules/overrides.nix
      lua.pkgs.libluv
      neovimLuaEnv
      tree-sitter
      unibilium
      utf8proc
    ]
    ++ lib.optionals finalAttrs.finalPackage.doCheck [
      glibcLocales
      procps
    ];

    doCheck = false;

    # to be exhaustive, one could run
    # make oldtests too
    checkPhase = ''
      runHook preCheck
      # Tests are handled by zig.hook's zigCheckPhase if enabled
      runHook postCheck
    '';

    nativeBuildInputs = [
      zig_hook
      gettext
      pkg-config
    ];

    # extra programs test via `make functionaltest`
    nativeCheckInputs =
      let
        pyEnv = python3.withPackages (
          ps: with ps; [
            pynvim
            msgpack
          ]
        );
      in
      [
        fish
        nodejs
        pyEnv # for src/clint.py
      ];

    # check that the above patching actually works
    disallowedRequisites = [ stdenv.cc ] ++ lib.optional (lua != codegenLua) codegenLua;

    preBuild = lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
      # When cross-compiling, Zig handles both native (build tools) and target (final binary)
      # compilation. However, Nix's cross-compilation environment pollutes the build with
      # target-specific compiler flags and include paths that Zig's native builds pick up,
      # causing ARM SVE header errors.

      # Solution: Clear the Nix cross-compilation environment variables before running zig build.
      # Zig will use its own bundled libc for C code compilation, avoiding system header issues.
      unset NIX_CFLAGS_COMPILE NIX_LDFLAGS NIX_CFLAGS_COMPILE_BEFORE NIX_LDFLAGS_BEFORE
      unset NIX_HARDENING_ENABLE NIX_IGNORE_LD_THROUGH_GCC

      # Also clear CC/CXX to prevent Zig from using the cross-compilation wrappers
      unset CC CXX LD AR RANLIB STRIP OBJCOPY OBJDUMP READELF NM SIZE STRINGS
    '';

    # Zig build flags - we need to specify the 'nvim' target explicitly
    zigBuildFlags = [
      "nvim"
      "--system"
      "${finalAttrs.deps}"
    ]
    ++ lib.optional lua.pkgs.isLuaJIT "-Dluajit=true"
    ++ lib.optional (!lua.pkgs.isLuaJIT) "-Dluajit=false"
    ++ lib.optional (!stdenv.hostPlatform.isDarwin) "-Dunibilium=true"
    ++ lib.optional stdenv.hostPlatform.isDarwin "-Dunibilium=false"
    # When cross-compiling, pass -Dcross=true to tell build.zig to build
    # build-time tools (nlua0, buildvm, minilua) for the build platform
    # and the final neovim binary for the target platform
    ++ lib.optional (zigTarget != null) "-Dcross=true"
    ++ lib.optional (zigTarget != null) "-Dtarget=${zigTarget}";


    shellHook = ''
      export VIMRUNTIME=$PWD/runtime
    '';

    postInstall = ''
      # Install man page
      # The Zig build doesn't install this automatically
      mkdir -p $out/share/man/man1
      cp src/man/nvim.1 $out/share/man/man1/
    '' + lib.optionalString stdenv.hostPlatform.isLinux ''
      # Install desktop file and icon for Linux systems
      # The Zig build doesn't install these automatically
      mkdir -p $out/share/applications
      cp runtime/nvim.desktop $out/share/applications/

      mkdir -p $out/share/icons/hicolor/128x128/apps
      cp runtime/nvim.png $out/share/icons/hicolor/128x128/apps/
    '';

    separateDebugInfo = true;

    nativeInstallCheckInputs = [
      versionCheckHook
    ];
    versionCheckProgram = "${placeholder "out"}/bin/nvim";
    versionCheckProgramArg = "--version";
    doInstallCheck = true;

    passthru = {
      updateScript = nix-update-script { };
    };

    meta = {
      description = "Vim text editor fork focused on extensibility and agility";
      longDescription = ''
        Neovim is a project that seeks to aggressively refactor Vim in order to:
        - Simplify maintenance and encourage contributions
        - Split the work between multiple developers
        - Enable the implementation of new/modern user interfaces without any
          modifications to the core source
        - Improve extensibility with a new plugin architecture
      '';
      homepage = "https://neovim.io";
      changelog = "https://github.com/neovim/neovim/blob/${finalAttrs.src.rev}/CHANGELOG.md";
      mainProgram = "nvim";
      # "Contributions committed before b17d96 by authors who did not sign the
      # Contributor License Agreement (CLA) remain under the Vim license.
      # Contributions committed after b17d96 are licensed under Apache 2.0 unless
      # those contributions were copied from Vim (identified in the commit logs
      # by the vim-patch token). See LICENSE for details."
      license = with lib.licenses; [
        asl20
        vim
      ];
      teams = [ lib.teams.neovim ];
      platforms = lib.platforms.unix;
    };
  }
)
