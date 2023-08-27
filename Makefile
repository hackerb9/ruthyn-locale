# Makefile for 8-bit (single byte) gconv modules based on a charmap file.
# Similar to https://github.com/martynets/ruthyn-hd44780, but
# automatically creates the necessary .c and .h files from the charmap.

# If you wish to use this for a different 8-bit encoding, you may need
# to only change the CHARMAP variable in this file to point to your
# POSIX style charmap. (Without root access on your machine, you'll
# also want to change the GCONVDIR variable.)

# Hackerb9 2020-2023

###############################################################################
# Charmap file to build a module from
# To override, use  `make CHARMAP=foo.charmap`
###############################################################################

# The character map is the fundamental source code for this project.
# It can be used standalone with iconv or to compile a gconv module.
CHARMAP		= ruthyn.charmap


###############################################################################
# Installation paths
# To override, use  `make GCONVDIR=~/.local/lib/gconv install`
###############################################################################
ifndef GCONVDIR
  ifdef GCONV_PATH
    # Allow user to override the installation directory by exporting GCONV_PATH.
    GCONVDIR	:= $(firstword $(subst :, ,$(GCONV_PATH)))
    $(warning Using environment variable GCONV_PATH to set GCONVDIR=$(GCONVDIR))
  endif
endif

ifndef GCONVDIR
  # The default system gconv dir, at least on Debian boxen. (Requires root.)
  GCONVDIR	:= /usr/lib/$(shell gcc -dumpmachine)/gconv
endif

# Optionally, the module may be installed into a custom directory.
# Tip 1: GNU libc checks the GCONV_PATH environment variable for extra modules.
# Tip 2: The custom directory must also contain a 'gconv-modules' file.
#GCONVDIR 	:= /usr/local/lib/gconv
#GCONVDIR 	:= $(HOME)/.local/lib/gconv


###############################################################################
# Pseudo-libraries
###############################################################################

# Use stubs copied from glibc for #include <iconv/{loop,skeleton}.c>
INCPATH		 += glibcstubs
INCPATH		 += glibcstubs/include

# Use machine dependent sysdep.h (from skeleton.c).
# This should actually be sysdeps/unix/sysv/linux/$(shell uname -m)
INCPATH		 += glibcstubs/sysdeps/$(shell uname -m)

# Use glibc's macro routines from 8bit-gap.c and 8bit-generic.c
INCPATH		 += glibcstubs/iconvdata

# Add the build directory for $(filebase)-gapstyle.h
INCPATH		 += .

###############################################################################
# Commands and their arguments
###############################################################################
# Declare GNU toolchain command line tools
CC		= gcc
CFLAGS		+= -Wall -Wundef -Og -g
CFLAGS		+= -D_STRING_ARCH_unaligned=1
LD		= ld
INSTALL		= install -m 644 -p -D -t
SED		= sed

# Gconv modules are actually dynamic libraries.
GCONV_CFLAGS  := $(addprefix -I, $(INCPATH))
GCONV_CFLAG   += -fPIC
GCONV_LDFLAGS  = -shared


###############################################################################
# Prerequisites and targets
###############################################################################

# Directory to write compiled and otherwise transformed objects.
OBJDIR		:= build

# Remove the ".charmap" extension as a base for making other filenames.
# (e.g., ruthyn.charmap -> ruthyn.c, ruthyn.h, ruthyn.o, ruthyn.so)
filebase	:= $(shell basename -s .charmap $(CHARMAP))

# Compiled objects are written into the OBJDIR directory.
objbase		:= $(OBJDIR)/$(filebase)


###############################################################################
# Extracted info from charmap file
###############################################################################

# Extract name of the codepage (code set) implemented by the charmap file.
CODEPAGE	:= $(shell sh -c "sed -n 's/<code_set_name> *//p' <$(CHARMAP)")
# If the charmap didn't specify the code_set_name, fall back to the filename.
CODEPAGE	:= $(firstword $(CODEPAGE) $(filebase))
# A list of all the aliases from the charmap file.
ALIASES		:= $(shell sh -c "sed -n 's/^% *alias *//p' <$(CHARMAP)")
# Shortest, most convenient alias to the codepage is usually the last one.
ALIAS		:= $(lastword $(CODEPAGE) $(ALIASES))


###############################################################################
# Rules
###############################################################################

# Default is to build the gconv module.
all: 	module

module: $(objbase).so


# Generic rules
.PHONY: clean cleanish uninstall install
.PHONY: install-gconv-modules install-charmap
.PHONY: uninstall-gconv-modules uninstall-charmap
.PHONY: test test-multi test-l1 test-identity test-all

install: $(objbase).so install-gconv-modules
	$(INSTALL) "$(GCONVDIR)" "$(objbase).so"

