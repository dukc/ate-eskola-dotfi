import vibe.vibe;
import std;

alias Req = HTTPServerRequest;
alias Res = HTTPServerResponse;

@safe void safeMain(string[] args, Opts opts)
{	auto settings = new HTTPServerSettings(opts.addr);
	auto router = new URLRouter;

	listenHTTP(settings, serve);

	writeln("CTRL-C lopettaaksesi");
	runApplication();
}

//readOption ei ole muistiturvallinen - luullakseni säieturvallisuus puuttuu
@system void main(string[] args)
{	Opts opts;
	readOption("addr", &opts.addr,
		"IP-Osoite ja/tai porttinumero mitä palvelin kuuntelee");
	finalizeCommandLineOptions();
	return safeMain(args, opts);
}

struct Opts
{	string addr = ":80";
}

@safe void delegate(Req, Res) @safe serve()
{	auto rootServer = serveStaticFiles("data/juuri");
	auto compServer = serveStaticFiles("data/koodipaja");

	return (req, res)
	{	auto urlHost = req.fullURL.normalized.host;

		if(urlHost.length >= 4 && urlHost[0 .. 4] == "www.")
			urlHost = urlHost[4 .. $];

		if(urlHost == "ate-eskola.fi") rootServer(req, res);
		else if(urlHost == "koodipaja.ate-eskola.fi") compServer(req, res);
	};
}
