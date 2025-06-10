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
	// Miten paljon tietokantakiintiö kasvaa tavuina per 10 sekuntia.
	// sivu kieltäytyy ottamasta lisäpäivityksiä asiakkailta jos
	// tietokantakiintiö ylittyy. Ei välttämättä pidä tarkasti
	// paikkansa - tietojen koot perustuvat karkeisiin arvioihin.
	long databaseAllowancePerDsec;
	// Tietokantakiintiön maksimiarvo, eli miten paljon tietokanta voi
	// maksimissaan kasvaa lyhyessä ajassa. Ylempi asetus täydentää vähennyttä
	// kunnes se on taas tässä arvossa.
	long databaseAllowanceMax;
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
	// Connectionissa ei ole virallisen olista keinoa tarkistaa onko sitä
	// alustettu ollenkan (database.status kaatuu jos ei) joten tarvitaan
	// erillinen muuttuja siitä kärryillä pysymiseksi.
	bool databaseInitialised;
	@trusted bool databaseOk() => databaseInitialised && database.status == CONNECTION_OK;

	long databaseAllowance;

}

void main(string[] args)
{	import dpq.connection;
	import dpq.exception;
	import dpq.value;
	import dpq.attributes;
	import dpq.result;
	import libpq.libpq;
	import ateeskola.fi.dpq;

	// Antaa vakiota paremman virheviestin jos tulee viitattua
	// laittomaan muistiin Linuxissa
	import etc.linux.memoryerror;
	static if (is(typeof(registerMemoryErrorHandler))) registerMemoryErrorHandler();

	Globals globals;
	globals.databaseAllowance = config.databaseAllowanceMax;

	if(auto err = globals.connectDatabase())
	{	writeln("Tietokantaan yhdistäminen epäonnistui.");
		err.writeln();
	} else writeln("Tietokantaan yhdistäminen onnistui.");

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

	runTask(
	{	// Jos ei nolla, ei kirjoiteta lokiin potentiaalisesti jatkuvasti
		// toistuvia pävityksiä, ettei loki kasva liian nopeasti.
		int errorBlock = 0;
		for(ulong i = 0;;i++) try
		{	sleep(10.seconds);

			if (errorBlock > 0) errorBlock--;
			if(i % 4 == 0 || !globals.databaseOk)
			{	if (auto e = globals.connectDatabase()) if(!errorBlock)
				{	e.writeln();
					errorBlock = 60;
				}
			}
			globals.databaseAllowance = min
			(	globals.databaseAllowance + config.databaseAllowancePerDsec,
				config.databaseAllowanceMax
			);
		} catch(Exception e)
		{	try
			{	writeln("Ajastin kaatui -- ei pitäisi koskaan tapahtua!");
				writeln(e);
			} catch(Exception) {}
			assert(false);
		}
	});

	runApplication();
}

