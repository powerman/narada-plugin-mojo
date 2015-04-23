use strict;
use warnings;
use Test::More;
use File::Spec;
use Perl::Critic::Utils qw( all_perl_files );

if ( not $ENV{TEST_AUTHOR} ) {
    my $msg = 'Author test.  Set $ENV{TEST_AUTHOR} to a true value to run.';
    plan( skip_all => $msg );
}

eval { require Test::Perl::Critic; };
plan(skip_all=>'Test::Perl::Critic required to criticise code') if $@;

my $rcfile = File::Spec->catfile( 't', 'build', '.perlcriticrc' );
Test::Perl::Critic->import(
    -profile    => $rcfile,
    -verbose    => 9,           # verbose 6 will hide rule name
);

my @files = grep {!m{perl/|t/|public/|_live.*/}} all_perl_files('.');
plan tests => 0+@files;
for (@files) {
    critic_ok($_);
}
