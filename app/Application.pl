use strict;
use utf8::all;
use SpamCatcher;

use Data::Dumper;

my @hams = glob('app/ham/*');
my @spams = glob('app/spam/*');

my $spam = SpamCatcher->new(\@hams,\@spams, 1);
#my $spam = SpamCatcher->new(\@hams,\@spams);

$spam->learn_dataset();

if($spam->is_spam('app/ham/00027.c9e76a75d21f9221d65d4d577a2cfb75')){
  print "is spam"
}else{
  print "is not spam"
}
print "\n";
