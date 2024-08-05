{ pkgs }:
with pkgs.stdenv; let
  extraStuff = mkDerivation
  { name= "initData";
    src= ./.;
    installPhase = ''
      mkdir -p $out/share/ate-eskola.fi/data
      cp -r data/. $out/share/ate-eskola.fi/data
    '';
  };
  # Jos Cloudplatform.fi ei jostain syystä katsele ilman kantakuvaa tehtyjä
  # kontteja, käytä pienintä tarjolla olevaa Linux-kantakuvaa.
  # alpine = pkgs.dockerTools.pullImage
  # {  imageName = "alpine";
  #    imageDigest = "sha256:e1c082e3d3c45cccac829840a25941e679c25d438cc8412c2fa221cf1a824e6a";
  #    sha256 = "0m0rw2md4clcd2crfbbcz958gyipwgcq47k5kkzllgwcrszp0kzi";
  #    finalImageName = "alpine";
  #    finalImageTag = "latest";
  # };
in pkgs.dockerTools.buildImage
{ name = "ate-eskola.fi";
  # fromImage = alpine;
  contents =
  [ (import ./default.nix {inherit pkgs; buildType = "release"; })
    extraStuff
  ];
  config = {
    Cmd = [ "/bin/ate-eskola.fi" ];
    WorkingDir = "/share/ate-eskola.fi";
  };
}
