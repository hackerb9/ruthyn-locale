ifndef GCONVDIR
  # The default system gconv dir, at least on Debian boxen. (Requires root.)
  # To override, use  `make GCONVDIR=~/.local/lib/gconv install`
  GCONVDIR	:= /usr/lib/$(shell gcc -dumpmachine)/gconv
endif

MODULE		= ruthyn-hd44780.so

test: ruthyn-example
	@echo "The following output should be in the ruthyn-hd44780 charset"
	./ruthyn-example

ruthyn-example: ruthyn-example.c $(GCONVDIR)/$(MODULE) $(GCONVDIR)/gconv-modules
	GCONV_PATH=$(GCONVDIR) gcc -fexec-charset=ruthyn ruthyn-example.c -o ruthyn-example

$(GCONVDIR)/$(MODULE) $(GCONVDIR)/gconv-modules &:
	@echo "Please run 'make install' before testing" && false

clean:
	$(RM) ruthyn-example
