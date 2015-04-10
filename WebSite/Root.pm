package WebSite::Root;
use Mojo::Base 'Mojolicious::Controller';


sub index {                             ## no critic(ProhibitBuiltinHomonyms)
    my $c = shift;
    return $c->render(
        message => 'Welcome to the Mojolicious!',
    );
}


1;
