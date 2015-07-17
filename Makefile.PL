use 5.020002;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

sub MY::postamble {
  return q{
application:
	perl -I ./lib app/Application.pl

debug:
	perl -d -I ./lib app/Application.pl

alldoc: README.pod README.html

cleandoc:
	rm -f README.pod
	rm -f README.html

README.pod: lib/SpamCatcher.pm
	podselect $< > $@

README.html: lib/SpamCatcher.pm
	cat $< | pod2html --header --outfile=$@

};
}



WriteMakefile(
    NAME              => 'SpamCatcher',
    VERSION_FROM      => 'lib/SpamCatcher.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
    	'Lingua::EN::StopWords' => 0,
    	'Lingua::Stem' => 0,
    	'Algorithm::NaiveBayes' => 0,
    	'HTML::Strip' => 0,
    	'Mail::Internet' => 0
    	}, # e.g., Module::Name => 1.1
    ABSTRACT_FROM     => 'lib/SpamCatcher.pm', # retrieve abstract from module
    AUTHOR            => 'A. U. Thor <chalkos@nonet>',
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #http://search.cpan.org/perldoc?Module%3A%3ABuild%3A%3AAPI
);
