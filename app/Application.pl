use strict;
use utf8::all;
use Lingua::Jspell;

use Data::Dumper;

sub check_email {
 my $file = shift;

 my $in = open($in, "<", $file) or die "cannot open '$file': $!";

 while (<$in>) {

 }
}


my $ham = check_email('app/ham');
my $spam = check_email('app/spam');