@safe void delegate(Req, Res) @safe serve(ref Globals globals)
{	import std.algorithm, std.file, std.functional, std.range;

	import ateeskola.fi.dpq;

	auto visitorQuery = globals.database.Query("select name, public_message, time from visitors order by time asc limit $1 offset $2;");
	auto visitorInsertion = globals.database.Query("insert into visitors (name, public_message, private_message, time) values ($1, $2, $3, $4);");
	auto visitorLenQuery = globals.database.Query("select count(*) from visitors;");
	auto visitorLogServer = servePreprocessed!"koodipaja/vieraat/index.html"((req) @safe
	{	import std.datetime;
		import dpq.exception;

		VisitorLogModel result;

		if ("pagenum" !in req.params)
		{	if (globals.databaseOk) try result.pageNumber =
				cast(int) visitorLenQuery.myRun().front[0].as!long.get() / result.pageSize + 1;
			catch (DPQException e)
			{	() @trusted
				{ 	result.errorHTML ~= "<error>Tietokantahäiriö: "
					~ e.toString.htmlEscape ~ "</error>";
				}();

				result.pageNumber = 1;
			}
			else result.pageNumber = 1;
		} else
		{	string parseInput = req.params["pagenum"];

			try result.pageNumber = parse!int(parseInput);
			catch(ConvException) result.pageNumber = -1;
		}

		if(req.params["error"].length > 0)
		{	result.errorHTML ~= req.params["error"];

			// Kun kerta tuli virhe, lähetetään käyttäjän lomake takaisin
			// jottei hänen tarvitse jälleenkirjoittaa sitä alusta mikäli
			// hän haluaa yrittää lähettää sen uudelleen.
			result.formName = req.form.get("name", "");
			result.formPubMsg = req.form.get("public_message", "");
			result.formPrivMsg = req.form.get("private_message", "");
		}

		if (globals.databaseOk) try
		{	auto visitorQueryResults = visitorQuery.myRun(result.pageSize,
				result.pageSize * (result.pageNumber - 1));


			result.shownVisitors = visitorQueryResults.map!(dbEntry => result.Entry
			(	dbEntry[0].asString.get(""),
				dbEntry[1].asString.get(""),
				dbEntry[2].as!SysTime.get
			)).array;
		} catch (DPQException e)
		{	() @trusted
			{ 	result.errorHTML ~= "<error> Tietokantahäiriö: "
				~ e.toString.htmlEscape ~ "</error>";
			}();
		} else if (result.errorHTML == "") result.errorHTML ~= "<error>Tietokantaan ei ole yhteyttä, joten "
			~ "vieraskirjaa ei voi valitettavasti näyttää. Uudelleen "
			~ "yrittäminen hetken kuluttua voi auttaa.</error>";

		return result;
	});

	// Sisältää @trusted-koodia
	@safe void serveVisitorLog(Req req, Res res)
	{	import std.datetime;
		import dpq.exception;

		req.params["error"] = "";
		if(req.method == HTTPMethod.POST) {
			if(!globals.databaseOk)
			{	req.params["error"] = req.params["error"]
				~ "<error>Tietokantaan ei saada yhteyttä, joten vieraskirjaan kirjoitus "
				~ "ei valitettavasti onnistunut. Uudelleen yrittäminen "
				~ "hetken kuluttua voi auttaa.</error>\n";
				goto postingDone;
			}

			if("name" !in req.form
				|| "public_message" !in req.form
				|| "private_message" !in req.form )
			{
				req.params["error"] = req.params["error"]
				~ "<error>Lähetetystä nettilomakkeesta puuttuu kenttiä. "
				~ "Jos yritit kirjoittaa vieraskirjaan normaalisti painamalla "
				~ "nappia alempana, tämän ei pitäisi tapahtua. Sivustossa "
				~ "(tai selaimessasi, epätodennäköistä) on siinä "
				~ "tapauksessa vika.</error>\n";
				goto postingDone;
			}

			auto entrySize = req.form.estimateVisitorEntrySize;

			if(entrySize > globals.databaseAllowance)
			{	req.params["error"] = req.params["error"]
				~ "<error>Vieraskirja on ruuhkautunut, tai "
				~ "palvelunestohyökkäyksen kohteena eikä siksi "
				~ "hyväksynyt päivitystä. Voit yrittää lyhentää terveisiäsi "
				~ "tai yrittää hetken kuluttua uudelleen</error>";
				goto postingDone;
			}

			try visitorInsertion.myRun(req.form["name"],
				req.form["public_message"],
				req.form["private_message"],
				Clock.currTime());
			catch (DPQException e)
			{	() @trusted
				{ 	req.params["error"] = req.params["error"]
					~ "<error> Tietokantahäiriö: "
					~ e.toString.htmlEscape ~ "</error>";
				}();
				goto postingDone;
			}

			globals.databaseAllowance -= entrySize;
		}

		postingDone:
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

//Jos yhdistäminen onnistuu, tulos null.
@trusted Exception connectDatabase(ref Globals globals)
{	import dpq.connection;
	import dpq.exception;
	try
	{	globals.database = Connection(config.database);
		globals.databaseInitialised = true;
		return null;
	} catch(DPQException e)
	{	return e;
	}
}

@safe pure long estimateVisitorEntrySize(typeof(Req.form) form)
=> VisitorLogModel.Entry.sizeof + form["name"].length +
	form["public_message"].length + form["private_message"].length;

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
	string errorHTML;
	string formName;
	string formPubMsg;
	string formPrivMsg;
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

// Hakee D-koodin HTML-tiedostosta.
// Huonosti tehty - pitäisi käyttää oikeaa HTML- tai XML-lukijaa. Tämä voi mm.
// erehtyä sen mukaan miten välilyönnit on sijoitettu eikä ota
// huomioon lainausmerkkejä tai mitään.
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

