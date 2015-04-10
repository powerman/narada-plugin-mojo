package WebSite::Version;
use Mojo::Base 'Mojolicious::Controller';


sub project {
    my $c = shift;
    return $c->render(json => {
        version => $::VERSION,
    });
}


1;
