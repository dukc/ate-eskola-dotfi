# Tämä viritelmä epäonnistui eikä toimi.
# Se on mukana vain siltä varalta että joskus
# haluan vielä työstää tätä.

# Jollet ole minä, täälä ei ole nähtävää :D

{pkgs}: let
  gemset = pkgs.bundlerEnv
  { name = "jekyll-bundle";
    gemdir = ./jekyll/koodipaja;
  };
in pkgs.stdenv.mkDerivation
{ name = "ate-eskola-dotfi-frontend";
  # nativeBuildInputs = [ gemset (pkgs.lowPrio gemset.wrappedRuby) ];
  nativeBuildInputs = [ pkgs.jekyll pkgs.bundler ];

  src = ./jekyll/koodipaja;
  rootSource = ./data/juuri;

  buildPhase = ''
    bundle exec jekyll build
  '';

  installPhase = ''
    mkdir $out
    cp $rootSource $out/juuri
    cp _site $out/koodipaja
  '';
}
