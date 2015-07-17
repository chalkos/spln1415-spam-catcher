package SpamCatcher;

use 5.020002;
use strict;
use warnings;
use utf8;

use HTML::Strip;
use Mail::Internet;
use Algorithm::NaiveBayes;

use File::Basename qw/basename/;
use File::Path qw/make_path/;

use Lingua::EN::StopWords qw(%StopWords);

use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(file_to_normalized_string word_frequency);

our $VERSION = '0.01';

########################
## PUBLIC METHODS

sub new {
  my ($class,$hamfiles,$spamfiles,$kfold) = @_;

  $kfold = 0 if(!defined $kfold);

  my $files = {};
  $files->{$_} = 'ham' for(@$hamfiles);
  $files->{$_} = 'spam' for(@$spamfiles);

  my $self = bless {
    'nb' => Algorithm::NaiveBayes->new,
    'files' => $files,
  }, $class;

  #debug_normalize_file($hamfiles, './cache/ham');
  #print "normalizado ham\n";
  #debug_normalize_file($spamfiles, './cache/spam');
  #print "normalizado spam\n";

  if( $kfold ){
    $self->confidence_level();
  }

  return $self;
}

sub learn_dataset {
  my ($self, $dont_use_cache) = @_;
  $dont_use_cache = 0 if(!defined $dont_use_cache);

  my $savefile = '.NaiveBayesSave';

  if(!$dont_use_cache && -e $savefile){
    $self->{nb} = Algorithm::NaiveBayes->restore_state($savefile);
  }else{
    foreach my $filename (keys %{$self->{files}}) {
      my $word_frequency = word_frequency(
          file_to_normalized_string($filename)
        );

      my $type = $self->{files}{$filename};
      $self->{nb}->add_instance(attributes => $word_frequency, label => $type);
    }
    $self->{nb}->train();

    $self->{nb}->save_state($savefile);
  }

  return undef;
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

  # métdo K-fold (Validação cruzada)
  for (my $t = 0; $t < 5; $t++) {
    $self->{nb} = Algorithm::NaiveBayes->new;

    # aprender com 4 blocos
    for (my $b = 0; $b < 5; $b++) {
      if ($b != $count) {

        my $box = $tests[$b];
        foreach my $filename (@$box) {
          my $body = file_to_normalized_string($filename);
          my $word_frequency = word_frequency($body);
          my $type = $self->{files}{$filename};

          $self->{nb}->add_instance(attributes => $word_frequency, label => $type);
        }
        #print $b, "\n";
      }
    }

    # preparar naive bayes
    $self->{nb}->train();

    # testar com o bloco restante
    my $box = $tests[$count];
    my ($guess_correct, $guess_fail) = (0,0);
    foreach my $filename (@$box) {
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
        " (" . $guess_correct . " em " . ($guess_correct+$guess_fail) . ")\n";

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
  #$text =~ s/<!--.*?-->//g;

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
