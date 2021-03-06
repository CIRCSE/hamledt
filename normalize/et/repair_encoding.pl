#!/usr/bin/env perl
# Repairs encoding of the Estonian treebank.
# Copyright © 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>
# License: GNU GPL

use utf8;
use open ":utf8";
binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

while(<>)
{
    # The treebank is encoded in UTF-8.
    # However, it contains wrong characters, perhaps because of previous conversions from other encodings.
    # The following occurs in the file piialaused.xml:
    # ð (\x{F0}) should be š (\x{161})
    # Elsewhere, there is "ts^" instead of "tš".
    # Examples: šatään, maršruut, dušš, tšuktši
    s/\x{F0}/\x{161}/g;
    s/S\^/\x{160}/g;
    s/s\^/\x{161}/g;
    # Similarly, loanwords may contain "ž".
    # Examples: žiletid, žurnalistika, žürii, žanr, žargoon
    s/Z\^/\x{17D}/g;
    s/z\^/\x{17E}/g;
    # Some instances are also encoded using entities (which underwent a second encoding when wrapped in the TIGER-XML).
    s/&amp;Scaron;/\x{160}/g;
    s/&amp;scaron;/\x{161}/g;
    s/&amp;Zcaron;/\x{17D}/g;
    s/&amp;zcaron;/\x{17E}/g;
    print;
}
