package DADA::FileHandle;

use strict;

use IO::File;
our @ISA = qw(IO::File);

use Errno qw(
	EEXIST
);

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
# Return early on Solaris since LOCK_EX locking seems to be broken 
# on some systems (cf. description of lockf implementation
# in perldoc -f flock).  BTW:  This seems to be fixed at least
# on 'SunOS x 5.10 Generic_139556-08 i86pc i386 i86pc'
use constant FLOCK_ENABLED => $^O ne 'solaris';

use Carp qw(carp croak);
use constant RETURN => sub { };
use constant CARP   => \&carp;
use constant CROAK  => \&croak;

# TODO: Use ${*$self}{errh} everywhere, override
# print etc., see perldoc File::IO

# usage: new($file, [$errh,] [$mode])
#  * $file is required
#  * $errh is a reference to the error handler
#    to be called when something goes haywire.
#    default: Carp::croak;
#  * if $mode is given, the file is opened, see open
sub new
{
	my $class = shift;
	
	my $file = shift;
	croak("missing file") unless $file;
	my $errh = shift;
	if (defined($errh) && !ref($errh)) {
		unshift(@_, $errh);
		$errh = undef;
	}
	$errh ||= CROAK;
	
	my $self = $class->SUPER::new();
	${*$self}{dada_file} = $file;
	${*$self}{dada_lock} = undef;
	${*$self}{dada_errh} = $errh;
	bless $self, $class;
	
	return $self->open(@_) if (@_);
	return $self;
}

sub DESTROY
{
	my($self) = @_;
	$self->close();
}


sub open
{
	my($self, $mode) = @_;
	croak("missing mode") unless $mode;
	my $file = ${*$self}{dada_file};
	my $errh = ${*$self}{dada_errh};
	
	# mode: r|r+|w|w+|a|a+ [b|u|h] [$t] [l[$t]]
	#  * read, read/write, write, write/read, append, append/read (cf. fopen(3))
	#  * binary, utf8, HTML_CHARSET
	#  * flock timeout (ms), 0 disable flock
	#  * lock before open, optional wait time
	# eg.: open('r+h100l')
	my($openmode, $binmode, $wait, $lock) = ($mode =~ /^([rwa][+]?)([buh])?(\d+)?([l]\d*)?$/);
	croak("invalid mode $mode") unless $openmode;
	$wait = FLOCK_WAIT unless defined $wait;
	
	if (defined($lock)) {
		$lock =~ /^l(\d*)$/;
		my $ret = $self->lock($1 || 0);
		return $ret unless $ret;
	}
	
	sub _err {
		$self->close();
		$errh->(@_) if $errh;
		return undef;
	}
	
	my $fh = $self->SUPER::open($file, $openmode);
	return _err("failed to open $file ($openmode): $!") unless $fh;
	
	chmod($DADA::Config::FILE_CHMOD, $file) ||
		return _err("failed to chmod $file: $!");
	
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
	
	if ($wait) {
		if ($openmode eq 'r') {
			$self->flock(LOCK_SH, $wait) ||
				return _err("failed to flock $file (sh): $!");
		}
		else {
			$self->flock(LOCK_EX, $wait) ||
				return _err("failed to flock $file (ex): $!");
		}
	}
	
	return $self;
}

sub close
{
	my($self) = @_;
	
	$self->unlock();
	
	return -1 unless $self->opened();
	return $self->SUPER::close();
}


sub getname
{
	my($self) = @_;
	return ${*$self}{dada_file};
}


sub flock
{
	return -1 unless FLOCK_ENABLED;

	my($self, $op, $wait) = @_;
	croak("missing op") unless defined $op;
	$wait ||= 0;
	
	my $bang;
	my $stop = time() + $wait / 1000;
	my $done = 0;
	while (!$done) {
		$done = time() > $stop;
		return 1 if flock($self, $op | LOCK_NB);
		$bang = $! * 1;
		usleep(FLOCK_SLEEP * 1000);
	}
	
	$! = $bang;
	
	return 0;
}


sub lock
{
	my($self, $wait) = @_;
	$wait ||= 0;
	
	my $file = ${*$self}{dada_file};
	my $lock = ${*$self}{dada_lock};
	return -1 if defined $lock;
	
	$lock = DADA::FileHandle->new($file . '.lock');
	
	my $stop = time() + $wait / 1000;
	my $done = 0;
	while (!$done) {
		$done = time() > $stop;
		$! = EEXIST;
		next if -f $lock->getname();
		if ($lock->open('a+1')) {
			$lock->seek(0, SEEK_SET);
			next if ($lock->getline());
			$lock->truncate(0);
			$lock->print("$$\n" . gmtime() . "\n");
			${*$self}{dada_lock} = $lock;
			return 1;
		}
		usleep(FLOCK_SLEEP * 1000);
	}
	
	# TODO: Use ${*$self}{errh} here
	croak("failed to lock $file: $!");
	return 0;
}

sub unlock
{
	my($self) = @_;
	
	my $file = ${*$self}{dada_file};
	my $lock = ${*$self}{dada_lock};
	return -1 unless defined $lock;
	
	$lock->close();
	unlink($lock->getname()) ||
		croak("failed to unlock $file: $!");
	
	${*$self}{dada_lock} = undef;
	return 1;
}

1;
