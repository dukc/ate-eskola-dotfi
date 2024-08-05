
{pkgs, buildType ? "debug"}: let
    dlang-nix = (import (pkgs.fetchFromGitHub {
        owner = "petarkirov";
        repo = "dlang-nix";
        rev = "44dd385";
        sha256 = "sha256-llfWaP4/NurUtDnY+/ex28McJOV0/rxXio6MyKl6C7s=";
    })).packages."${pkgs.system}";
    mkDub = import "${pkgs.fetchFromGitHub {
        owner = "lionello";
        repo = "dub2nix";
        rev = "0.4.1";
        sha256 = "sha256-/J70yjg1cvMk9oI20O0d2KQlrlRlG34k95Snp+zCCqI=";
    }}/mkDub.nix" { inherit pkgs; dmd = dlang-nix.dmd-2_105_2; };
in mkDub.mkDubDerivation {
    src = ./.;
    buildInputs = [ pkgs.openssl ];
    inherit buildType;
}
