{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, binName ? "herdr"
}:

let
  version = "0.7.1";

  platformMap = {
    "aarch64-darwin" = "macos-aarch64";
    "x86_64-darwin" = "macos-x86_64";
    "x86_64-linux" = "linux-x86_64";
    "aarch64-linux" = "linux-aarch64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "herdr is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "macos-aarch64" = "1y2dcfxyawh5j3igkaldx211p3pi88jv1da65dyixsli0hznbx0n";
    "macos-x86_64" = "0ih814ak0rl9ryv20zv60ax6qgq1c5mbh81dwmwqv9xrvc3zm02p";
    "linux-x86_64" = "0m56v2ws8rwwb6h309k2q953z2p9z1yayr3cdr5za8iczjpsqrdr";
    "linux-aarch64" = "0v2py4kjrpdf2psa1zwwkyl17zi3ck63x3038pf7j7k31k1plx9x";
  };

  nativeBinary = fetchurl {
    url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/herdr-${platform}";
    sha256 = nativeHashes.${platform};
  };
in
stdenv.mkDerivation {
  pname = "herdr";
  inherit version;

  dontUnpack = true;

  nativeBuildInputs = [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isElf [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    install -m755 ${nativeBinary} $out/bin/.herdr-unwrapped

    makeBinaryWrapper $out/bin/.herdr-unwrapped $out/bin/${binName}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    license = licenses.agpl3Only;
    platforms = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    mainProgram = binName;
  };
}
