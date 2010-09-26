package DADA::FileHandle;

use strict;

use IO::File;
our @ISA = qw(IO::File);

use Fcntl qw(
	:flock
	LOCK_EX
	LOCK_SH
	SEEK_SET
	SEEK_CUR
	SEEK_END
);
our @EXPORT = qw(
	LOCK_EX
	LOCK_SH
	SEEK_SET
	SEEK_CUR
	SEEK_END
);

use Time::HiRes qw(time usleep);
use constant FLOCK_WAIT => 500;
use constant FLOCK_SLEEP => 100;

use Carp qw(carp croak);


sub new
{
	my $class = shift;
	
	my $file = shift;
	croak("missing file") unless $file;
	
	my $self = $class->SUPER::new();
	${*self}{dada_file} = $file;
	bless $self, $class;
	
	return $self->open(@_) if (@_);
	return $self;
}

sub open
{
	my ($self, $mode, $errhandler) = @_;
	croak("missing mode") unless $mode;
	
	my($openmode, $binmode) = ($mode =~ /^([rwa][+]?)([buh])?$/);
	croak("invalid mode $mode") unless $openmode;
	
	my $file = ${*self}{dada_file};
	
	sub _err {
		$self->close();
		$errhandler->(@_) if $errhandler;
		return undef;
	}
	
	my $fh = $self->SUPER::open($file, $openmode);
	return _err("failed to open $file ($openmode): $!") unless $fh;
	
	if ($binmode) {
		if ($binmode eq "b") {
			$self->binmode(":raw") ||
				return _err("failed to set binary encoding for $file: $!");
		}
		elsif ($binmode eq "u") {
			$self->binmode(":encoding(utf8)") ||
				return _err("failed to set UTF-8 encoding for $file: $!");
		}
		elsif ($binmode eq "h") {
			$self->binmode(":encoding(" . $DADA::Config::HTML_CHARSET . ")") ||
				return _err("failed to set HTML_CHARSET encoding for $file: $!");
		}
	}
	
	# Return early on Solaris since locking seems to be broken on 
	# some systems (cf. description of lockf implementation
	# in perldoc -f flock).  BTW:  This seems to be fixed at least
	# on 'SunOS x 5.10 Generic_139556-08 i86pc i386 i86pc'
	return $self if $^O eq 'solaris';
	
	if ($openmode eq 'r') {
		$self->flock(LOCK_SH) ||
			return _err("failed to flock $file (sh): $!");
	}
	else {
		$self->flock(LOCK_EX)  ||
			return _err("failed to flock $file (ex): $!");
	}
	return $self;
}

sub flock
{
	my($self, $op) = @_;
	my $stop = time() + FLOCK_WAIT / 1000;
	do {
		return 1 if flock($self, $op | LOCK_NB);
		usleep(FLOCK_SLEEP);
	} while (time() < $stop);
	return 0;
}

1;
