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

struct Globals
{	import dpq.connection;
	import dpq.exception;
	import dpq.value;
	import dpq.attributes;
	import dpq.query;
	import dpq.result;
	import libpq.libpq;

	Connection database;
	@trusted bool databaseOk() => database.status == CONNECTION_OK;
}

void main(string[] args)
{	import dpq.connection;
	import dpq.exception;
	import dpq.value;
	import dpq.attributes;
	import dpq.result;
	import libpq.libpq;
	import ateeskola.fi.dbq;

	// Antaa vakiota paremman virheviestin jos tulee viitattua
	// laittomaan muistiin Linuxissa
	import etc.linux.memoryerror;
	static if (is(typeof(registerMemoryErrorHandler))) registerMemoryErrorHandler();

	Globals globals;

	try
	{	globals.database = Connection(config.database);
		writeln("Tietokantaan yhdistäminen onnistui.");
	} catch(DPQException e)
	{	writeln("Tietokantaan yhdistäminen epäonnistui: ", e.message);
	}

	auto settings = new HTTPServerSettings(config.addr);
	//auto router = new URLRouter;
	listenHTTP(settings, serve(globals));
	writeln("CTRL-C lopettaaksesi");

	// Tietokannan toimivuuden pikatesti
	version (None) if (globals.databaseOk)
	{	auto results = Query(globals.database, "select * from visitors;").myRun();
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

@safe void delegate(Req, Res) @safe serve(ref Globals globals)
{	import std.algorithm, std.file, std.functional, std.range;

	import ateeskola.fi.dbq;

	auto visitorQuery = globals.database.Query("select name, public_message, time from visitors order by time asc limit $1 offset $2;");
	auto visitorLenQuery = globals.database.Query("select count(*) from visitors;");
	auto visitorLogServer = servePreprocessed!"koodipaja/vieraat/index.html"((req) @safe
	{	import std.datetime;
		VisitorLogModel result;

		if ("pagenum" !in req.params)
		{	//debug writeln(cast(void[]) [visitorLenQuery]);
			if (globals.databaseOk) result.pageNumber =
				visitorLenQuery.myRun().front[0].as!int.get() % result.pageSize + 1;
			else result.pageNumber = 1;
		} else
		{	string parseInput = req.params["pagenum"];

			try result.pageNumber = parse!int(parseInput);
			catch(ConvException) result.pageNumber = -1;
		}

		if (globals.databaseOk)
		{	auto visitorQueryResults = visitorQuery.myRun(result.pageSize,
				result.pageSize * (result.pageNumber - 1));

			result.shownVisitors = visitorQueryResults.map!(dbEntry => result.Entry
			(	dbEntry[0].asString.get(""),
				dbEntry[1].asString.get(""),
				dbEntry[2].as!SysTime.get
			)).array;
		}

		return result;
	});

	@safe void serveVisitorLog(Req req, Res res)
	{	import std.datetime;
		if(req.method == HTTPMethod.POST) {
			writeln("posting");
		}

		visitorLogServer(req, res);
	}

	auto rootRouter = (new URLRouter)
		.get("/", servePreprocessed!"juuri/index.html"(req => PersonalIndexModel(config.companyUrl)))
		.get("*", serveStaticFiles("views/juuri"));
	auto compRouter = (new URLRouter)
		.get("/vieraat", &serveVisitorLog)
		.get("/vieraat/", &serveVisitorLog)
		.get("/vieraat/:pagenum", &serveVisitorLog)
		.post("/vieraat", &serveVisitorLog)
		.post("/vieraat/", &serveVisitorLog)
		.post("/vieraat/:pagenum", &serveVisitorLog)
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
		SysTime time;
	}

	@safe processable() => pageNumber > 0;
	int pageNumber;
	Entry[] shownVisitors;
	enum int pageSize = 40;
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

// Nämä ovat luullakseni muistiturvallisia

