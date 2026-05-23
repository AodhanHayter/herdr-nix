{ lib
, stdenv
, fetchurl
, makeBinaryWrapper
, autoPatchelfHook
, binName ? "herdr"
}:

let
  version = "0.6.2";

  platformMap = {
    "aarch64-darwin" = "macos-aarch64";
    "x86_64-darwin" = "macos-x86_64";
    "x86_64-linux" = "linux-x86_64";
    "aarch64-linux" = "linux-aarch64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or
    (throw "herdr is not supported on ${stdenv.hostPlatform.system}. Supported: aarch64-darwin, x86_64-darwin, x86_64-linux, aarch64-linux");

  nativeHashes = {
    "macos-aarch64" = "03h1z9mvlsscanh0fqh6px7xh2prbx61vrsi4lqqdlqywci2bwjc";
    "macos-x86_64" = "0isg2l15nphimn57r617145wvqgx0ffhg4i14aa4w8057mw3vwvk";
    "linux-x86_64" = "12807avbxwdjdc54vfpf01ac4mvvqcdyja23ab8iznx0l1w53s4y";
    "linux-aarch64" = "0nspvxjrz8p19x0613bzzl64n39ck290xgjhwwlqbqkj7m65g2h8";
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
