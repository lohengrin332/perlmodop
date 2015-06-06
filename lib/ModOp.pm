package ModOp;

use Moose;

=head1 NAME

ModOp.pm

=head1 DESCRIPTION

Used to parse package names into actual package files, then either:
1> Open those files in new VIM tabs.
2> Process those files with "TlistAddFiles" and open a tags window (TlistOpen).

=cut

has 'curwin'    => ( is => 'rw', required => 1, );
has 'debug'     => ( is => 'rw', default  => 0, );

=head2 ModOp::ProprietaryRole

    Allow for customization to include proprietary or private code.

    If, for instance, your organization uses a custom library to manipulate the
    @INC paths, ModOp::ProprietaryRole can be created and added to the default
    Perl path, or PROPRIETARY_VIM_PATH can be defined, getINC and getUseLines
    can be overridden or extended, and that custom @INC path library can be
    called, allowing ModOp to find Perl packages in your custom locations.

=cut
if($ENV{PROPRIETARY_VIM_PATH} && -r "$ENV{PROPRIETARY_VIM_PATH}/lib/ModOp/ProprietaryRole.pm") {
    unshift(@INC, "$ENV{PROPRIETARY_VIM_PATH}/lib");
    with qw(
        ModOp::ProprietaryRole
    );
}

=head2 openSourceFile

    Utilizing the VIM API, find any package names on the current line of Perl
    code and open them in new tabs to the right of the current tab.

=cut
sub openSourceFile {
    my $self = shift;
    my @files = $self->getFilesUnderCursor();
    unless(scalar(@files)) {
        VIM::Msg('No files found') if($self->debug);
        return;
    }
    for my $file(reverse(@files)) {
        VIM::DoCommand("tabedit $file\ntabprevious");
    }
    VIM::DoCommand('tabnext');
}

=head2 loadSourceFile

    Utilizing the VIM API, find any package names on the current line of Perl
    code and load them into the tags list, then open the tags list.
    This requires the "taglist" plugin, found here:
    http://www.vim.org/scripts/script.php?script_id=273

=cut
sub loadSourceFile {
    my $self = shift;
    my @files = $self->getFilesUnderCursor();
    return unless(scalar(@files));
    if(scalar(@files)) {
        VIM::DoCommand('TlistAddFiles ' . join(' ', @files));
    } else {
        VIM::Msg('No files found in @INC');
    }
    VIM::DoCommand('TlistOpen');
}

=head2 getFilesUnderCursor

    Uses the defined curwin to find the line where the cursor currently rests,
    then passes that line to another subroutine for processing.

=cut
sub getFilesUnderCursor {
    my $self = shift;

    my ($row, $col) = $self->curwin->Cursor();
    my $line = $self->curwin->Buffer->Get($row);

    return $self->getPackagesFromLine($line);
}
sub getFileUnderCursor {
    my $self = shift;
    my @files = $self->getFilesUnderCursor;
    return $files[0];
}

=head2 getPackagesFromLine

    Given a line of perl code, find valid package name strings, exclude known
    inclusion verbs (e.g. use/require/parent), pass each package name to other
    subroutines to parse them into actual file paths, then return this list of
    file paths.

=cut
sub getPackagesFromLine {
    my $self = shift;
    my $line = shift;

    my @parts = $self->splitLineToParts($line);

    my @packages;
    for my $part(@parts) {
        push(@packages, $part) unless($part =~ m/\A(use|require|extends|parent|isa|with|qw)\z/);
    }

    my @files;
    for my $package(@packages) {
        my $file_name = $self->getFileNameFromPackage($package);
        my $full_file_name = $self->getFilePath($file_name);
        push(@files, $full_file_name) if($full_file_name && -r $full_file_name);
    }

    return @files;
}

=head2 splitLineToParts

    Split a line into a list of potential package names, excluding characters
    which are not valid as parts of a package name.

