perlmodop
=========

Vim plugin for opening Perl modules from inside Perl code.

Usage:
In your .vimrc file, add the following line:

`map go :call perlmodop#OpenPerlSourceFile()<CR>`

Then, when editing a Perl file, navigate your cursor to a line with a package name:

```perl
#!/usr/bin/perl

use Data::Dumper;
...
```

Type "go" and the package (in this case "Data::Dumper") will be opened in a new tab to the right of your current tab.
If multiple package names exist on this line, each will be opened in the order that they appear on the line.
