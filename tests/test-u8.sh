#!/bin/bash -e
# Test roundtrip to UTF-8 and back

# Looks for test files named after the character set (in UPPER CASE):
#
#    testdata/CHARSET		(a file in the CHARSET's own encoding)
#    testdata/CHARSET..UTF-8	(the same file in UTF-8)
#
# Tests converting from each file into the other using 'iconv'. 
#
# If the files don't exist, then all 8-bit chars from 0x20 to 0xFF are tried.

main() {
    local charset="$1"
    if ! iconv -f $charset -t $charset </dev/null; then
	echo "Error: Charset '$charset' not found. Maybe try 'make install'"?
	exit 1
    fi

    cd "$(dirname "$0")"

    local data="testdata/${charset@U}"
    local data8="testdata/${charset@U}..UTF-8"
    if [[ -r "$data" && -r "$data8" ]]; then
	# If we happen to have ground truth testdata files, check them.
	echo "'$data' <=> '$data8'"
	cmpiconv "$charset" "$data" "$data8" || exit 1
	cat "$data8"
	echo "Ground truth files test good."
    else
	# Just try all 8-bit characters (0x20 to 0xFF) and show result.
	# BUG: Characters do not align properly if charset has holes.
	./mk8bit.sh -a |
	    iconv -c -f $charset -t UTF8 |
	    iconv -f UTF8 -t $charset |
	    iconv -f $charset
    fi
}


cmpiconv() {
    # Given an encoding name and two files, check that iconv can convert
    # those files using the given charset. 
    local enc="$1" f1="$2" f2="$3"
    
    if ! cmp --print-bytes --verbose \
	 <(iconv -f $enc -t UTF8 "$f1") \
	 "$f2"
    then
	echo "Converting file '$f1' to UTF-8 does not match '$f2'">&2
	return 1
    fi
    
    if ! cmp --print-bytes --verbose \
	 <(iconv -f UTF8 -t $enc "$f2") \
	 "$f1"
    then
	echo "Converting file '$f2' to $enc does not match '$f1'">&2
	return 1
    fi

    return 0
}


if [[ -z "$1" ]]; then
    echo "Usage: $0 <charset>"
    exit 1
fi

main "$@"
