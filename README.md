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
  to create modules for different character sets. The old .c and .h
  files have been removed as they are now automatically generated.
  
* The module can be dynamically loaded by calling GNU glibc's
  `setlocale()` function.[^†]

* Many programs will not need to be recompiled if they already use
  `setlocale` and wide-character I/O (`wprintf`).[^†]

* Strings can be dynamically generated, not just hardcoded literals.[^†]

* Can use the POSIX standard `iconv` program to convert files
  bidirectionally or as a filter in a pipeline to convert Unicode to
  the character set. There is no need to compile a gconv module at all
  as iconv can read charmap files directly.

[^†]: Requires setting an environment variable: `LANG=ruthyn`.
	Additionally, If the module is not installed in the system
	directory (e.g., /usr/lib/x86_64-linux-gnu/gconv/), then an
	additional environment variable must be set:
	`GCONV_PATH=/usr/local/lib/gconv/`.

## Installation

<blockquote>
First: Do you really need to install? The charmap file can be used as
is with iconv, no installation required. See Usage below.
</blockquote>

With that out of the way, installation is a piece of cake:

```bash
make
sudo make install
```

To uninstall the module:

```bash
make uninstall
```

### Installation without root access

By default the module gets installed to the system directory (e.g,
`/usr/lib/$(gcc -dumpmachine)/gconv`). If you do not want to install
system wide, you can set the `GCONVDIR` variable to any directory when
installing or uninstalling:

```
make  GCONVDIR=~/.local/lib/gconv  install
```

Note that you'll need to set the `GCONV_PATH` environment variable to
the same directory when running programs that use that module.

``` bash
export GCONV_PATH=$HOME/.local/lib/gconv
./myprog
```


## Usage

There are multiple ways in which these files can be used which offer
different benefits. 

0. **iconv charmap**: 
   * Simplest method. 
   * Requires piping the output from a program into iconv.
1. **fexec-charset**: 
   * Binary can run on a machine without additional files installed.
   * Most restricted in abilities: literal strings only.
   * Sufficient for many tasks.
2. **setlocale("")**: 
   * Most complex.
   * Can handle input and output conversion simultaneously.
   * The "[correct](https://pubs.opengroup.org/onlinepubs/9699919799/functions/setlocale.html)" 
	 way to use a different character set.
   * Many programs already use `setlocale` and will magically work.
   
All methods support "forward mapping", that is, they convert a
program's output from Unicode to an 8-bit character set.

### Table of differences between options

| Option Name       | Source code as is | No recompile | Dynamic strings | One binary | Compiles w/o files | Runs w/o files | Runs w/o vars | Reverse map | I & O |
|-------------------|-------------------|--------------|-----------------|------------|--------------------|----------------|---------------|-------------|-------|
| iconv charmap     | Yes               | Yes          | Yes             | Yes        | Yes                | No             | Yes           | Yes         | No    |
| fexec-charset     | Maybe             | No           | No              | No         | No                 | Yes            | Yes           | No          | No    |
| setlocale("")     | Maybe             | Yes          | Yes             | Yes        | Yes                | No             | *Root*        | Yes         | Yes   |

<details><summary>Click to show table key</summary>

* **Source code as is**: 
  Can use existing source code as it is, no modifications required.
* **No recompile**: 
  No recompilation necessary; can use existing binaries.
* **Dynamic strings**: 
  Can output any string of text, not just hardcoded string literals.
* **One binary**: 
  A single executable binary can output different character sets.
* **Compiles w/o files**: 
  Compilation does not require extra files.
* **Runs w/o files**: 
  Running does not require extra files.
* **Runs w/o vars**: 
  Running does not require special environment variables such as `LANG` or `GCONV_PATH`. 
* **Reverse map**: 
  Can reverse the mapping either for input or so that a program which
  uses an 8-bit code internally will instead output Unicode.
* **I & O**: 
  A program can simultaneously use both input (mapping from
  8-bit character set to Unicode) and output (Unicode to 8-bit
  character set).
* "*Root*" means "YES" if the user has root access to install
  into the system directories, otherwise it means "NO".
</details>



### Option 0: iconv -t ./ruthyn.charmap
```bash
some_unicode_program | iconv -t ./ruthyn.charmap
```

The simplest usage is as a pipeline filter using iconv. This has the
benefit of convenience because it does not require compiling anything.
For example:

``` bash
some_unicode_program | iconv -t ./ruthyn.charmap > /dev/lcd

```

The only file needed is ruthyn.charmap. The gconv module is not used. 

The downside is that the charmap file must be explicitly invoked
whenever the program is run. 

<ul>

**Tip:** iconv only reads charmap files if they contain at
least one slash ('/'). 

</ul>

#### Testing

Run `make test-iconv-charmap`. That target uses three testdata files
to confirm that iconv is working correctly with ruthyn.charmap.

<details>

  1. tests/testdata/RUTHYN-HD44780..UTF8
	 A file containing all characters in the Ruthyn characterset.
	 Encoded in UTF-8.

  2. tests/testdata/RUTHYN-HD44780
	 Same as above, but encoded in the Ruthyn characterset.

  3. tests/testdata/RUTHYN-HD44780-sample.u8
	 A sample presentable to the user to demonstrate functionality.
	 Encoded in UTF-8.

Note that file 1 can be transformed into file 2, but trying the
reverse will not be exact. This is because multiple UCS characters can
map to a single Ruthyn encoding.

For example, both U+0413 and U+0490 are encoded as the byte 0xA1:

	<U0413>		/xA1		% CAPITAL_H (Г)
	<U0490>		/xA1		% CAPITAL_G (Ґ)

The UCS character listed first in the charmap file will be used when
mapping in reverse.

</details>


### Option 1: gcc -fexec-charset=ruthyn 

After installing the gconv module, you may compile a program's C
source code so that it outputs text from literal strings in a custom
code page.

```bash
gcc -fexec-charset=ruthyn -c -o main.o main.c
```

Where `ruthyn` is the name or alias of the custom code page
implemented by the module. If you have installed the module in a
non-default directory, you must also set `GCONV_PATH` to the same
directory. For example, `GCONV_PATH=~/.local/lib/gconv gcc -fexec...`.

When compiling this way, the gconv files are needed during
compilation, but do _not_ need to be installed on the machine that
will be running the binary.


Note that the C source must embed the Unicode text as plain C literal
strings and should not use setlocale nor wide characters. 

The benefit of this method is that the resulting executable does not
require any external files. The drawback is inflexibility: any strings
which need to be printed in ruthyn must be hardcoded in the C program.
Also, this method can only convert from unicode to ruthyn, not
vice-versa.

#### Example source code

Please see the file [ruthyn-example.c](examples/ruthyn-example.c) in
the examples directory for a program with literal strings encoded in
UTF-8 that output as the custom code page when compiled as described
above. You may use `make test` to compile the example and run it.

### Option 2: setlocale(LC_CTYPE,"")

Install the gconv module systemwide using 'make install', so ruthyn
can be used automatically with (almost) any program without having to
recompile.

	 export LANG=ruthyn
	 some_unicode_program > output-to-hd44780

XXX benefits
XXX costs


### Option 3: setlocale(LC_CTYPE,"name")

Similar to option 2, but hardcoded to the specific character set. 
[XXX fill this in; why do this at all? avoid LANG variable]. 


