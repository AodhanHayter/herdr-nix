{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, binName ? "herdr"
}:

let
  version = "0.6.4";

  platformMap = {
    "aarch64-darwin" = "macos-aarch64";
    "x86_64-darwin" = "macos-x86_64";
    "x86_64-linux" = "linux-x86_64";
    "aarch64-linux" = "linux-aarch64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "herdr is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "macos-aarch64" = "1nfvvnzqpwzhqshvjq3wsl7ffafmyl39mf4mn228bzksa084ivmx";
    "macos-x86_64" = "0m015dbv9yzfcwvzjrq3wnj91xszl966fi31rdfcc6baigiivxi4";
    "linux-x86_64" = "12z3nnn8g91dnxgk5wnfgjsdn6h9z46gp2m5i8pzzp0w9f7qd5vs";
    "linux-aarch64" = "0d25m56i7zgd4c9ygs3pr7x9ys4m46fblli94r32x7i56y7w0nhf";
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