=cut
sub splitLineToParts {
    my $self = shift;
    my $line = shift;

    my @parts;
    # split the line on characters which are ineligible for package names
    for my $part(split(qr{[^A-Za-z0-9_:]+}, $line)) {
        VIM::Msg($part) if($self->debug);
        # confirm that the part is a valid package name
        # regex found here: http://blogs.perl.org/users/michael_g_schwern/2011/10/how-not-to-load-a-module-or-bad-interfaces-make-good-people-do-bad-things.html
        push(@parts, $part) if($part =~ m{\A [A-Z_a-z] [0-9A-Z_a-z]* (?: :: [0-9A-Z_a-z]+)* \z}x);
    }

    return @parts;
}

=head2 getFileNameFromPackage

    Convert a Perl package name to a partial file path.

=cut
sub getFileNameFromPackage {
    my $self = shift;
    my $package = shift;

    VIM::Msg("package: $package") if($self->debug);
    $package =~ s{::}{/}g;
    return $package . ".pm";
}

=head2 getFilePath

    Given a partial file path, searh @INC paths for a matching file.

=cut
sub getFilePath {
    my $self = shift;
    my $file_name = shift;

    for my $dir($self->getINC) {
        return "$dir/$file_name" if(-f "$dir/$file_name");
    }

    VIM::Msg("File $file_name not found in \@INC") if($self->debug);
    return undef;
}

=head2 getINC

    Return @INC. This can be overridden or (more appropriately) extended via
    an "around" modifier to pull in extra paths if desired.

    Accepts:
        no arguments

    Returns:
        An array like what would be found in @INC.

=cut
sub getINC {
    my $self = shift;

    my @use_lines = $self->getUseLines;

    my @custom_inc = $self->evalUseLines(@use_lines);

    return @custom_inc;
}

=head2 getUseLines

    Find 'use lib ' lines within the current file, scrub 'FindBin' into the
    actual file name in these lines, and return them.

    This can be overridden or (more appropriately) extended via an 'around'
    modifier to pull in extra use statements if desired.

=cut
sub getUseLines {
    my $self = shift;

    my @raw_use_lines = grep(m/use lib /, $self->curwin->Buffer->Get(1 .. $self->curwin->Buffer->Count()));
    VIM::Msg("raw_use_lines:\n    ".join("\n    ", @raw_use_lines)) if($self->debug);

    my $current_file = VIM::Eval('expand("%:p:h")');

    my @use_lines;

    for my $use_line(@raw_use_lines) {
        VIM::Msg("original use_line: $use_line") if($self->debug);
        if($use_line =~ m/FindBin/) {
            # Replace FindBin::? with appropriate overrides from the VIM API.
            $use_line =~ s{\$FindBin::Bin}{$current_file}g;
            $use_line =~ s{\$FindBin::RealBin}{$current_file}g;
        }
        VIM::Msg("modified use_line: $use_line") if($self->debug);
        push(@use_lines, $use_line);
    }

    return @use_lines;
}

=head2 evalUseLines

    Eval use_lines and return the resultant @INC.
    Will pass $ENV{_PERL5LIB} into the `/usr/bin/env perl` command if it is defined.

    Accepts:
        An array of code to be eval'd, one at a time, within a `try{}`.

    Returns:
        An array representing the resultant @INC after all that was eval'd by `/usr/bin/env perl`.

=cut
sub evalUseLines {
    my $self = shift;
    my @use_lines = @_;

    VIM::Msg("use_lines:\n    ".join("\n    ", @use_lines)) if($self->debug);

    my $code_to_eval = join('', map { qq#try { eval(qq{$_}); };# } @use_lines);

    my $perl5lib_env;
    $perl5lib_env = "PERL5LIB=$ENV{_PERL5LIB}" if(defined($ENV{_PERL5LIB}));

    my @custom_inc = `$perl5lib_env /usr/bin/env perl -e 'use Try::Tiny; $code_to_eval print join("\n", \@INC);'`;
    chomp(@custom_inc);

    VIM::Msg('@INC: ' . join(' - ', @custom_inc)) if($self->debug);

    return @custom_inc;
}


1;
