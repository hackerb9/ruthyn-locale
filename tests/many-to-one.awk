#!/bin/gawk -nf
# many-to-one.awk:
# Usage: many-to-one.awk <filename.charmap>

# Look for many-to-one mappings in the charmap definition and then
# test to see if they actually work in the gconv module.

# For example, both U+00B7 and U+2022 may map to the same character in
# an 8-bit encoding.

# Many-to-one mappings were often called for when dealing with
# single-byte encodings which only had space for 256 characters.
# Certain characters performed double or triple duty. For example,
# Latin-1's 'ß' character, which is officially the German S-sharp, was
# often used in English speaking countries to mean a Greek Beta.

# Note: Mapping in reverse, each 8-bit character goes to a unique UCS
# character. There is probably an official way to do this, but for
# now, hackerb9 has decided that only the first UCS character listed
# in the charmap file will be used for reverse maps.
##

# SIDENOTE: glibc automatically handles many reasonable
# transliterations when the //translit option is specified at the end
# of the characterset name. For example, if a characterset defines
# U+007C ('|') but not U+00A6 ('¦'), then any time the program prints
# A6 to the screen, 7C will be sent instead:
#
# 	$ printf $'\uA6' | iconv -t ruthyn//translit | xxd -p
#	7c
#
# However, those transliterations are not what this program exercises.


BEGIN {
    progname = PROCINFO["argv"][2];
    IGNORECASE = 1;
    incharmap = 0;
    comment_char = "#";		# charmaps from GNU & IBM set this to "%".
    escape_char = "\\"; 	# charmaps from GNU & IBM set this to "/".
}

$1=="<code_set_name>" { code_set_name=$2; }
$1=="<comment_char>" { comment_char=$2; }
$1=="<escape_char>" { escape_char=$2; }

# Skip lines that start with the comment character (typically %)
$1 ~ "^" comment_char { next; }

# Only process lines between "CHARMAP" and "END CHARMAP"
$1=="CHARMAP" { incharmap=1; next; }
$1=="END" && $2=="CHARMAP" { incharmap=0; next; }

incharmap==1 {
    # Read each Unicode character (in hexadecimal) and
    # the corresponding byte sequence (also in hex).

    # If the Unicode character has been seen before, test the new
    # definition to make sure that it also works in the gconv module.

    # Look for hex in $1 (like <U000E01EF>)
    if (! match($1, /<U([0-9A-F]+)>/, matcharray)) { next; }
    ucsidx = toupper(matcharray[1]);

    # Look for hex in $2 (like /xf3/xa0/x87/xaf -> code=f3)
    patsplit($2, a, /[0-9A-F]+/);
    code = tolower(a[1]);

    if (revmap[code]=="") {
	/* Mark this 8-bit encoding as used */
	revmap[code] = ucsidx;
    }
    else {
	/* This 8-bit encoding has been used before, test it. */
	testboth(revmap[code], ucsidx, code);
    }
}


function testboth(a, b, x,	aval, bval, xval, aout, bout, xout) {
    aval = hex2bytes(a);
    bval = hex2bytes(b);
    xval = "\\x" x;

    printf  FILENAME ":"  NR; 
    pipecmd=sprintf("/bin/printf '%s' | iconv -f UCS4 -t %s | xxd -p",
		    aval, code_set_name);
    pipecmd | getline aout;
    close(pipecmd)

    pipecmd=sprintf("/bin/printf '%s' | iconv -f UCS4 -t %s | xxd -p",
		    bval, code_set_name);
    pipecmd | getline bout;
    close(pipecmd)

    if (aout!=bout) {
	print "\t***ERROR***";
	printf("Both UCS %s (%c) and UCS %s (%c) should map to 0x%s.",
	       a, strtonum("0x" a), b, strtonum("0x" b), x );
	print ("\t%s (%c) -> %s\n", a, strtonum("0x" a), aout);
	print ("\t%s (%c) -> %s\n", b, strtonum("0x" b), bout);
	print;
	err=1;
    }

    pipecmd=sprintf("/bin/printf '%s' | iconv -f %s -t UCS4 | xxd -p",
		    xval, code_set_name);
    pipecmd | getline xout;
    close(pipecmd)
    if (aout==bout && hex2bytes(xout)==aval) {
	printf( "    UCS %s (%c) ↔ 0x%s and UCS %s (%c) → 0x%s.",
		a, strtonum("0x" a), x, b, strtonum("0x" b), x );
	print "\tGood."
    }
    else  {
	print "\t***ERROR***";
	printf("Encoding %s (%c) should map to UCS %s (%c),",
	       x, strtonum("0x" x), a, strtonum("0x" a) );
	printf (" but instead maps to %s.\n", xout);
	print;
	err=1;
    }
}

function hex2bytes(u) {
    # Given a string u of hexadecimal numbers, break them into bytes
    # (two hexits) and prefix each byte with "\x" for interpretation
    # by /bin/printf. Example "1F6E7" -> "\x00\x01\xF6\xE7"
    u = strtonum("0x" u);
    return sprintf( "\\x%02X\\x%02X\\x%02X\\x%02X",
		    (u / 0x01000000) % 0x100,
		    (u / 0x00010000) % 0x100,
		    (u / 0x00000100) % 0x100,
		    (u / 0x00000001) % 0x100 );
}


END {
    if (err) {
	print "***ERRORS DETECTED***";
	exit 1;
    }
    else
	print "All many-to-one tests successful.";
	exit 0;
}
