module ateeskola.fi.main;

import vibe.d;
import std;
// config ei ole versionhallinnassa, sinun pitää kirjoittaa se itse.
// Voit kopioida projektin juurikansiosta exampleConfigin src-kansioon
// ja uudelleennimetä sen config.d:ksi, ja sen pitäisi toimia.
import ateeskola.fi.config : config;

alias Req = HTTPServerRequest;
alias Res = HTTPServerResponse;

/*@safe void safeMain(string[] args,  opts)
{	auto settings = new HTTPServerSettings(opts.addr);
	auto router = new URLRouter;

	listenHTTP(settings, serve);

	writeln("CTRL-C lopettaaksesi");
	runApplication();
}*/

@safe void main(string[] args)
{	auto settings = new HTTPServerSettings(config.addr);
	auto router = new URLRouter;

	listenHTTP(settings, serve);

	writeln("CTRL-C lopettaaksesi");
	runApplication();
}

struct Config
{	string addr;
	string rootHostnameRegex;
	string compHostnameRegex;
	string database;
}

@safe void delegate(Req, Res) @safe serve()
{	import std.algorithm, std.range;
	auto rootServer = serveStaticFiles("data/juuri");
	auto compServer = serveStaticFiles("data/koodipaja");

	auto rootMatcher = regex(config.rootHostnameRegex, "i");
	auto compMatcher = regex(config.compHostnameRegex, "i");

	return (req, res)
	{	auto urlHost = req.fullURL.normalized.host;

		if(urlHost.matchFirst(rootMatcher).equal(urlHost.only)) rootServer(req, res);
		else if(urlHost.matchFirst(compMatcher).equal(urlHost.only)) compServer(req, res);
	};
}
