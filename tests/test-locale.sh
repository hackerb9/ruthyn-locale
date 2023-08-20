#!/bin/bash -e
# Test if a given locale is valid. There must be a better way to do this...
main() {
    local loc="$1"
    
    if ! LANG=$loc islocalevalid; then
	if ! LANG=en_US.$loc islocalevalid; then
	    echo "Error: Locale '$loc' not installed" >&2
	    exit 1
	else
	    echo -n "Found locale 'en_US.$loc': " >&2
	    loc=en_US.$loc
	fi
    else
	echo -n "Locale '$loc' is valid: " 
    fi	

    LANG=$loc locale -kc charmap | grep charmap
    exit 0
}

islocalevalid() {
    # Returns an error if the current locale ($LANG) is invalid.
    # locale command doesn't return a proper exit code, but we can check stderr.
    local error=$(locale 2>&1 1>/dev/null)
    if [[ "$error" ]]; then
	return 1		# Invalid
    else
	return 0		# Valid
    fi
}


if [[ -z "$1" ]]; then
    echo "Valid locales:"
    echo
    locale -a | column | sed 's/^/\t/'
    echo
    echo "Usage: $0 <localename>"
    exit
fi


main "$@"
