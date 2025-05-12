# Ate Eskolan ja koodipajansa kotisivut

Tämä palvelin toteuttaa verkkosivut https://ate-eskola.fi ja https://koodipaja.ate-eskola.fi. Tosin vain yrityksen sivuilla on "kunnon sisältöä", henkilökohtaisessa verkko-osoiteessa on pelkästään varausilmoitus ja linkki yrityksen sivuille. Toki voi olla että joku päivä sinne jotain muutakin lisään.

Palvelinsovellus itse toimii kahtena eri tiedostopalvelimena palvelupyyntöjen verkkotunnuksen perusteella (`koodipaja.` vai ei). Se myös yrittää muodostaa yhteyden tietokantaan ja jos saa sen muodostettua, pitää vieraskirjaa kävijöitä varten.

Sisältö yrityksen sivuille on tuotettu Jekyllillä. Tehdessä muutoksia siihen, Jekyll-generaattori ajetaan (`bundle exec jekyll build` `./jekyll/koodipaja`- kansiossa), ja `_site` - kansion sisältö kopioidaan `/data/koodipaja` - kansioon. Ensimmäisellä kerralla `.jekyll/koodipaja`ssa pitää ajaa ensin `bundle install --gemfile Gemfile --path vendor/cache` Jekyllin käyttämien kirjastojen lataamiseksi.

Ensin sovellukseen asetukset pitää säätää kohdalleen. `exampleconfig.d` sisältää vakioasetukset, joten ensiksi se kopioidaan src-kansioon ja uudelleennimeätään `config.d`:ksi. Sitten asetukset muutetaan. Käytännössä ainakin "database"-arvo vaatii säätämistä jos käytetään ulkoista tietokantaa. Myös `configVer`-muuttuja pitää muuttaa arvoon 0 tai 1 sen mukaan oletko koostamassa testi- vai julkaisuversiota, olettaen ettet muuta asetustiedoston logiikkaa tässä suhteessa.

Palvelinsovelluksen koostamiseksi `dub build` (Vaatii [D-kääntäjän](https://dlang.org) ja D:n pakettienhallinta [DUBin](https://code.dlang.org) joka tulee normaalisti kääntäjän mukana), ajamiseksi testiä varten (Linuxissa - en ole testannut muilla käyttöjärjestelmillä. Toimiikohan edes...) suorita käännetty sovellus ilman lisäargumentteja. Joudut muuttamaan käyttöjärjestelmän tai selaimen nimipalveluasetuksia (DNS) niin että kun menet ate-eskola.localhost:8080 - osoitteeseen (tai mitä sitten sääditkään palvelimen kuuntelemaan `config.d`:ssä) se ohjaa sen omalle koneellesi eikä Internet-osoitteeseen kuten normaalisti. Firefoxissa tämä onnistuu kirjoittamalla osoitepalkkiin `about:config` ja muuttamalla `network.dns.localDomains` testin ajaksi arvoon `koodipaja.ate-eskola.localhost, ate-eskola.localhost`.

Tarvitset myös PostgreSQL-tietokannan joko samalle koneelle sovelluksen kanssa tai jollekin muulle verkkopalvelimelle, ja tietysti käyttäjätunnuksen jolla kirjautua sinne sisälle, mikäli haluat vieraskirjan toimivan. Kirjaudu tietokantaan kyseisellä tunnuksella ja aja `init.db.sql` luodaksesi sovelluksen vaatima tietue tietokantaan.

## Pilveen vienti

Sovelluksen voi varmasti viedä pilveen (tai laittaa palvelemaan Internettiä suoraan koneelta) monella tavalla, mutta kuvailen tässä miten itse sen teen.

Ensin `configVer`-muuttuja `config.d`:ssä (jos se on edelleen kirjoitettu niin kuin `exampleconfig.d`) pitää säätää, ja asetukset muutenkin tarkistaa.

Teen sovelluksesta [Docker-kontin](https://www.docker.com/). Sitä varten käytän [Nix-pakettienhallintaa](https://nixos.org), ja komennan projektin juurihakemistossa `nix-build --arg pkgs "import <nixpkgs> {}" container.nix`.

Pilvessä ([Virtuozzo-alusta](https://www.virtuozzo.com/application-platform/)) teen aluksi uuden tyhjän Docker CE-solmun. Siinä voi kätevästi ajaa sekä itse sovelluksen että tarvittavan Postgres-tietokannan. Tietokanta pitää luonnollisesti saada toimimaan ensin. Itse asennus on hyvin helppoa, sen kuin vain lataa ja ajaa sopivan Docker-kontin. Vaikea osuus tässä itselleni oli saada IP-osoitteen portti reitittymään Postgres-porttiin, ja sen tarkistaminen että tietokannan tiedot ovat pysyviä, eli jos kontti tai koko Docker-solmu resetoituu, eivät tiedot katoa.

Itse sovelluksen suhteen siirrän koostamani kontin Docker - solmuun tiedostona tietokoneeltani - ei erillistä pilvivarastoa kontille - ja kirjaudun SSH:lla sen hallintaan. Lataan Dockeriin solmuun ladatun konttikuvan (`docker load --input tiedosto`), lisään sille viitteen `docker tag` - komennolla ja ajan sen `docker run --detach --restart unless-stopped -p 80:80 ate-eskola.fi:viite`. 

Jos olen tuomassa uutta konttia vanhan tilalle, varmistan palvelukatkon minimoimiseksi ihan ensin että sivu edelleen toimii ja vaihdan vanhan kontin heti takaisin, ellei. Onhan mahdollista että olen unohtanut vaikka säätää `config.d`:n oikein koostaessani konttia.

Huomaa että kontti käsittelee salaamattomia HTTP - pyyntöjä. Erillisen kuormantasaussolmun täytyy toteuttaa SSL-salaus. Tosin tähänkin olen miettinyt muutosta, koska pääsisin halvemmalla ellei tarvitsisi maksaa kuormantasauspalvelimesta vain sertifikaatin takia. Lisäksi jouduin tappelemaan kuormantasauspalvelimen (Nginx) kanssa jotta sain sen päästämään läpi palvelupyynnöt myös tietokannalle eikä pelkästään sovellukselle ja Docker-solmun hallinnoinntiin.

## Lisenssi

Kaikki koodi ja muu sisältö tässä projektissa on käytettävissä MIT-lisenssillä.

Voit siis vapaasti muuntaa tämän esimerkiksi omaksi kotisivuksesi! Muista vain mainita tämä projekti lähteenä jossakin.