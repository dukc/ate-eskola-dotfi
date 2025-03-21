module ateeskola.fi.config;
import ateeskola.fi.main : Config;

// Muuta tämä manuaalisesti sen mukaan teetkö paikallista testiversiota vai
// pilveen tarkoitettua.
private enum configVer = -1;

static if (configVer == 0)
{   immutable Config config = {
        addr: "127.0.0.1:8080",
        rootHostnameRegex: `(?:www\.)?ate\-eskola\.localhost`,
        compHostnameRegex: `(?:www\.)?koodipaja\.ate\-eskola\.localhost`,
        database: "postgres://localhost"
    };
    debug {} else pragma(msg, "HUOMIO: Olet ilmeisesti kääntämässä julkaisuversiota vaikka src/config.d on edelleen säädetty testiasetuksiin!");
} else static if(configVer == 1)
{   immutable Config config = {
        addr: ":80",
        rootHostnameRegex: `(?:www\.)?ate\-eskola\.fi`,
        compHostnameRegex: `(?:www\.)?koodipaja\.ate\-eskola\.fi`,
        database: "postgres://postgres:password@ate-eskola.fi"
    };
}
