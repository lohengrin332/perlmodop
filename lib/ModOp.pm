package ModOp;

use Moose;
use Try::Tiny;

try {
    # bomb out so we don't try to add a non-existant path to @INC, and won't try to use a non-existant file
    die unless($ENV{PROPRIETARY_VIM_PATH} && -r "$ENV{PROPRIETARY_VIM_PATH}/lib/ModOp/ProprietaryRole.pm");
    unshift(@INC, "$ENV{PROPRIETARY_VIM_PATH}/lib");
    with qw(
        ModOp::ProprietaryRole
    );
} catch {
    # Do nothing
};

has 'curwin' => ( is => 'rw', required => 1, );
has 'debug'  => ( is => 'rw', default => 0, );

sub getFilesUnderCursor {
    my $self = shift;

    my ($row, $col) = $self->curwin->Cursor();
    my $line = $self->curwin->Buffer->Get($row);

    return $self->getModulesFromLine($line);
}

sub getModulesFromLine {
    my $self = shift;
    my $line = shift;

    my @parts = $self->splitLineToParts($line);

    my @modules;
    for my $part(@parts) {
        push(@modules, $part) unless($part =~ m/\A(use|require|extends|parent|isa|with|qw)\z/);
    }

    my @files;
    for my $module(@modules) {
        my $file_name = $self->getFileNameFromModule($module);
        my $full_file_name = $self->getFilePath($file_name);
        push(@files, $full_file_name) if($full_file_name && -r $full_file_name);
    }

    return @files;
}

sub splitLineToParts {
    my $self = shift;
    my $line = shift;

    my @parts;
    # split the line on characters which are ineligible for module names
    for my $part(split(qr{[^A-Za-z0-9_:]+}, $line)) {
        VIM::Msg($part) if($self->debug);
        # confirm that the part is a valid module name
        push(@parts, $part) if($part =~ m{\A [A-Z_a-z] [0-9A-Z_a-z]* (?: :: [0-9A-Z_a-z]+)* \z}x);
    }

    return @parts;
}

sub getFileNameFromModule {
    my $self = shift;
    my $module = shift;

    return join('/', split('::', $module)) . ".pm";
}

sub getFilePath {
    my $self = shift;
    my $file_name = shift;

    for my $dir($self->getINC) {
        return "$dir/$file_name" if(-f "$dir/$file_name");
    }

    VIM::Msg("File $file_name not found in \@INC") if($self->debug);
    return undef;
}

sub getINC {
    my $self = shift;

    return @INC;
}

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


1;