install-gconv-modules:
	@mkdir -p "$(GCONVDIR)"
	@touch "$(GCONVDIR)/gconv-modules"
	@$(SED) --in-place=~ --follow-symlinks /$(CODEPAGE)/d "$(GCONVDIR)/gconv-modules"
	@printf "# Added by $(CODEPAGE) Makefile on $(shell date)\n" \
		>> "$(GCONVDIR)/gconv-modules"
	@printf    "%-8s%-24s%-24s%-16s%-7s\n" \
		   "#"  "from"  "to    ($(CODEPAGE))"  module  cost \
		>> "$(GCONVDIR)/gconv-modules"
	@for a in $(ALIASES); do \
		   printf    "%-8s%-24s%-24s%-16s%-8s\n" \
			      alias $$a// $(CODEPAGE)// "" ""; \
	done	>> "$(GCONVDIR)/gconv-modules"
	@printf    "%-8s%-24s%-24s%-16s%-8s\n" \
		   module $(CODEPAGE)// INTERNAL $(filebase) 1 \
		   module INTERNAL $(CODEPAGE)// $(filebase) 1 \
		>> "$(GCONVDIR)/gconv-modules"
	iconvconfig  -o "$(GCONVDIR)/gconv-modules.cache"  "$(GCONVDIR)"

uninstall: uninstall-gconv-modules
	$(RM) "$(GCONVDIR)/$(filebase).so"
	@rmdir --ignore-fail-on-non-empty "$(GCONVDIR)" || true

uninstall-gconv-modules:
	@$(SED) --in-place=~ --follow-symlinks /$(CODEPAGE)/d  "$(GCONVDIR)/gconv-modules"
	iconvconfig  -o "$(GCONVDIR)/gconv-modules.cache"  "$(GCONVDIR)"
	@if [ ! -s "$(GCONVDIR)/gconv-modules" ]; then \
	    $(RM) "$(GCONVDIR)/gconv-modules"; \
	    $(RM) "$(GCONVDIR)/gconv-modules~"; \
	    $(RM) "$(GCONVDIR)/gconv-modules.cache"; \
	fi

cleanish:
	$(RM) $(objbase).o core *~

clean: cleanish
	$(RM) $(addprefix $(objbase), .so .c .h -gapstyle.h .txtmap)



###############################################################################
# Various tests. 'make test-all' runs all tests.
###############################################################################
test:
	@echo
	@echo "TESTING ROUNDTRIP TO UTF-8 AND BACK..."
	GCONV_PATH=$(GCONVDIR) tests/test-u8.sh $(CODEPAGE)

test-multi:
	@echo
	@echo "TESTING MANY-TO-ONE MAPPING..."
	GCONV_PATH=$(GCONVDIR) tests/many-to-one.awk $(CHARMAP)

test-l1:
	@echo
	@echo "TESTING LATIN-1 CHARACTERS + TRANSLITERATION..."
	export GCONV_PATH=$(GCONVDIR); \
	    tests/mk8bit.sh \
	    | iconv -f latin1 -t $(CODEPAGE)//translit \
	    | iconv -f $(CODEPAGE)

# NOTA BENE! test-identity fails on gconv modules compiled using
# glibcstubs! However, compiling using the full glibc source tree
# works fine. The difference appears to be something we're
# #include'ing from sysdep.h. See tests/glibcmake.sh.
test-identity:
	@echo
	@echo "TESTING IDENTITY FUNCTION ..."
	echo "Hello" \
	    | GCONV_PATH=$(GCONVDIR) iconv -f $(CODEPAGE) -t $(CODEPAGE)

test-all: test-l1 test-multi test-identity test

# Give a clear warning if a test requires the module to be installed.
$(TARGETDIR)/$(TARGET) $(TARGETDIR)/gconv-modules &: $(TARGET)
	@echo "Please run 'make install' before testing" && false


###############################################################################
# Build Rules
###############################################################################

$(OBJDIR):
	mkdir $(OBJDIR)

# Automagically create the .h tables from the charmap file.
# (cm2h also creates the -gapstyle.h file in passing.)
$(objbase).h $(objbase)-gapstyle.h &: $(CHARMAP) cm2h  | $(OBJDIR)
	./cm2h $< > $(objbase).h || ( $(RM) $(objbase).h; false )
	mv $(filebase)-gapstyle.h $(objbase)-gapstyle.h

# Fill in the boilerplate .c code from the charmap file.
$(objbase).c: $(CHARMAP) cm2c  | $(OBJDIR)
	./cm2c $< $@

# Compile the tables into an object file.
$(objbase).o: $(objbase).c $(objbase).h $(objbase)-gapstyle.h glibcstubs/iconv/skeleton.c glibcstubs/iconv/loop.c
	$(CC) -c $(CFLAGS) $(GCONV_CFLAGS) -o $@ $<

# Link the gconv module as a dynamic library.
$(objbase).so: $(objbase).o
	$(LD) $(LDFLAGS) $(GCONV_LDFLAGS) -o $@ $<
