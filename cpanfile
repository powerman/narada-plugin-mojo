requires 'perl', '5.010001';

requires 'AnyEvent::DBI::MySQL';
requires 'DBIx::SecureCGI';
requires 'EV';
requires 'List::Util', '1.33';
requires 'Mojo::Base';
requires 'Mojolicious', '6.0';
requires 'Mojolicious::Commands';
requires 'Mojolicious::Plugin::Narada', '0.3.0';
requires 'Mojolicious::Plugin::ValidateTiny', '0.15';
requires 'Narada', '2.2.0';
requires 'Narada::Config';
requires 'Narada::Lock';
requires 'Narada::Log';
requires 'Path::Tiny';
requires 'Perl6::Export::Attrs';
requires 'Text::MiniTmpl';
requires 'Time::Local';
requires 'Unicode::UTF8';
requires 'Validate::Tiny', '1.501';

on test => sub {
    requires 'Log::Fast';
    requires 'Perl::Critic::Utils';
    requires 'Test::Mojo';
    requires 'Test::More';
    requires 'Test::Perl::Critic';
};
