module ateeskola.fi.main;

import vibe.vibe;
import std;
// config ei ole versionhallinnassa, sinun pitää kirjoittaa se itse.
// Voit kopioida projektin juurikansiosta exampleConfigin src-kansioon
// ja uudelleennimetä sen config.d:ksi, ja sen pitäisi toimia.
import ateeskola.fi.config : config;

alias Req = HTTPServerRequest;
alias Res = HTTPServerResponse;

struct Config
{	// Portti ja/tai IP-osoite jota kuunnellaan. Määrittelysyntaksi kuten täällä:
    // https://vibed.org/api/vibe.http.server/HTTPServerSettings.this
	string addr;
	// RegEx - lause, jolla testataan tuleeko palvelupyyntö henkilokhtaiselle
    // sivulle. Koko osoitteen pitää täsmätä, ei vain osan siitä. Kirjainkoko
    // on merkityksetön.
	string rootHostnameRegex;
	// Sama, mutta yrityksen sivulle.
	string compHostnameRegex;
	// URL-osoite yrityksen sivuille
	string companyUrl;
	// PostgreSQL-yhdistyslause jota käytetään tietokantaan yhdistämiseen.
    // Syntaksi löytyy
    // https://www.postgresql.org/docs/current/libpq-connect.html
    // Sivu toimii tietokantaa vaativia funktioita lukuunottamatta vaikka
    // tämä jättää tyhjäksi (tai virheelliseen arvoon).
	string database;
}

void main(string[] args) => Globals().main(args);

struct Globals
{	import dpq.connection;
	import dpq.exception;
	import dpq.value;
	import dpq.attributes;
	import dpq.query;
	import dpq.result;
	import libpq.libpq;

	Connection database;
	bool databaseOk() => database.status == CONNECTION_OK;

	void main(string[] args)
	{	try
		{	database = Connection(config.database);
			writeln("Tietokantaan yhdistäminen onnistui.");
		} catch(DPQException e)
		{	writeln("Tietokantaan yhdistäminen epäonnistui: ", e.message);
		}

		auto settings = new HTTPServerSettings(config.addr);
		//auto router = new URLRouter;
		listenHTTP(settings, serve());
		writeln("CTRL-C lopettaaksesi");

		// Tietokannan toimivuuden pikatesti
		version (none) if (databaseOk)
		{	auto results = Query(database, "select * from visitors;").run();
			foreach(row; results)
			{	import std.array;
				row
					.repeat
					.zip(iota(4))
					.map!(bind!((val, index) => val[index].as!string.get("NULL")))
					.join(", ")
					.writeln;
			}
		}

		runApplication();
	}
}

@safe void delegate(Req, Res) @safe serve()
{	import std.algorithm, std.file, std.functional, std.range;

	auto visitorLogServer = servePreprocessed!"koodipaja/vieraat/index.html"((req) @safe
	{	import std.datetime;
		if ("pagenum" !in req.form) req.form["pagenum"] = "1";

		string parseInput = req.form["pagenum"];
		VisitorLogModel result;
		result.pageNumber = parse!int(parseInput);
		if(!parseInput.empty) result.pageNumber = -1;

		result.shownVisitors =
		[	result.Entry("Hannu", "terve", cast(DateTime) Clock.currTime() - 30.minutes),
			result.Entry("Kerttu", "horo", cast(DateTime) Clock.currTime() - 30.seconds)
		];

		return result;
	});

	@safe void serveVisitorLog(Req req, Res res)
	{	import std.datetime;
		if(req.method == HTTPMethod.POST) {
			writeln("posting");
		}

		visitorLogServer(req, res);
		// Jos visitorLogServer ei saanut kirjoitettua.
		res.writeBody("", 404);
	}

	auto rootRouter = (new URLRouter)
		.get("/", servePreprocessed!"juuri/index.html"(req => PersonalIndexModel(config.companyUrl)))
		.get("*", serveStaticFiles("views/juuri"));
	auto compRouter = (new URLRouter)
		.get("vieraat/", &serveVisitorLog)
		.get("vieraat/:pagenum", &serveVisitorLog)
		.post("vieraat/", &serveVisitorLog)
		.post("vieraat/:pagenum", &serveVisitorLog)
		.get("*", serveStaticFiles("views/koodipaja"));

	auto rootMatcher = regex(config.rootHostnameRegex, "i");
	auto compMatcher = regex(config.compHostnameRegex, "i");

	return (req, res)
	{	auto urlHost = req.fullURL.normalized.host;

		if(urlHost.matchFirst(rootMatcher).equal(urlHost.only))
			rootRouter.handleRequest(req, res);
		else if(urlHost.matchFirst(compMatcher).equal(urlHost.only))
			compRouter.handleRequest(req, res);
	};
}

struct PersonalIndexModel
{	string companyUrl;
	enum processable = true;
}

struct VisitorLogModel
{	import std.datetime;

	static struct Entry
	{	string name;
		string message;
		DateTime time;
	}

	@safe processable() => pageNumber > 0;
	int pageNumber;
	Entry[] shownVisitors;
}



/+@safe void delegate(Req, Res) @safe servePersonalIndex(string path)(PersonalIndexModel)
{	return (reg, res) => {};
}+/


@safe void delegate(Req, Res) @safe servePreprocessed(string path, Model)(Model delegate(Req) @safe controller)
{	import std.file;
	auto processor =
		HtmlDScript!(path, Model).Preprocessor(std.file.readText("views/" ~ path));

	return (req, res)
	{	auto model = controller(req);
		if (model.processable)
		{	auto bodyChunks = processor.run(controller(req));
			foreach(chunk; bodyChunks) res.bodyWriter.write(chunk);
			res.finalize();
		}
	};
}

template HtmlDScript(string path, Args)
{	mixin(getDScript(import(path)));
}

// Huonosti tehty - pitäisi käyttää oikeaa HTML-lukijaa. Tämä voi mm. erehtyä sen mukaan
// miten välilyönnit on sijoitettu eikä ota huomioon lainausmerkkejä tai mitään.
@safe pure string getDScript(string from)
{	import std.algorithm, std.range, std.utf;
	auto search = from.byCodeUnit;

	redo:
	search = search.findSplitAfter("<script".byCodeUnit)[1];
	if (search.empty) return [];

	auto tagEnd = search.findSplitAfter(">".byCodeUnit);
	auto dlangAttr = search.findSplitAfter("dlang".byCodeUnit);

	if(dlangAttr[0].length >= tagEnd[0].length)
	{	search = dlangAttr[1];
		goto redo;
	}

	auto closingTag = tagEnd[1].findSplit("</script".byCodeUnit);
	if (closingTag[2].empty) return [];
	// .source muuttaa .byCodeUnitin paluuarvon takaisin tavalliseksi merkkijonoksi.
	return closingTag[0].source;

}

