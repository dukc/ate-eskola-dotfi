---
layout: page
title: Vieraskirja
permalink: /vieraat/
dscript: >-
    struct Preprocessor {
        import std.array, std.meta, std.range, std.sumtype, std.typecons,
            std.utf, std.uni;

        enum Placeholder {pageNum, pageNext, pagePrev,
            name, pubMsg, privMsg, rows, error}
        alias Output = SumType!(string, Placeholder);

        Output[] outputs;

        @safe this(string src) {
            while(src.length) {
                auto match = src.find(aliasSeqOf!(
                    only(__traits(allMembers, Placeholder))
                    .map!(phName => '$' ~ phName.toUpper)
                ));

                outputs ~= Output(src[0 .. $ - match[0].length]);

                auto action(T)(T o, size_t i) => tuple(Output(o), i);

                (
                    match[1]?
                    action
                    (   cast(Placeholder) (match[1]-1),
                        [__traits(allMembers, Placeholder)][match[1]-1].length + 1):
                    action("", 0)
                ).bind!((Output o, size_t skipLen){
                    outputs ~= o;
                    src = match[0][skipLen .. $];
                });
            }
        }

        static immutable monthNames = ["tammi", "helmi", "maalis", "huhti",
            "touko", "kesä", "heinä", "elo",
            "syys", "loka", "marras", "joulu"];

        @safe run(Args args){
            string rows = args.shownVisitors.map!(row =>
                    "\t<tr>\n\t\t<td>" ~
                    htmlEscape(row.name) ~
                    "</td>\n\t\t<td>" ~
                    htmlEscape(row.message) ~
                    "</td>\n\t\t<td>" ~
                    text(
                        row.time.hour, ".", row.time.minute.pipe!(m => (m < 10? "0": "") ~ text(m)), " ",
                        row.time.day, ". ",  monthNames[row.time.month - 1], "kuuta ",  row.time.year) ~
                    "</td>\n\t</tr>\n")
                .join;
            return outputs.map!( output => output.match!(
                ((string s) => s),
                ((Placeholder ph) => [
                    args.pageNumber.text,
                    (args.pageNumber + 1).text,
                    (args.pageNumber - 1).text,
                    htmlAttribEscape(args.formName),
                    htmlAttribEscape(args.formPubMsg),
                    htmlAttribEscape(args.formPrivMsg),
                    rows,
                    args.errorHTML
                ][ph])
            ));
        }
    }
---

$ERROR

<table>
    <tr>
        <th> Vieras </th>
        <th> Terveiset </th>
        <th> Pvm </th>
    </tr>
    $ROWS
</table>

<form action="/vieraat/$PAGENUM" method="post">
    <h1> Kirjoita oma päiväyksesi </h1>
    <p>
        <label for="name">Nimi (pakollinen)</label>
        <input type="text" id="name" name="name" value="$NAME" required />
    </p>
    <p>
        <label for="public_message">Julkiset terveiset</label><br />
        <textarea id="public_message" name="public_message">$PUBMSG</textarea>
    </p>
    <p>
        <label for="private_message">Yksityiset terveiset</label><br />
        <textarea id="private_message" name="private_message">$PRIVMSG</textarea>
    </p>
    <p>
        <button type="submit">Kirjoita</button>
    </p>

</form>

[<<](/vieraat/1) [<\|](/vieraat/$PAGEPREV) Sivu $PAGENUM [\|>](/vieraat/$PAGENEXT) [>>](/vieraat/)
