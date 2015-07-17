# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl SpamCatcher.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('SpamCatcher') };

# verificar se os métodos principais estão definidos
can_ok('SpamCatcher', qw(new learn_dataset confidence_level is_spam file_to_normalized_string word_frequency));

isa_ok( SpamCatcher->new([],[]), 'SpamCatcher' );
isa_ok( SpamCatcher->new([],[],0), 'SpamCatcher' );


### Testa frequência de palavras
my $got = SpamCatcher::word_frequency("arroz de pato pato ontem");
my $expected = { 'arroz' => 1, 'de' => 1, 'pato' => 2, 'ontem' => 1, };
is_deeply($got, $expected, ' frequencia de palavras ');

$got = SpamCatcher::word_frequency();
$expected = {};
is_deeply($got, $expected, ' frequencia de palavras ');

done_testing();
