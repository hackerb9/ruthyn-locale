# RUTHYN-HD44780 gconv module

Compiles a module, ruthyn.so, which maps from Unicode to the Ruthyn
character set for Epson's HD44780 LCD driver. 

## Comparison to Martynets' original

This is similar to [Andriy Martynets](github.com/martynets/ruthyn-hd44780), 
but with a rewritten implementation. It should now be simpler for
people to reuse this code for other 8-bit character sets as all that
is needed is a POSIX charmap file. (See [ruthyn.charmap](ruthyn.charmap) 
for an example).

### Similarities

* Can be used to compile C programs that contain Ukrainian literal
  strings so that they automatically output using the RUTHYN-HD44780
  character set instead of UTF-8 Unicode.
  
### Differences

* The ruthyn.charmap file is the only source that needs to be changed
  to create a module for a different character set. The old .c and .h
  files have been removed as they are now automatically generated.
  
* The module can be dynamically loaded by calling GNU glibc's
  `setlocale()` function.[^†]

* Many programs will not need to be recompiled if they already use
  `setlocale` and wide-character I/O (`wprintf`).[^†]

* Strings can be dynamically generated, not just hardcoded literals.[^†]

* Can use `iconv` to convert files bidirectionally.

[^†]: Requires setting an environment variable: `LANG=ruthyn`.
	Additionally, If the module is not installed in the system
	directory (e.g., /usr/lib/x86_64-linux-gnu/gconv/), then an
	additional environment variable must be set:
	`GCONV_PATH=/usr/local/lib/gconv/`.

## Installation

To compile and install the module issue the following commands from the directory containing the source:

```bash
make
make install
```

By default the module gets installed to the system directory (e.g,
`/usr/lib/$(gcc -dumpmachine)/gconv`). If this is not the preferred
destination either the `Makefile` needs to be altered to modify the
`GCONVDIR` variable or the destination must be specified in the
command line in format:


```
make GCONVDIR=$HOME/.local/lib/gconv install
```
To uninstall the module:

```bash
make uninstall
```

For more customizations see the `Makefile` internal variables and comments.

## Usage

There are multiple ways in which these files can be used which offer
different benefits. 

All the options perform a "forward mapping", that is, they convert a
program's output from Unicode to an 8-bit character set.

| Option Name       | Source code as is | No recompile | Dynamic strings | One binary | Compiles w/o files | Runs w/o files | Runs w/o vars | Reverse map | I&O |
|-------------------|-------------------|--------------|-----------------|------------|--------------------|----------------|---------------|-------------|-----|
| iconv charmap     | Yes               | Yes          | Yes             | Yes        | Yes                | No             | Yes           | Yes         | No  |
| fexec-charset     | Maybe             | No           | No              | No         | No                 | Yes            | Yes           | No          | No  |
| setlocale("name") | Maybe             | Maybe        | Yes             | No         | Yes                | No             | Maybe         | Yes         | Yes |
| setlocale("")     | Maybe             | Maybe        | Yes             | Yes        | Yes                | No             | Maybe         | Yes         | Yes |
|                   |                   |              |                 |            |                    |                |               |             |     |

* Can use existing source code as it is, no modifications required.
* No recompilation necessary; can use existing binaries.
* Can output any string of text, not just hardcoded string literals.
* A single binary can output different character sets.
* Compilation does not require extra files.
* Running does not require extra files.
* Running does not require special environment variables. "Root" means
  that special environment variables are necessary unless the user has
  root access to install into the system directories.
* Can reverse the mapping so that a program which uses an 8-bit code
  internally will instead output Unicode.
* A program can simultaneously use both input (reverse mapping) and
  output (forward mapping).




### Option 0: iconv -t ./ruthyn.charmap
The simplest usage is to pipe the output from a program that emits
Unicode into `iconv`, which can read the charmap file directly and
convert the output to RUTHYN. 

The only file needed is ruthyn.charmap. The gconv module is not used. 

```bash
some_unicode_program | iconv -t ./ruthyn.charmap
```

<ul>

**Important note!** iconv only reads charmap files if they contain at
least one slash ('/'). 

</ul>


## Option 1: gcc -fexec-charset=ruthyn 
To get the source compiled with desired custom code page used for
string literals coding the following command line can be used as an
example:

```bash
GCONV_PATH=../gconv gcc -fexec-charset=ruthyn -c -o main.o main.c
```

where `../gconv` is the directory the custom module is installed in
and `ruthyn` is the name or alias of the custom code page implemented
by the module.

Note that when compiling this way, the gconv files are _not_ needed at
runtime, only compilation. Also note that the C file should not use
setlocale nor wide characters.

#### Example source code

Please see the file [ruthyn-example.c](ruthyn-example.c) for a program
with literal strings encoded in UTF-8 that output as the custom code
page when compiled as described above. You may use `make test` to
compile the example and run it.

### Option 2: setlocale(LC_CTYPE,"name")

### Option 3: setlocale(LC_CTYPE,"")

