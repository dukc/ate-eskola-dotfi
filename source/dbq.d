module ateeskola.fi.dbq;

// dbq-kirjastoa ei ole merkitty muistiturvalliseksi vaikka se uskoakseni ainakin
// pääosin on. Tämä moduuli sisältää koodia että sitä voisi käyttää turvallisesti.

@trusted Query(ref imported!"dpq.connection".Connection conn, string command)
=> imported!"dpq.query".Query(conn, command);

// Koska run on Queryn jäsenfunktio, en voi "ohittaa" sen määritelmää dpq:ssa
// omallani noin vain. Siksi toinen nimi.
@trusted myRun(T...)(imported!"dpq.query".Query query, T args)
=> query.run(args).QueryResult;

struct QueryResult
{	imported!"dpq.result".Result impl;

	@trusted:

	auto front() => QueryRow(impl.front);
	auto popFront() => impl.popFront();
	auto empty() => impl.empty();
	// impl on käytännössä tallennettava sarja yksinkertaisesti kopioimalla
	// vaikka tekijä ei olekaan määritellyt sitä sellaisesksi.
	auto save() => this;
}

struct QueryRow
{	imported!"dpq.result".Row impl;

	@trusted:

	auto opIndex(T)(T col) => impl.opIndex(col);
}

// Vähän kyseenalaista merkitä tämä muistiturvalliseksi, koska palautettu string
// joka saa viitata vain muuttumattomaan muistiin viittaa potentiaalisesti
// muuttuvaan ubyte[]-tyyppiseen muistiin (Valuen kenttä). Kenttä on kuitenkin
// yksityinen joten kaitpa se on kyllin hyvin suojattu muutoksilta.
@trusted pure auto asString(imported!"dpq.value".Value val)
=> val.as!string;
