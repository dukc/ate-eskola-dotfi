---
layout: page
title: Vieraskirja
permalink: /vieraat/
dscript: >-
    struct Preprocessor {
        import std.array, std.range, std.sumtype, std.typecons, std.utf;

        static struct PageNum{}
        static struct Rows{}
        alias Output = SumType!(string, PageNum, Rows);

        Output[] outputs;
        size_t tablesPos;

        @safe this(string src) {
            while(src.length) {
                auto match = src.find('$' ~ "PAGENUM", '$' ~ "ROWS");
                outputs ~= Output(src[0 .. $ - match[0].length]);

                auto action(T)(T o, size_t i) => tuple(Output(o), i);

                predSwitch(match[1],
                        0, action("", 0),
                        1, action(PageNum(), 8),
                        2, action(Rows(), 5))
                    .bind!((Output o, size_t skipLen){
                        outputs ~= o;
                        src = match[0][skipLen .. $];
                    });
            }

        }

        static immutable monthNames = ["tammi", "helmi", "maalis", "huhti",
            "touko", "kesä", "heinä", "elo",
            "syys", "loka", "marras", "joulu"];

        @safe run(Args args){
            string pageNum = args.pageNumber.text;
            string rows = args.shownVisitors.map!(row =>
                    "\t<tr>\n\t\t<td>" ~
                    row.name ~
                    "<\td>\n\t\t<td>" ~
                    row.message ~
                    "<\td>\n\t\t<td>" ~
                    text(
                        row.time.hour, ".", row.time.minute.pipe!(m => m < 10? "0": "" ~ text(m)), " ",
                        row.time.day, ". ",  monthNames[row.time.month], "kuuta ",  row.time.year) ~
                    "<\td>\n\t<\tr>\n")
                .join;
            return outputs.map!( output => output.match!(
                ((string s) => s),
                ((Rows _) => rows),
                ((PageNum _) => pageNum)
            ));
        }
    }
---

<table>
    <tr>
        <th> Vieras <\th>
        <th> Terveiset <\th>
        <th> Pvm <\th>
    <tr>
    $ROWS
<\table>

<form action="post">
    <p> Kirjoita oma päiväyksesi <\p>

</form>
