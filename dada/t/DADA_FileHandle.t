#!/usr/bin/perl
use strict;
use warnings;

use lib qw(./ ./DADA/perllib
./t
);

use Test::More qw(no_plan);

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 
$DADA::Config::FILE_CHMOD = 0660;

use DADA::FileHandle;

sub f
{
  my $f = shift;
  my $d = "test_only_dada_files/t.FileHandle";
  if (!-d $d) {
    mkdir($d) || die $!;
  }
  return "$d/$f"
}

sub t1;
sub t2;
sub t3;
sub t4;

my($f1, $f2);
my($fh1, $fh2);
my $ret;

unlink(glob(f("*")));
$f1 = f("test");

use constant DADAFH => 'DADA::FileHandle';

$fh1 = t1("open file (w0)", DADAFH, 'new', $f1, 'w0');
$ret = t2("write file", $fh1, 'print', "foo\nbar\n");
$ret = t2("close file", $fh1, 'close');
$ret = t2("read file", $fh1, 'getline');
is($ret, undef, "read file: fail");

$fh1 = t1("open file (r)", DADAFH, 'new', $f1, 'r');
is($fh1->getline(), "foo\n", "read file");
is($fh1->getline(), "bar\n", "read file");
$ret = t2("close file", $fh1, 'close');

$fh1 = t1("open file (w+)", DADAFH, 'new', $f1, 'w+');
$ret = t2("read file", $fh1, 'getline');
is($ret, undef, "read file: empty");
$ret = t2("write file", $fh1, 'print', "bla\n");
$ret = t2("seek file", $fh1, 'seek', 0, SEEK_SET);
is($fh1->getline(), "bla\n", "read file");
$fh2 = t4("locked file", DADAFH, 'new', $f1, 'r');
$ret = t2("close file", $fh1, 'close');

$DADA::Config::HTML_CHARSET = 'utf16';
$fh1 = t1("open file (wb)", DADAFH, 'new', $f1, 'wb');
$ret = t2("write file", $fh1, 'print', "\xfe\xff\x00\x44\x00\x41\x00\x44\x00\x41");
$ret = t2("close file", $fh1, 'close');
$fh1 = t1("open file (rh)", DADAFH, 'new', $f1, 'rh');
$ret = $fh1->getline();
is($ret, 'DADA', 'utf16');
$ret = t2("close file", $fh1, 'close');

$fh1 = t1("new file (1)", DADAFH, 'new', $f1);
$ret = t3("lock file (1)", $fh1, 'lock', 100);
$fh1 = t1("open file (1:r1)", $fh1, 'open', 'r1');
$ret = t3("lock file (1)", $fh1, 'lock', 100);
$fh2 = t1("open file (2:r1)", DADAFH, 'new', $f1, 'r1');
$ret = t4("lock file (2)", $fh2, 'lock', 100);
$ret = t2("unlock file (1)", $fh1, 'unlock');
$ret = t3("lock file (2)", $fh2, 'lock', 100);
$ret = t2("close file (2)", $fh2, 'close');
$ret = t2("close file (1)", $fh1, 'close');
$fh1 = t1("open file (1:r)", DADAFH, 'new', $f1, 'r');
$ret = t2("lock file (1)", $fh1, 'lock', 1000);
$ret = t2("close file (1)", $fh1, 'close');


our $err = undef;

sub t1
{
  my  $txt = shift;
  my  $ref = shift;
  my  $sub = shift;
  diag("--> next: $txt");
  my $arg = shift;
  $err = undef;
  my $ret = $ref->$sub($arg, sub { $err = shift; }, @_);
  diag((defined($ret) ? $ret : "undef") . ($ref ne DADAFH and $ref->can('getname') ? " (" . $ref->getname() . ")" : ""));
  is($err, undef, $txt);
  return $ret;
}

sub t2
{
  my $txt = shift;
  my $ref = shift;
  my $sub = shift;
  $! = undef;
  diag("--> next: $txt");
  my $ret = $ref->$sub(@_);
  diag((defined($ret) ? $ret : "undef") . ($ref ne DADAFH and $ref->can('getname') ? " (" . $ref->getname() . ")" : ""));
  is($! ? $! : undef , undef, $txt);
  return $ret;
}

sub t3
{
  my $txt = shift;
  my $ref = shift;
  my $sub = shift;
  diag("--> next: $txt");
  my $ret = eval { $ref->$sub(@_); };
  diag((defined($ret) ? $ret : "undef") . ($ref ne DADAFH and $ref->can('getname') ? " (" . $ref->getname() . ")" : ""));
  isnt($ret ? $ret : undef, undef, $txt);
  return $ret;
}

sub t4
{
  my $txt = shift;
  my $ref = shift;
  my $sub = shift;
  diag("--> next: $txt");
  my $ret = eval { $ref->$sub(@_); };
  diag((defined($ret) ? $ret : "undef") . ($ref ne DADAFH and $ref->can('getname') ? " (" . $ref->getname() . ")" : ""));
  is($ret ? $ret : undef, undef, $txt);
  return $ret;
}
