{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, binName ? "herdr"
}:

let
  version = "0.6.3";

  platformMap = {
    "aarch64-darwin" = "macos-aarch64";
    "x86_64-darwin" = "macos-x86_64";
    "x86_64-linux" = "linux-x86_64";
    "aarch64-linux" = "linux-aarch64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "herdr is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "macos-aarch64" = "1nnbjap71dw6yfln4ikm3dwfc7mwv12mdgld4d6hy0x0l9pbik9x";
    "macos-x86_64" = "1bafsxj85dkavd0ldcqkprdw2vm85r5clyryvkmxikaajfgjvad4";
    "linux-x86_64" = "0v1r6gn7q77mphz1x7jk66nq43mah4krf9ddn7sbvwbqxzqgbfbc";
    "linux-aarch64" = "0byxh2lgdydc4yar0yfxh02cid4q24kvqcq0fyg3y3n3j3zv4ygj";
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
