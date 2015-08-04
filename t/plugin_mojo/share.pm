use Mojo::Base -strict;
strict->import;
warnings->import;
utf8->import;
feature->import(':5.10');
use Mojo::Reactor::EV;
use Mojo::Reactor::Poll;
use Mojo::Util qw( monkey_patch );
use Test::Exception;
use Test::MockModule;
use Test::Mojo;
use Test::More;
use Time::HiRes qw( CLOCK_MONOTONIC );
use _init;


### Deterministic time & Mojo timers:
# use t::plugin_mojo::share qw( :TIME );
# Mojo::IOLoop->one_tick;       # move time forward by 0.002 sec
# ff($dur);                     # move time forward by $dur sec

my (@Timers, $Now);

sub _mock_time {
    # should be called only once
    return if defined $Now;
    $Now = 0;

    # return faked current time based on $Now
    my $start = time;
    *CORE::GLOBAL::time = *CORE::GLOBAL::time = sub () { int($start+$Now) };
    state $_hires = Test::MockModule->new('Time::HiRes');
    $_hires->mock(time          => sub ()   { $start+$Now });
    $_hires->mock(clock_gettime => sub (;$) { $_[0] == CLOCK_MONOTONIC() ? $Now : $start+$Now });
    $_hires->mock(gettimeofday  => sub ()   { split qr/[.]/ms, $start+$Now, 2 });

    # fake all timers
    my $next_id = 0;
    state $_r_ev    = Test::MockModule->new('Mojo::Reactor::EV');
    state $_r_poll  = Test::MockModule->new('Mojo::Reactor::Poll');
    for ($_r_ev, $_r_poll) {
        my $_r = $_;
        $_r->mock(timer    => sub {
            if ($_[1] == 0) {
                # do not fake timer for 0 seconds to avoid hang
                return $_r->original('timer')->(@_);
            }
            my $id = 'fake_'.($next_id++);
            push @Timers, {
                type    => 'timer',
                id      => $id,
                start   => $Now,
                self    => $_[0],
                delay   => $_[1],
                cb      => $_[2],
            };
            return $id;
        });
        $_r->mock(recurring=> sub {
            my $id = 'fake_'.($next_id++);
            push @Timers, {
                type    => 'recurring',
                id      => $id,
                start   => $Now,
                self    => $_[0],
                delay   => $_[1],
                cb      => $_[2],
            };
            return $id;
        });
        $_r->mock(again    => sub {
            if ($_[1] !~ /\Afake_(\d+)\z/ms) {
                $_r->original('again')->(@_);
            }
            else {
                my ($timer) = grep { $_->{id} eq $_[1] } @Timers;
                $timer->{start} = $Now;
            }
            return;
        });
        $_r->mock(one_tick => sub {
            # protect against hang with one real timer
            my $id = $_r->original('timer')->($_[0], 0.002, sub {});
            $_r->original('one_tick')->(@_);
            $_r_poll->original('remove')->($_[0], $id);
            # fast-forward time in deterministic way
            ff(0.002);
            return;
        });
    }
    $_r_poll->mock(remove   => sub {
        if ($_[1] !~ /\Afake_(\d+)\z/ms) {
            $_r_poll->original('remove')->(@_);
        }
        else {
            @Timers = grep { $_->{id} ne $_[1] } @Timers;
        }
        return;
    });

    return;
}

# Fast-forward current time ($Now) by $dur seconds, run timers if needed.
sub ff {
    my ($dur) = @_;
    $dur = 0 if $dur < 0;

    @Timers = sort { $a->{start}+$a->{delay} <=> $b->{start}+$b->{delay} } @Timers;
    my $next_at = @Timers ? $Timers[0]{start}+$Timers[0]{delay} : 0;
    $next_at = 0+sprintf '%.5f', $next_at;

    if (!$next_at || $next_at > $Now+$dur) {
        $Now += $dur;
        $Now = 0+sprintf '%.5f', $Now;
        return;
    }

    $dur -= $next_at - $Now;
    $dur = 0+sprintf '%.5f', $dur;
    $Now = $next_at;
    $Timers[0]{cb}->($Timers[0]{self});
    if ($Timers[0]{type} eq 'timer') {
        shift @Timers;
    }
    else {
        $Timers[0]{start} = $Now;
    }
    @_ = ($dur);
    goto &ff;
}


### Mock some config files:
# use t::plugin_mojo::share
#   'log/level' => 'INFO',
#   'title' => 'test title',
#   …
#   ;

my %MOCK_CONFIG;

sub t::plugin_mojo::share::import {
    shift;
    if (grep {$_ eq ':TIME'} @_) {
        @_ = grep {$_ ne ':TIME'} @_;
        _mock_time();
    }
    %MOCK_CONFIG = (%MOCK_CONFIG, @_);

    state $fallback;
    return if $fallback;

    $fallback = \&Narada::Config::get_config;
    monkey_patch 'Narada::Config',  get_config => sub {
        my ($param) = @_;
        return $MOCK_CONFIG{$param} if exists $MOCK_CONFIG{$param};
        return $fallback->(@_);
    };
    monkey_patch '_init',           get_config => \&Narada::Config::get_config;
    monkey_patch __PACKAGE__,       get_config => \&Narada::Config::get_config;
    attributes->import('Narada::Config' => \&Narada::Config::get_config, 'Export');
    return;
}


1;
