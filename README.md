Welcome to Simile source code.

For more information about Simile than you could possibly hope to
assimilate, see https://simulistics.com

Simile will build with 'make' on Linux, Windows and MacOS. On Windows
we recommend the Msys2 MinGW64 environment. Otherwise, use a regular
shell.

Simile needs other components to build and run, as listed in the
simile.spec and debian/control files. On Linux, these should be
provided by your distribution's package manager -- if not, try to find
them elsewhere. On MacOS, they can be installed using MacPorts. On
Widows in Msys2, they can be installed using Pacman.

The tricky one is likely to be GNU-Prolog, which is needed for
building. This can be built and installed from its own Github at
didoudiaz/gprolog. It is also possible to build Simile with SWI-Prolog
which has reduced performance but is better for debugging.

Once the make is complete, the script at System/bin/simile will start
the tool. 'make install' will install to standard places. Note this is
not the same as the pre-built binary packages, which are bundled with
some of the required components.

All components very welcome!

