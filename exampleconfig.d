module ateeskola.fi.config;
import ateeskola.fi.main : Config;

immutable Config config = {
    addr: ":80",
    rootHostnameRegex: `(?:www\.)?ate\-eskola\.fi`,
    compHostnameRegex: `(?:www\.)?koodipaja\.ate\-eskola\.fi`,
};
