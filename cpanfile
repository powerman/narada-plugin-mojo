requires 'perl', '5.010001';

requires 'AnyEvent::DBI::MySQL';
requires 'DBIx::SecureCGI';
requires 'EV';
requires 'List::Util', '1.33';
requires 'Mojo::Base';
requires 'Mojolicious', '6.0';
requires 'Mojolicious::Commands';
requires 'Mojolicious::Plugin::Narada';
requires 'Mojolicious::Plugin::ValidateTiny';
requires 'Narada::Config';
requires 'Narada::Lock';
requires 'Narada::Log';
requires 'Path::Tiny';
requires 'Perl6::Export::Attrs';
requires 'Text::MiniTmpl';
requires 'Time::Local';
requires 'Validate::Tiny';

on test => sub {
    requires 'Log::Fast';
    requires 'Perl::Critic::Utils';
    requires 'Test::Mojo';
    requires 'Test::More';
    requires 'Test::Perl::Critic';
};
