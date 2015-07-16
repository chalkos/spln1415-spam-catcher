package SpamCatcher;

use 5.020002;
use strict;
use warnings;
use utf8;

use Lingua::Jspell;
use HTML::Strip;
use Mail::Internet;
use Algorithm::NaiveBayes;

use File::Basename qw/basename/;
use File::Path qw/make_path/;

use Lingua::EN::StopWords qw(%StopWords);

use Carp::Assert;

use Data::Dumper;
#$Data::Dumper::Sortkeys = 1;

require Exporter;

our @ISA = qw(Exporter);

# o que se pode importar individualmente
#our @EXPORT_OK = qw( );

our $VERSION = '0.01';

########################
## PUBLIC METHODS

sub new {
  my ($class,$hamfiles,$spamfiles) = @_;

  my $files = {};
  $files->{$_} = 'ham' for(@$hamfiles);
  $files->{$_} = 'spam' for(@$spamfiles);

  my $self = bless {
    # 'SpamCatcher' => {},
    # 'dict' => Lingua::Jspell->new("eng"),
    'nb' => Algorithm::NaiveBayes->new,
    'files' => $files,
  }, $class;

  #debug_normalize_file(['app/spam/00001.317e78fa8ee2f54cd4890fdc09ba8176'], './cache/spam');
#
#  #my $freqs = word_frequency(file_to_normalized_string('app/spam/00001.317e78fa8ee2f54cd4890fdc09ba8176'));
#
#  #print Dumper $freqs;
#
#  #$self->{nb}->add_instance(attributes=>$freqs, label=>'spam');
  #print Dumper $self->{nb};

  #debug_normalize_file($hamfiles, './cache/ham');
  #print "normalizado ham\n";
  #debug_normalize_file($spamfiles, './cache/spam');
  #print "normalizado spam\n";

  #die();

  $self->confidence_level();
  #print Dumper \%x;
}

sub confidence_level {
  my ($self) = @_;

  ################
  # Ciclo para criar box para emails
  my $files_per_box = int(0.20 * keys( %{$self->{files}} ));

  my @tests = ();
  my $i = 0;
  my $box = [];
  foreach my $key (keys( %{$self->{files}} )) {
    if($i == $files_per_box) {
      push @tests, $box;

      $i=0;
      $box = [];
    }
    push(@$box, $key);

    $i++;
  }

  ################
  # Ciclo de teste
  # my ($ham, $spam) = ();
  my $count = 4;
  for (my $t = 0; $t < 5; $t++) {
    $self->{nb} = Algorithm::NaiveBayes->new;

    for (my $b = 0; $b < 5; $b++) {
      if ($b != $count) {

        my $box = $tests[$b];
        foreach my $filename (@$box) {
          my $body = file_to_normalized_string($filename);

          #print Dumper $body;

          my $word_frequency = word_frequency($body);

          #print Dumper $word_frequency;

          my $type = $self->{files}{$filename};

          assert($type eq 'ham' || $type eq 'spam');

          $self->{nb}->add_instance(attributes => $word_frequency, label => $type);
        }
        #print $b, "\n";
      }
    }
    $self->{nb}->train();
    #die(Dumper $self->{nb});
    print "instances: " . $self->{nb}{instances} . "\n";
    #print "trained\n";

    my $box = $tests[$count];
    my ($guess_correct, $guess_fail) = (0,0);
    foreach my $filename (@$box) {
      # testa cada email

      my $isSPAM = $self->is_spam($filename);

      if ( $isSPAM && $self->{files}{$filename} eq 'spam') {
        $guess_correct++;
      } elsif(!$isSPAM && $self->{files}{$filename} eq 'ham'){
        $guess_correct++;
      } else {
        $guess_fail++;
      }
    }

    print "Confiabilidade ($count): " .
        ($guess_correct/($guess_correct+$guess_fail)) .
        "(" . $guess_correct . " em " . ($guess_correct+$guess_fail) . ")\n";

    $count--;
  }
  $self->{nb} = Algorithm::NaiveBayes->new;
}

sub is_spam{
  my ($self, $filename) = @_;

  my $body = file_to_normalized_string($filename);
  my $word_frequency = word_frequency($body);

  my $result = $self->{nb}->predict(attributes => $word_frequency);

  return ($result->{spam} > 0.5 && $result->{spam} > $result->{ham});
}

#######################
## PRIVATE METHODS   ##

sub file_to_normalized_string {
  my ($filename) = @_;

  open(my $in, "<", $filename) or die "cannot open '$filename': $!";

  # remover cabeçalhos de email
  my $email = Mail::Internet->new($in);
  $email->tidy_body();
  $email->remove_sig();

  my $body_array = $email->body();
  my $c_type = $email->get('Content-Type');

  my $text = join('', @$body_array);

  # remover PGP signatures
  #$text =~ s/--==_Exmh_-.*?--==_Exmh_.*?\n//mg;

  # remover tags HTML
  if( defined($c_type) && index($c_type,"text/html") >= 0){
    my $hs = HTML::Strip->new();
    $text = $hs->parse( $text );
  }

  close($in);

  # meter tudo em letras minusculas
  $text = lc($text);

  #remover ainda mais tags HTML (mesmo quando o contenttype nao é html)
  $text =~ s/<(\w+(\b.*?)|\/\w+)>//g;

  # apenas permitir letras e plicas
  $text =~ s/[^a-z']+/ /g;
  $text =~ s/^[ \t\n]+//;
  $text =~ s/[ \t\n]+$//;

  # remover stopwords
  my @words = split ' ', $text;
  $text = join ' ', grep { !$StopWords{$_} && (length $_ > 2)} @words;

  return $text;
}

sub word_frequency {
  my ($text) = @_;
  my @words = split(' ', $text);

  my $count = {};
  $count->{$_}++ for(@words);

  #print Dumper \@words, $count;

  return $count;
}

sub debug_normalize_file{
  my ($filenames, $output_dir) = @_;

  make_path($output_dir);
  unlink glob "$output_dir/*";

  foreach my $filename (@$filenames) {

    my $name = basename($filename);

    open(my $out, '>', "$output_dir/$name") or die "Could not open file '$filename' $!";
    print $out file_to_normalized_string($filename);
    close $out;
  }
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

SpamCatcher - Perl extension for blah blah blah

=head1 SYNOPSIS

  use SpamCatcher;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for SpamCatcher, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

A. U. Thor, E<lt>chalkos@nonetE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by A. U. Thor

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.20.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
