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

############################
##   PUBLIC SUBROUTINES   ##

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

###########################
##   CLASS SUBROUTINES   ##

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

#############################
##   PRIVATE SUBROUTINES   ##

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

=encoding utf8

=head1 Nome

SpamCatcher - Identificador de emails de SPAM

=head1 SINOPSE

  use SpamCatcher;

  my @hams = glob('app/ham/*');
  my @spams = glob('app/spam/*');

  my $spam;

  # Inicializar e registar os ficheiros passados como argumento
  $spam = SpamCatcher->new(\@hams,\@spams);

  # OU

  # Inicializar, mostrar grau de confiança e registar os ficheiros passados como argumento
  #$spam = SpamCatcher->new(\@hams,\@spams, 1);

  # teria como output algo semelhante a:
  # Confiabilidade (4): 0.977551020408163 (1916 em 1960)
  # Confiabilidade (3): 0.98265306122449 (1926 em 1960)
  # Confiabilidade (2): 0.977040816326531 (1915 em 1960)
  # Confiabilidade (1): 0.976020408163265 (1913 em 1960)
  # Confiabilidade (0): 0.971938775510204 (1905 em 1960)

  # Construir a base de dados com os ficheiros passados ao inicializador
  $spam->learn_dataset();

  # Verificar se um email é SPAM
  if($spam->is_spam('app/ham/00027.c9e76a75d21f9221d65d4d577a2cfb75')){
    print "is spam\n"
  }else{
    print "is not spam\n"
  }


=head1 DESCRIÇÃO

O Spam Catcher permite identificar se um email é SPAM.

O módulo necessita que lhe sejam fornecidos vários emails previamente reconhecidos como SPAM ou HAM (não-SPAM). Esses emails são usados para conseguir prever se um email é SPAM.

Ao observar a taxa de sucesso do módulo usando o algoritmo K-Fold, o módulo reconheceu emails de HAM e SPAM com uma taxa de sucesso superior a 97%.



=head1 SUBROTINAS

=head2 EXPORT

Nada é exportado de forma implícita/predefinida.

=head2 EXPORT_OK

=head3 file_to_normalized_string

Recebe como argumento um nome de ficheiro.

Abre o ficheiro cujo nome foi passado como argumento, normaliza o seu conteúdo e devolve-o na forma de uma string.

=head3 word_frequency

Recebe um texto (string) como argumento. Este texto deve ter sido previamente normalizado usando L<file_to_normalized_string|/"file_to_normalized_string">.

Devolve uma hash cujas chaves são as palavras encontradas no texto e os valores são as correspondentes frequências absolutas.

=head3 debug_normalize_file

Recebe uma referência para um array com nomes de ficheiro e uma directoria (string) (sem C</> no fim).

Cria uma versão normalizada do ficheiro original, com o mesmo nome, na directoria indicada.

=head2 SUBROTINAS DE INSTÂNCIA

=head3 new

Recebe como argumentos:

=over

=item 1. Referêcia para uma lista com os nomes de ficheiro dos emails pre-identificados como HAM;

=item 2. Referêcia para uma lista com os nomes de ficheiro dos emails pre-identificados como SPAM;

=item 3. (opcional, falso por predefinição) Valor de verdade que indica se deve ser executada a subrotina de verificação do grau de confiança do C<SpamCatcher>.

=back

Cria uma nova instância de C<SpamCatcher> que usará os ficheiros designados para I<aprender> a identificar emails.

Caso o terceiro argumento tenha um valor verdadeiro, é executada a subrotina de verificação do grau de confiança do C<SpamCatcher>.

=head3 learn_dataset

Recebe um argumento (opcional e falso por predefinição) que indica se o ficheiro temporário do Naive Bayes deverá ser ignorado.

Se o ficheiro temporário existir e puder ser usado, é carregado esse ficheiro, ficando a instância rapidamente pronta a reconhecer emails.

Se o ficheiro temporário não existir ou não puder ser usado, todos os ficheiros são normalizados e as suas frequências absolutas adicionadas à instância de C<Algorithm::NaiveBayes>. Depois disso as frequências são preparadas para serem utilizadas na classificação de emails. Por fim o estado do C<Algorithm::NaiveBayes> é guardado num ficheiro temporário para poder ser directamente recuperado e acelerar as próximas execuções desta subrotina.

=head3 confidence_level

Não recebe argumentos.

Executa o método K-Fold com 5 blocos (a distribuição dos emails pelos blocos é aleatória para instâncias diferentes de C<SpamCatcher>):

=over

=item 1. Aprende a identificar emails usando os blocos 1 a 4 e verifica a percentagem de emails do 5.º bloco que classificou com sucesso.

=item 2. Aprende a identificar emails usando os blocos 1, 2, 3 e 5 e verifica a percentagem de emails do 4.º bloco que classificou com sucesso.

=item 3. Aprende a identificar emails usando os blocos 1, 2, 4 e 5 e verifica a percentagem de emails do 3.º bloco que classificou com sucesso.

=item 4. Aprende a identificar emails usando os blocos 1, 3, 4 e 5 e verifica a percentagem de emails do 2.º bloco que classificou com sucesso.

=item 5. Aprende a identificar emails usando os blocos 2, 3, 4 e 5 e verifica a percentagem de emails do 1.º bloco que classificou com sucesso.

=back

A informação sobre confiança é mostrada no ecrã.

A subrotina devolve C<undef>.

=head3 is_spam

Recebe como argumento um nome de ficheiro.

Computa as frequências absolutas das palavras contidas no ficheiro cujo nome foi passado como argumento, questiona a instância de C<Algorithm::NaiveBayes> sobre a probabilidade de o email ser de SPAM.

Um email é de SPAM quando o C<Algorithm::NaiveBayes> devolve uma probabilidade de ser SPAM de mais de 50% e o valor da probabilidade de ser SPAM é maior que o valor da probabilidade de ser HAM.


=head1 REGRAS DA MAKEFILE

Existem algumas regras adicionais na makefile do projecto:

=over

=item * C<application>: executa a aplicação de exemplo (é necessário extrair o tar.bz2 com os datasets)

=item * C<alldoc>: gera o ficheiro README.pod e uma versão do relatório perldoc em HTML (com índice)

=item * C<cleandoc>: remove os ficheiros gerados pela regra htmlreport

=back

=head1 DEPENDÊNCIAS EXTERNAS

=over

=item * C<Lingua::Jspell> com o dicionário Português ("port") instalado;

=item * C<Text::RewriteRules>.

=item * C<Lingua::EN::StopWords> tem palavras que não contribuem para decisão entre HAM e SPAM;

=item * C<Lingua::Stem> é uma dependência do C<Lingua::EN::StopWords>;

=item * C<Algorithm::NaiveBayes> implementa o algoritmo Naive Bayes, permite inserir as frequências absolutas das palavras e obter valores de previsão para classificar emails;

=item * C<HTML::Strip> Remove tags HTML dos emails;

=item * C<Mail::Internet> Remove cabeçalhos dos emails.

=back

=head1 AUTORES

  B. Ferreira E<lt>chalkos@chalkos.netE<gt>
  M. Pinto E<lt>mcpinto98@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2015 by B. Ferreira and M. Pinto

This program is free software; licensed under GPL.

=cut
