use strict;
use utf8::all;
use SpamCatcher;

use Data::Dumper;


my $spam = SpamCatcher->new();

# print "###########\n";
#my $body = $spam->check_email('app/ham/00001.1a31cc283af0060967a233d26548a6ce');
my $body = $spam->check_email('app/spam/00010.2558d935f6439cb40d3acb8b8569aa9b');

# print "###########\n";
# print Dumper $spam->check_email('app/spam/00001.317e78fa8ee2f54cd4890fdc09ba8176');

# print "###########\n";
# print Dumper $spam->check_email('app/spam/00010.2558d935f6439cb40d3acb8b8569aa9b');


#######
# TODO
# 1- Remove url links from body
# 2- Remove emails from body
# 3- Improve filter of words

$spam->network_learning($body);


