{
  lib,
  stdenv,
  fetchFromGitHub,
  replaceVars,
  python3Packages,
  libunistring,
  harfbuzz,
  fontconfig,
  pkg-config,
  ncurses,
  imagemagick,
  libstartup_notification,
  libGL,
  libx11,
  libxrandr,
  libxinerama,
  libxcursor,
  libxkbcommon,
  libxi,
  libxext,
  wayland-protocols,
  wayland,
  xxhash,
  nerd-fonts,
  lcms2,
  librsync,
  openssl,
  installShellFiles,
  dbus,
  sudo,
  libcanberra,
  libicns,
  wayland-scanner,
  libpng,
  python3,
  zlib,
  simde,
  bashInteractive,
  zsh,
  fish,
  nixosTests,
  go_1_26,
  buildGo126Module,
  nix-update-script,
  makeBinaryWrapper,
  darwin,
  cairo,
  fetchpatch,
  buildPackages,
}:

with python3Packages;
buildPythonApplication rec {
  pname = "kitty";
  version = "0.48.1";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "kovidgoyal";
    repo = "kitty";
    tag = "v${version}";
    hash = "sha256-h4dE99FET26iTgEFrmeXcFDw6DLl8dQjGep0NJ7jMzk=";
  };

  goModules =
    (buildGo126Module {
      pname = "kitty-go-modules";
      inherit src version;
      vendorHash = "sha256-nxPca7xDgxQd8vXbGKGuKXmB5vu0d3me//m8AULJZ6o=";
    }).goModules;

  buildInputs = [
    harfbuzz
    ncurses
    simde
    lcms2
    librsync
    matplotlib
    openssl.dev
    xxhash
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    libpng
    python3
    zlib
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    fontconfig
    libunistring
    libcanberra
    libx11
    libxrandr
    libxinerama
    libxcursor
    libxkbcommon
    libxi
    libxext
    wayland-protocols
    wayland
    dbus
    libGL
    cairo
  ];

  nativeBuildInputs = [
    installShellFiles
    ncurses
    pkg-config
    sphinx
    furo
    sphinx-copybutton
    sphinxext-opengraph
    sphinx-inline-tabs
    go_1_26
    fontconfig
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    imagemagick
    libicns # For the png2icns tool.
    darwin.autoSignDarwinBinariesHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wayland-scanner
  ];

  depsBuildBuild = [ pkg-config ];

  outputs = [
    "out"
    "terminfo"
    "shell_integration"
    "kitten"
  ];

  patches = [
    # Needed on darwin

    # Gets `test_ssh_shell_integration` to pass for `zsh` when `compinit` complains about
    # permissions.
    ./zsh-compinit.patch

    # Skip `test_ssh_bootstrap_with_different_launchers` when launcher is `zsh` since it causes:
    # OSError: master_fd is in error condition
    ./disable-test_ssh_bootstrap_with_different_launchers.patch

    (replaceVars ./libxkbcommon-runtime-path.patch {
      libxkbcommon = "${lib.getLib libxkbcommon}/lib/libxkbcommon.so.0";
    })
  ];

  hardeningDisable = [
    # causes redefinition of _FORTIFY_SOURCE
    "fortify3"
  ];

  env = {
    CGO_ENABLED = 0;
    GOFLAGS = "-trimpath";
    GOTOOLCHAIN = "local";
  }
  // lib.optionalAttrs (stdenv.hostPlatform != stdenv.buildPlatform) {
    PKGCONFIG_EXE = "${stdenv.hostPlatform.config}-pkg-config";
  };

  postPatch =
    lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform && stdenv.hostPlatform.isLinux)
      ''
        # When cross-compiling, glfw/glfw.py resolves the wayland-scanner binary
        # via pkg-config which finds the target-arch (non-executable) one.
        # Hardcode the native binary path directly so it doesn't need pkg-config.
        substituteInPlace glfw/glfw.py \
          --replace-fail \
            "os.path.abspath(pkg_config('wayland-scanner', '--variable=wayland_scanner')[0])" \
            "'${buildPackages.wayland-scanner}/bin/wayland-scanner'"

        # update_go_generated_files runs the just-built (target-arch) kitty binary
        # via "kitty +launch gen/go_code.py" to regenerate Go source/data files.
        # When cross-compiling that binary can't execute on the build host.
        # Patch setup.py to use the native kitty from buildPackages instead.
        substituteInPlace setup.py \
          --replace-fail \
            "cp = subprocess.run([kitty_exe, '+launch', os.path.join(src_base, 'gen/go_code.py')], stdout=subprocess.DEVNULL, env=env)" \
            "cp = subprocess.run(['${buildPackages.kitty}/bin/kitty', '+launch', os.path.join(src_base, 'gen/go_code.py')], stdout=subprocess.DEVNULL, env=env)"

        # gen/go_code.py spawns "go run generate.go" (start_simdgen) to produce SIMD
        # assembly.  That sub-process inherits the cross CC from the build environment
        # and tries to link an x86_64 binary with the aarch64 cross-compiler, which
        # fails.  Force CGO_ENABLED=0 and clear CC/CXX so the Go host toolchain is
        # used without CGO for that step.
        sed -i 's|cwd=.tools/simdstring., stdout=subprocess.PIPE, stderr=subprocess.PIPE)|cwd="tools/simdstring", stdout=subprocess.PIPE, stderr=subprocess.PIPE, env={**os.environ, "CGO_ENABLED": "0", "CC": "", "CXX": ""})|' gen/go_code.py

        # build_static_kittens calls run_one which builds the kitten binary using Go.
        # Without for_platform set, it targets the host arch (x86_64) with whatever
        # CC is in the environment (the aarch64 cross-compiler), causing a link
        # failure.  Patch run_one to cross-compile for the target platform instead,
        # using CGO_ENABLED=0 and the correct GOOS/GOARCH, with CC cleared so the
        # Go internal linker is used.
        substituteInPlace setup.py \
          --replace-fail \
            "e.pop('PWD', None)" \
            "e.pop('PWD', None); e['CGO_ENABLED'] = '0'; e['GOOS'] = 'linux'; e['GOARCH'] = '${stdenv.hostPlatform.go.GOARCH}'; e.pop('CC', None); e.pop('CXX', None)"

        # setup.py linux-package tries to run "make docs" (which imports the aarch64
        # kitty C extension) if docs/_build/html doesn't exist.  Pre-create the
        # directory so it skips that step when cross-compiling.
        mkdir -p docs/_build/html docs/_build/man
      '';

  configurePhase = ''
    export GOCACHE=$TMPDIR/go-cache
    export GOPATH="$TMPDIR/go"
    export GOPROXY=off
    cp -r --reflink=auto $goModules vendor
  '';

  buildPhase =
    let
      commonOptions = "--update-check-interval=0 " + "--shell-integration='enabled no-rc' ";
      darwinOptions = ''
        --disable-link-time-optimization \
        ${commonOptions}
      '';
    in
    ''
      runHook preBuild

      # Add the font by hand because fontconfig does not finds it in darwin
      mkdir ./fonts/
      cp "${nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFontMono-Regular.ttf" ./fonts/

      ${
        if stdenv.hostPlatform.isDarwin then
          ''
            ${python.pythonOnBuildForHost.interpreter} setup.py build ${darwinOptions}
            make docs
            ${python.pythonOnBuildForHost.interpreter} setup.py kitty.app ${darwinOptions}
          ''
        else
          ''
            ${python.pythonOnBuildForHost.interpreter} setup.py linux-package \
            --egl-library='${lib.getLib libGL}/lib/libEGL.so.1' \
            --startup-notification-library='${libstartup_notification}/lib/libstartup-notification-1.so' \
            --canberra-library='${libcanberra}/lib/libcanberra.so' \
            --fontconfig-library='${fontconfig.lib}/lib/libfontconfig.so' \
            ${commonOptions}
            ${python.pythonOnBuildForHost.interpreter} setup.py build-launcher
          ''
      }
      runHook postBuild
    '';

  nativeCheckInputs = [
    pillow

    # Shells needed for shell integration tests
    bashInteractive
    zsh
    fish
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    # integration tests need sudo
    sudo
  ];

  # skip failing tests due to darwin sandbox
  preCheck =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      substituteInPlace kitty_tests/check_build.py \
        --replace test_macos_dictation_forwarding no_test_macos_dictation_forwarding

      substituteInPlace kitty_tests/file_transmission.py \
        --replace test_transfer_send dont_test_transfer_send

      substituteInPlace kitty_tests/ssh.py \
        --replace test_ssh_connection_data no_test_ssh_connection_data \
        --replace test_ssh_shell_integration no_test_ssh_shell_integration \
        --replace test_ssh_copy no_test_ssh_copy \
        --replace test_ssh_env_vars no_test_ssh_env_vars

      substituteInPlace kitty_tests/shell_integration.py \
        --replace test_fish_integration no_test_fish_integration \
        --replace test_zsh_integration no_test_zsh_integration

      substituteInPlace kitty_tests/fonts.py \
        --replace test_fallback_font_not_last_resort no_test_fallback_font_not_last_resort

      # theme collection test starts an http server
      rm tools/themes/collection_test.go
      # passwd_test tries to exec /usr/bin/dscl
      rm tools/utils/passwd_test.go
    ''
    + ''
      # These depend on files that are not available in the sandbox
      rm tools/utils/machine_id/api_test.go
    '';

  checkPhase = ''
    runHook preCheck

    # Fontconfig error: Cannot load default config file: No such file: (null)
    export FONTCONFIG_FILE=${fontconfig.out}/etc/fonts/fonts.conf
    # Required for `test_ssh_shell_integration` to pass.
    export TERM=kitty

    make test
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    mkdir -p "$kitten/bin"
    ${
      if stdenv.hostPlatform.isDarwin then
        ''
          mkdir "$out/bin"
          ln -s ../Applications/kitty.app/Contents/MacOS/kitty "$out/bin/kitty"
          ln -s ../Applications/kitty.app/Contents/MacOS/kitten "$out/bin/kitten"
          cp ./kitty.app/Contents/MacOS/kitten "$kitten/bin/kitten"
          mkdir "$out/Applications"
          cp -r kitty.app "$out/Applications/kitty.app"

          installManPage 'docs/_build/man/kitty.1'
        ''
      else
        ''
          cp -r linux-package/{bin,share,lib} "$out"
          cp linux-package/bin/kitten "$kitten/bin/kitten"
        ''
    }

    # dereference the `kitty` symlink to make sure the actual executable
    # is wrapped on macOS as well (and not just the symlink)
    wrapProgram $(realpath "$out/bin/kitty") --suffix PATH : "$out/bin:${
      lib.makeBinPath [
        imagemagick
        ncurses.dev
      ]
    }"

    ${lib.optionalString (stdenv.hostPlatform == stdenv.buildPlatform) ''
      installShellCompletion --cmd kitty \
        --bash <("$out/bin/kitty" +complete setup bash) \
        --fish <("$out/bin/kitty" +complete setup fish2) \
        --zsh  <("$out/bin/kitty" +complete setup zsh)
    ''}

    terminfo_src=${
      if stdenv.hostPlatform.isDarwin then
        ''"$out/Applications/kitty.app/Contents/Resources/terminfo"''
      else
        "$out/share/terminfo"
    }

    mkdir -p $terminfo/share
    mv "$terminfo_src" $terminfo/share/terminfo

    mkdir -p "$out/nix-support"
    echo "$terminfo" >> $out/nix-support/propagated-user-env-packages

    cp -r 'shell-integration' "$shell_integration"

    runHook postInstall
  '';

  passthru = {
    tests = lib.optionalAttrs stdenv.hostPlatform.isLinux {
      default = nixosTests.terminal-emulators.kitty;
    };
    updateScript = nix-update-script { };
  };

  meta = {
    homepage = "https://github.com/kovidgoyal/kitty";
    description = "Fast, feature-rich, GPU based terminal emulator";
    license = lib.licenses.gpl3Only;
    changelog = [
      "https://sw.kovidgoyal.net/kitty/changelog/"
      "https://github.com/kovidgoyal/kitty/blob/v${version}/docs/changelog.rst"
    ];
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    mainProgram = "kitty";
    maintainers = with lib.maintainers; [
      rvolosatovs
      Luflosi
      kashw2
      leiserfg
    ];
  };
}
