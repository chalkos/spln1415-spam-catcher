use strict;
use utf8::all;
use SpamCatcher;

use Data::Dumper;

my @fold_ham = glob('app/ham/*');
my @fold_spam = glob('app/spam/*');

my $files = ();

$files->{$_} = 'ham' for(@fold_ham);
$files->{$_} = 'spam' for(@fold_spam);

my $spam = SpamCatcher->new($files);





#print Data::Dumper->Dump(\@test);

#foreach my $x (@test) {
#  print scalar @$x, "\n";
#}

#print Dumper $files;
#print "size of hash:  " . keys( %$files )  . ".\n";
#print "key: $key, value: ${$files}{$key}\n";

# print "###########\n";
#my $body = $spam->check_email('app/ham/00001.1a31cc283af0060967a233d26548a6ce');
#my $body = $spam->check_email('app/spam/00010.2558d935f6439cb40d3acb8b8569aa9b');

# print "###########\n";
# print Dumper $spam->check_email('app/spam/00001.317e78fa8ee2f54cd4890fdc09ba8176');

# print "###########\n";
# print Dumper $spam->check_email('app/spam/00010.2558d935f6439cb40d3acb8b8569aa9b');
