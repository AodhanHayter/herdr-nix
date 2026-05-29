{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, binName ? "herdr"
}:

let
  version = "0.6.5";

  platformMap = {
    "aarch64-darwin" = "macos-aarch64";
    "x86_64-darwin" = "macos-x86_64";
    "x86_64-linux" = "linux-x86_64";
    "aarch64-linux" = "linux-aarch64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "herdr is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "macos-aarch64" = "1np8cy6awycdf2f69p2fg3zhyb6ijsz97jgb437n45y1q5yccf09";
    "macos-x86_64" = "0i4l62kl5dmslsv82kfpsqqsdab5ffd9anbp467vw7wv15fahkhp";
    "linux-x86_64" = "1gz2c13pgacm59adzdn6v1a7y3dg5xb0fv3bl80pjsf04pj4rvvh";
    "linux-aarch64" = "0sc6gp6rmss5374vx1fd5nrhvaycx5ax68raiwhmdrjs6dxy5mbq";
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
