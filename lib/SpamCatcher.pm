package SpamCatcher;

use 5.020002;
use strict;
use warnings;
use utf8::all;

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
  my $class = shift;
  my $self = bless {
    'SpamCatcher' => {},
    'dict' => Lingua::Jspell->new("eng"),
    }, $class;
}

sub check_email {
  my ($self,$filename) = @_;

  open(my $in, "<", $filename) or die "cannot open '$filename': $!";

  my $body = normalize_email($in);

  $self->{'SpamCatcher'} = $body;
}

sub network_learning {
  my ($self) = @_;

  #TODO use NaiveBayes
}


#######################
## PRIVATE METHODS

sub remove_html_tags {
  my $text = shift;

  my $hs = HTML::Strip->new();
  my $clean_text = $hs->parse( $text );
  $hs->eof;

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

  $body = remove_html_tags($body) if index($c_type,"text/html")==0;

  return $body;
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
