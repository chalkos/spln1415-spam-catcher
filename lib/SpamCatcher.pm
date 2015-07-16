package SpamCatcher;

use 5.020002;
use strict;
use warnings;
use utf8;

use Lingua::Jspell;
use HTML::Strip;
use Mail::Internet;
use Algorithm::NaiveBayes;

use Data::Dumper;

require Exporter;

our @ISA = qw(Exporter);

# o que se pode importar individualmente
#our @EXPORT_OK = qw( );

our $VERSION = '0.01';

########################
## PUBLIC METHODS

sub new {
  my ($class,$files) = @_;
  my $self = bless {
    # 'SpamCatcher' => {},
    # 'dict' => Lingua::Jspell->new("eng"),
    'nb' => Algorithm::NaiveBayes->new,
    'files' => $files,
  }, $class;
  $self->network_learning();
}

sub check_email {
  my ($self,$filename) = @_;

  open(my $in, "<", $filename) or die "cannot open '$filename': $!";

  my $body = normalize_email($in);
  close($in);

  print "############ $filename\n";

  return $body;
}

sub network_learning {
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

    for (my $b = 0; $b < 5; $b++) {
      if ($b != $count) {

        my $box = $tests[$b];
        foreach my $filename (@$box) {
          my $body = $self->check_email($filename);
          my $words_count = normalize_body($body);

          my $type = $self->{files}{$filename};
          if ($type=~ /ham/) {
            $self->{nb}->add_instance(attributes => $words_count, label => 'ham');
          } else {
            $self->{nb}->add_instance(attributes => $words_count, label => 'spam');
          }
        }
        print $count, "\n";
      }
    }
    $self->{nb}->train();

    my $box = $tests[$count];
    foreach my $filename (@$box) {
      my $body = $self->check_email($filename);
      my $words_count = normalize_body($body);

      my $type = $self->{files}{$filename};
      # if ($type=~ /ham/) {
      #   ;
      # } else {
      #   ;
      # }

      # testa cada email
      # obtém valores e altera confiabilidade
    }
    $count--;
  }
  $self->{nb}->new();
}


#######################
## PRIVATE METHODS   ##

sub remove_html_tags {
  my $text = shift;

  my $hs = HTML::Strip->new();
  my $clean_text = $hs->parse( $text );

  return $clean_text;
}

sub normalize_email {
  my $text = shift;

  my $email = Mail::Internet->new($text);

  $email->tidy_body();
  $email->remove_sig();

  my $body = $email->body();
  my $c_type = $email->get('Content-Type');

  $body = join('', @$body);

  $body = remove_html_tags($body) if( defined($c_type) && index($c_type,"text/html") == 0);

  return $body;
}

sub normalize_body {
  my $body = shift;
  my $count = ();

  $body = lc($body);
  $body =~ s/[^a-z']/ /g;

  my @words = split(' ', $body);

  $count->{$_}++ for(@words);

  return $count;
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
