{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  numpy,
  pytest-repeat,
  pytestCheckHook,
  setuptools,
  stdenv,
}:

buildPythonPackage rec {
  pname = "stringzilla";
  version = "4.6.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ashvardanian";
    repo = "stringzilla";
    tag = "v${version}";
    hash = "sha256-5WAD5ZpzhdIDv1kUVinc5z91N/tQVScO75kOPC1WWlY=";
  };

  build-system = [
    setuptools
  ];

  # The upstream setup.py uses platform.machine() to detect the target
  # architecture, which returns the *build* host arch when cross-compiling.
  # Upstream supports these environment variable overrides to set the correct
  # SIMD target flags.
  env = {
    SZ_IS_64BIT_X86_ = if stdenv.hostPlatform.isx86_64 then "1" else "0";
    SZ_IS_64BIT_ARM_ = if stdenv.hostPlatform.isAarch64 then "1" else "0";
  };

  pythonImportsCheck = [ "stringzilla" ];

  nativeCheckInputs = [
    numpy
    pytest-repeat
    pytestCheckHook
  ];

  enabledTestPaths = [ "scripts/test_stringzilla.py" ];

  disabledTests = [
    # test downloads CaseFolding.txt from unicode.org
    "test_utf8_case_fold_all_codepoints"
  ];

  meta = {
    changelog = "https://github.com/ashvardanian/StringZilla/releases/tag/${src.tag}";
    description = "SIMD-accelerated string search, sort, hashes, fingerprints, & edit distances";
    homepage = "https://github.com/ashvardanian/stringzilla";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      aciceri
      dotlambda
    ];
  };
}
