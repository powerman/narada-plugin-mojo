package WebSite::validate;
use Mojo::Base -strict;
use Validate::Tiny 1.501 qw( :all );
use Perl6::Export::Attrs;
no warnings qw( experimental::lexical_topic ); ## no critic (ProhibitNoWarnings)   # my $_;


# Validate rules for models
# - using Regexp in 'checks' may occasionally match 'field__func' params
# - when validating JSON remember field values may be of any complex type

# our $Model = {
#     fields => [qw(  )],
#     filters=> [
#         qr/.*/ms        => filter(qw( trim )),
#     ],
#     checks => [
#         [qw(  )]        => is_required(),
#     ],
# };


# Extra validation rules

sub is_datetime :Export {
    use Time::Local qw( timelocal );
    state $DATE = qr/(20\d\d)  -  (0[1-9]|1[012])  -  (0[1-9]|[12]\d|3[01])/xms;
    state $TIME = qr/([01]\d|2[0-3])  :  ([0-5]\d)  :  ([0-5]\d)/xms;
    return sub {
        my ($_) = @_;
        return if !defined || !length;
        return 'Bad datetime format' if !/\A$DATE $TIME\z/mso;
        return 'Bad datetime value'  if !eval{timelocal($6,$5,$4,$3,$2-1,$1)};  ## no critic (ProhibitCaptureWithoutTest)
        return;
    };
}

sub is_gt :Export {
    my ($f) = @_;
    return sub {
        my ($_, $p) = @_;
        return if !defined || !length;
        return "Must be greater than '$p->{$f}'" if $_ le $p->{$f};
        return;
    }
}

sub is_not_null :Export {
    return sub {
        my ($_, $p, $f) = @_;
        return 'Is null' if exists $p->{$f} && !defined;
        return;
    };
}

sub is_scalar :Export {
    return sub {
        my ($_) = @_;
        return if !defined;
        return 'Not a scalar' if ref;
        return;
    };
}

sub is_array :Export {
    return sub {
        my ($_) = @_;
        return if !defined;
        return 'Not an array' if ref $_ ne 'ARRAY';
        return;
    };
}

sub is_hash :Export {
    return sub {
        my ($_) = @_;
        return if !defined;
        return 'Not a hash' if ref $_ ne 'HASH';
        return;
    };
}


1;
