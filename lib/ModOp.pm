package ModOp;

use Moo;
use Try::Tiny;

=head1 NAME

ModOp.pm

=head1 DESCRIPTION

Used to parse package names into actual package files, then either:
1> Open those files in new VIM tabs.
2> Process those files with "TlistAddFiles" and open a tags window (TlistOpen).

=cut

=head2 ModOp::ProprietaryRole

    Allow for customization to include proprietary or private code.

    If, for instance, your organization uses a custom library to manipulate the
    @INC paths, ModOp::ProprietaryRole can be created and added to the default
    Perl path, or PROPRIETARY_VIM_PATH can be defined, getINC can be overridden
    or extended, and that custom @INC path library can be called, allowing
    ModOp to find Perl packages in your custom locations.

=cut
try {
    unshift(@INC, "$ENV{PROPRIETARY_VIM_PATH}/lib")
        if($ENV{PROPRIETARY_VIM_PATH} && -r "$ENV{PROPRIETARY_VIM_PATH}/lib/ModOp/ProprietaryRole.pm");
    with qw(
        ModOp::ProprietaryRole
    );
} catch {
    # Do nothing
};

has 'curwin' => ( is => 'rw', required => 1, );
has 'debug'  => ( is => 'rw', default => 0, );

=head2

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

=head2

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

=head2

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

=head2

    Convert a Perl package name to a partial file path.

=cut
sub getFileNameFromPackage {
    my $self = shift;
    my $package = shift;

    return join('/', split('::', $package)) . ".pm";
}

=head2

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

=head2

    Return @INC.  This can be overridden or (more appropriately) extended via
    an "around" modifier to pull in extra paths if desired.

=cut
sub getINC {
    my $self = shift;

    return @INC;
}


1;
