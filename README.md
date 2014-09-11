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


To customize the behavior of the Perl code, you can declare a "PROPRIETARY_VIM_PATH" environment variable to
direct the plugin to a perl lib directory with a "ModOp::ProprietaryRole" package in it.

Example:

```
$ export PROPRIETARY_VIM_PATH=$HOME/code
$ ls $PROPRIETARY_VIM_PATH -R
    lib

    lib/:
    ModOp

    lib/ModOp:
    ProprietaryRole.pm
```

This package will be included as a Moo::Role, and should be defined as such:

```perl
package ModOp::ProprietaryRole;

use Moo:Role;

around 'getINC' => sub {
    my $orig = shift;
    my $self = shift;
    unshift(@INC, '/some/custom/perl/lib');
    return $self->$orig(@_);
}
```
