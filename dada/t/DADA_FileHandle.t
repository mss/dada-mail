#!/usr/bin/perl
use strict;
use warnings;

use lib qw(./ ./DADA/perllib ../ ../DADA/perllib ../../ ../../DADA/perllib 
./t
);

use Test::More qw(no_plan);

BEGIN{$ENV{NO_DADA_MAIL_CONFIG_IMPORT} = 1}
use dada_test_config; 

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

sub t1
{
  my  $txt = shift;
  my  $ref = shift;
  my  $sub = shift;
  our $err = undef;
  my $ret = $ref->$sub(@_, sub { $err = shift; });
  is($err, undef, $txt);
  diag($ret);
  return $ret;
}

sub t2
{
  my $txt = shift;
  my $ref = shift;
  my $sub = shift;
  $! = undef;
  my $ret = $ref->$sub(@_);
  is(defined($!) ? $! ? $! : undef : undef, undef, $txt);
  diag($ret);
  return $ret;
}

my($f1, $f2);
my($fh1, $fh2);
my $ret;

$f1 = f("test");
unlink($f1);

use constant DADAFH => 'DADA::FileHandle';

$fh1 = t1("open file (w)", DADAFH, 'new', $f1, 'w');
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
is($ret, undef, "read file: fail");
$ret = t2("write file", $fh1, 'print', "bla\n");
$ret = t2("seek file", $fh1, 'seek', 0, SEEK_SET);
is($fh1->getline(), "bla\n", "read file");

$fh2 = DADAFH->new($f1, 'r');
is($fh2, undef, "locked");

$ret = t2("close file", $fh1, 'close');

$DADA::Config::HTML_CHARSET = 'utf16';
$fh1 = t1("open file (wb)", DADAFH, 'new', $f1, 'wb');
$ret = t2("write file", $fh1, 'print', "\xfe\xff\x00\x44\x00\x41\x00\x44\x00\x41");
$ret = t2("close file", $fh1, 'close');
$fh1 = t1("open file (rh)", DADAFH, 'new', $f1, 'rh');
$ret = $fh1->getline();
is($ret, 'DADA', 'utf16');
$ret = t2("close file", $fh1, 'close');
