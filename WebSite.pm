package WebSite;
use Mojo::Base 'Mojolicious';
use AnyEvent::DBI::MySQL;
use DBIx::SecureCGI;
use List::Util 1.33 qw( none );
use Text::MiniTmpl qw( encode_js encode_js_data );

use _init;

use constant CONFIG_LINE    => qw( title );
use constant CONFIG_FULL    => qw( );


sub startup {
    my $app = shift;

    #--- Narada
    $app->config($_ => get_config_line($_))   for CONFIG_LINE; ## no critic (ProhibitPostfixControls)
    $app->config($_ => get_config($_))        for CONFIG_FULL; ## no critic (ProhibitPostfixControls)
#     $app->config(db => Narada::Config::get_db_config());

    $app->plugin('Narada', log => $LOG);

    # initialization done, release bootstrap lock
    unlock();

    # undo _init.pm: die logging will be handled by Mojo
    undef $::SIG{__DIE__};

    #--- Plugins
    # use .tmpl instead of .ep to avoid conflict with POWER.js on <%…%>
    $app->plugin('EPRenderer', name => 'tmpl', template => {
        tag_start => '[%',
        tag_end   => '%]',
    });
    $app->plugin('ValidateTiny');

    #--- Helpers
    $app->helper(render_cb      => sub { shift->render_later->proxy(@_) });
    $app->helper(encode_js      => sub { shift; goto &encode_js     });
    $app->helper(encode_js_data => sub { shift; goto &encode_js_data});
    $app->helper(add_mtime      => \&_helper_add_mtime);
    $app->helper(dbh            => sub { shift->{dbh} });
    $app->helper(new_dbh        => sub {
        state $db = shift->app->config('db') or return;
        return AnyEvent::DBI::MySQL->connect(@{$db}{qw(dsn login pass)},
            {mysql_enable_utf8 => 1});
    });
    $app->helper(validate       => sub {
        my ($c, $rules) = @_;
        # make sure do_validate() called with $c->{_} in second param
        # (otherwise it'll use crap from $c->param)
        return $c->do_validation(_sane_validation_rules($rules), $c->{_});
    });
    $app->helper(validate_json  => sub {
        my ($c, $rules) = @_;
        my $json = $c->req->json;
        if (!$json || ref $json ne 'HASH') {
            return _set_validation_errors($c, json => 'JSON not an Object');
        }
        return $c->do_validation(_sane_validation_rules($rules), $json);
    });
    $app->helper(validator_set_errors => \&_set_validation_errors);

    #--- Hooks
    $app->hook(before_routes => sub {
        my $c = shift;
        # each connection have own dbh
        $c->{dbh} = $c->new_dbh;
        # sane params hash
        $c->{_} = {};
        for my $name (@{ $c->req->params->names }) {
            next if $name =~ /\A_(?!_)/ms;  # DBIx::SecureCGI protected fields
            my $vals = $c->req->params->every_param($name);
            $c->{_}{$name} = $name =~ /\A\@|__|\[\]\z/ms ? $vals : $vals->[0];
        }
    });
    $app->hook(after_render => sub {
        my $c = shift;
        # cache control for dynamic content
        $c->res->headers->header('Expires' => 'Sat, 01 Jan 2000 00:00:00 GMT');
    });;

    #--- Defaults
    $app->defaults(appjs => 'main');

    #--- Routes
    my $r = $app->routes;

    $r->get(q{/})->to('root#index');
    $r->get(q{/version})->to('version#project');

    return;
}


# add_mtime '/css/main.css'                 => '/css/main.1234567890.css'
# add_mtime 'main' (test '/js/main.js')     => 'main.1234567890'
use constant MTIME => 9;
sub _helper_add_mtime {
    my (undef, $url) = @_;
    my $is_js = $url !~ m{\A/}ms;
    my $file = $is_js ? "public/js/$url.js" : "public/$url";
    if (-f $file) {
        my $mtime = (stat $file)[MTIME];
        if ($is_js) {
            $url .= ".$mtime";
        } else {
            $url =~ s/[.](\w+)\z/.$mtime.$1/ms;
        }
    }
    return $url;
}

sub _sane_validation_rules {
    my ($rules) = @_;
    if (ref $rules eq 'ARRAY') {
        $rules = { checks => $rules };
    }
    # sanity check for Regexp in 'checks'
    use Carp;
    for ( my $i = 0; $i < @{$rules->{checks}}; $i += 2 ) {
        my $field = $rules->{checks}[$i];
        if (ref $field eq 'Regexp') {
            if (!$rules->{fields}) {
                croak 'You must use {fields} when using Regexp in {checks}';
            }
            if (none {/$field/ms} @{ $rules->{fields} }) {
                croak "No fields in {fields} match /$field/ check";
            }
        }
    }
    # fix Mojolicious::Plugin::ValidateTiny bug 84959
    $rules->{fields} = [@{ $rules->{fields} || [] }];
    for ( my $i = 0; $i < @{$rules->{checks}}; $i += 2 ) {
        my $field = $rules->{checks}[$i];
        if (ref $field eq 'ARRAY') {
            push @{ $rules->{fields} }, @{ $field };
        }
    }
    return $rules;
}

sub _set_validation_errors {
    my ($c, %err) = @_;
    my @checks = map {my $e=$err{$_}; $_=>sub{$e}} keys %err; ## no critic (ProhibitComplexMappings)
    my $r = Validate::Tiny->check(\%err, {fields=>[],checks=>\@checks});
    $c->stash( 'validate_tiny.was_called', 1 );
    $c->stash( 'validate_tiny.result' => $r );
    if (!$r->success) {
        $c->stash( 'validate_tiny.errors' => $r->error );
        $c->app->log->debug('ValidateTiny: Failed: '.join ', ', keys %{ $r->error });
    }
    return;
}


1;
