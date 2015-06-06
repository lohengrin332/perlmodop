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


If you happen to be using a version of Perl different from what was compiled into vim (e.g. you run multiple versions of
Perl with perlbrew, etc), you may need to add the following variables and aliases to your environment (assuming vim was
compiled against `/usr/bin/perl`):

```shell
export VIMPERLLIB=$(PERL5LIB= /usr/bin/perl -le 'print join ":", @INC')
alias vim='_PERL5LIB=$PERL5LIB PERL5LIB=${VIMPERLLIB} vim'
```


This will cause the Perl environment run by vim to use the correct libraries, etc when executing the ModOp code, but
use the runtime Perl (i.e. `/usr/bin/env perl`) when determining the `@INC` path to search for library files.


To customize this behavior, you can declare a "PROPRIETARY_VIM_PATH" environment variable to direct the plugin to a Perl lib
directory with a "ModOp::ProprietaryRole" package in it.

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

This package will be included as a Moose::Role, and should be defined as such:

```perl
package ModOp::ProprietaryRole;

use Moose:Role;

around 'getINC' => sub {
    my $orig = shift;
    my $self = shift;
    return($self->$orig(@_), '/some/custom/perl/path');
};

around 'getUseLines' => sub {
    my $orig = shift;
    my $self = shift;
    return($self->$orig(@_), "use lib '/some/custom/perl/path'");
};
```
