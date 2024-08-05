# Ate Eskolan ja koodipajansa kotisivut

Tämä palvelin toteuttaa verkkosivut https://ate-eskola.fi ja https://koodipaja.ate-eskola.fi. Tosin vain yrityksen sivuilla on "kunnon sisältöä", henkilökohtaisessa verkko-osoiteessa on pelkästään varausilmoitus ja linkki yrityksen sivuille. Toki voi olla että joku päivä sinne jotain muutakin lisään.

Palvelinsovellus itse toimii kahtena eri tiedostopalvelimena palvelupyyntöjen verkkotunnuksen perusteella (`koodipaja.` vai ei). Siinä ei tällä hetkellä ole sen hienostuneempaa logiikkaa. Huomaa että tämä on epätaloudellinen ratkaisu. Pääsisin todennäköisesti huomattavasti halvemmalla ja vähemmällä työmäärällä jos hankkiutuisin palvelinsovelluksesta eroon ja veisin tiedostot sen sijaan johonkin verkkohotelliin. Toisaalta tällä tavalla minulla on mahdollisuus tulevaisuudessa lisätä palvelimelle jotakin erikoislogiikkaa (esimerkiksi päivitysten hakemista muilta sivuilta) ilman että joudun vaihtamaan pilvipalvelua sitä varten.

Sisältö yrityksen sivuille on tuotettu Jekyllillä. Tehdessä muutoksia siihen, Jekyll-generaattori ajetaan (`bundle exec jekyll build` `./jekyll/koodipaja`- kansiossa), ja `_site` - kansion sisältö kopioidaan `/data/koodipaja` - kansioon.

Palvelinsovelluksen koostamiseksi `dub build` (Vaatii [D-kääntäjän](https://dlang.org) ja D:n pakettienhallinta [DUBin](https://code.dlang.org) joka tulee normaalisti kääntäjän mukana), ajamiseksi testiä varten (Linuxissa - en ole testannut muilla käyttöjärjestelmillä. Toimiikohan edes...) `ate-eskola.fi --addr=127.0.0.1:8080`. Joudut muuttamaan käyttöjärjestelmän tai selaimen nimipalveluasetuksia (DNS) niin että kun menet ate-eskola.fi:8080 - osoitteeseen se ohjaa sen omalle koneellesi eikä Internet-osoitteeseen kuten normaalisti. Firefoxissa tämä onnistuu kirjoittamalla osoitepalkkiin `about:config` ja muuttamalla `dns.network.localDomains` testin ajaksi arvoon `koodipaja.ate-eskola.fi, ate-eskola.fi`.

## Pilveen vienti

Sovelluksen voi varmasti viedä pilveen (tai laittaa palvelemaan Internettiä suoraan koneelta) monella tavalla, mutta kuvailen tässä miten itse sen teen.

Teen sovelluksesta [Docker-kontin](https://www.docker.com/). Sitä varten käytän [Nix-pakettienhallintaa](https://nixos.org), ja komennan projektin juurihakemistossa `nix-build --arg pkgs "import <nixpkgs> {}" container.nix`.

Pilvessä ([Virtuozzo-alusta](https://www.virtuozzo.com/application-platform/)) teen aluksi uuden tyhjän Docker CE-solmun. Lataan koostamani kontin siihen tietokoneeltani - ei erillistä pilvivarastoa kontille - ja kirjaudun SSH:lla solmuun. Lataan Dockeriin solmuun ladatun konttikuvan (`docker load --input tiedosto`), lisään sille viitteen `docker tag` - komennolla ja ajan sen `docker run --detach --restart unless-stopped -p 80:80 ate-eskola.fi:viite`.

Huomaa että kontti käsittelee salaamattomia HTTP - pyyntöjä. Kuormantasauspalvelimen täytyy toteuttaa SSL-salaus. Tosin tähänkin harkitsen muutosta, koska pääsisin halvemmalla ellei tarvitsisi maksaa kuormantasauspalvelimesta vain sertifikaatin takia.

## Lisenssi

Kaikki koodi ja muu sisältö tässä projektissa on käytettävissä MIT-lisenssillä.

Voit siis vapaasti muuntaa tämän esimerkiksi omaksi kotisivuksesi! Muista vain mainita tämä projekti lähteenä jossakin.