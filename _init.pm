package _init;
use warnings;
use strict;
use feature ':5.10';
use POSIX qw(locale_h); BEGIN { setlocale(LC_MESSAGES,'en_US.UTF-8') } # avoid UTF-8 in $!

use lib 'perl/lib/perl5';   # eval $(perl -Mlocal::lib=perl)

# use Inline Config => DIRECTORY => 'var/Inline/';

use constant LOCK_WAIT => 15; # sec
use constant CALLER_SUB => 3;

use Narada::Lock qw( shared_lock unlock );
BEGIN { shared_lock(LOCK_WAIT) or do {warn "can't get bootstrap lock\n"; exit} }

use Narada::Config qw( get_config get_config_line set_config );
use Narada::Log qw( $LOG );
use List::Util qw( any );

$::SIG{__WARN__}  = sub {
    my $s = $_[0]; $s =~ s/\n\z//xms; $LOG->WARN($s);
};
$::SIG{__DIE__}   = sub {
    # work around https://github.com/kraih/mojo/issues/774
    return if any {defined && $_ eq '(eval)'} (caller 1)[CALLER_SUB], (caller 2)[CALLER_SUB];
    my $s = $_[0]; $s =~ s/\n\z//xms; $LOG->ERR($s);
};

if(!$^C){ $LOG->INFO('started') };  # work around 'too late for INIT{}' with plackup & hypnotoad
END     { $LOG->INFO('finished') }  # use `plackup -L Delayed` or END{} will run twice

my @EXPORT = qw(
    &shared_lock &unlock
    &get_config &get_config_line &set_config
    $LOG
);


sub import {
    no strict 'refs';
    for (map {substr$_,1} grep {/\A\&/xms} @EXPORT) {
        *{"${\scalar caller}::$_"} = \&{$_};
    }
    for (map {substr$_,1} grep {/\A\$/xms} @EXPORT) {
        *{"${\scalar caller}::$_"} = \${$_};
    }
    return;
}


1;
