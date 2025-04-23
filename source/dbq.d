// dbq-kirjastoa ei ole merkitty muistiturvalliseksi vaikka se uskoakseni
// pääosin on. Tämä moduuli sisältää koodia että sitä voisi käyttää turvallisesti.

module ateeskola.fi.dbq;

import std.typecons;



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

// as!stringin paluuarvo
// joka saa viitata vain muuttumattomaan muistiin viittaa potentiaalisesti
// muuttuvaan ubyte[]-tyyppiseen muistiin (Valuen kenttä). Kenttä on yksityinen
// mutta tupleofilla siihen pääsisi käsiksi joten tarkasti ottaen as!string ei
// ole muistiturvallinen. Siksi kopioin paluuarvon (idup) ennen kuin palautan
// sen edelleen.
@trusted pure Nullable!string asString(imported!"dpq.value".Value val)
{	auto result = val.as!string;
	if (!result.isNull) result = result.get.idup.nullable;
	return result;
}
