use Mojo::Base -strict;
use Log::Fast; Log::Fast->global->config({fh=>do{open my$fh,'>/dev/null';$fh}});
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('WebSite');

$t->get_ok('/')
    ->status_is(200)
    ->content_like(qr/<title>/i);

$t->get_ok('/version')
    ->status_is(200)
    ->json_is('/version' => $::VERSION);


done_testing();
