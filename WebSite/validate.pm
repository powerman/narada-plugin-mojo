package WebSite::validate;
use Mojo::Base -strict;
use Validate::Tiny 1.501 qw( :all );
use Export::Attrs;


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
        my ($v) = @_;
        return if !defined $v || !length $v;
        return 'Bad datetime format' if $v !~ /\A$DATE $TIME\z/mso;
        return 'Bad datetime value'  if !eval{timelocal($6,$5,$4,$3,$2-1,$1)};  ## no critic (ProhibitCaptureWithoutTest)
        return;
    };
}

sub is_gt :Export {
    my ($f) = @_;
    return sub {
        my ($v, $p) = @_;
        return if !defined $v || !length $v;
        return "Must be greater than '$p->{$f}'" if $v le $p->{$f};
        return;
    }
}

sub is_not_null :Export {
    return sub {
        my ($v, $p, $f) = @_;
        return 'Is null' if exists $p->{$f} && !defined $v;
        return;
    };
}

sub is_scalar :Export {
    return sub {
        my ($v) = @_;
        return if !defined $v;
        return 'Not a scalar' if ref $v;
        return;
    };
}

sub is_array :Export {
    return sub {
        my ($v) = @_;
        return if !defined $v;
        return 'Not an array' if ref $v ne 'ARRAY';
        return;
    };
}

sub is_hash :Export {
    return sub {
        my ($v) = @_;
        return if !defined $v;
        return 'Not a hash' if ref $v ne 'HASH';
        return;
    };
}


1;
