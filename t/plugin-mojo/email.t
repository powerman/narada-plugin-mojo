use t::share (
    'email/from'        => 'from@localhost',
    'email/envelope'    => 'envelope@localhost',
);

BEGIN { $ENV{EMAIL_SENDER_TRANSPORT} = 'Test' }
use _email;
$_email::TMPL_DIR = 't/plugin-mojo/' . $_email::TMPL_DIR;

my $to = 'to@localhost';


# smoke test
lives_ok { _send('simple',[to=>$to])        } 'To: in headers';
lives_ok { _send('simple',[],{},{to=>$to})  } 'To: in mail_args';

# - incorrect params:
throws_ok { _send()                         } qr/usage:/, 'no params';
throws_ok { _send('simple')                 } qr/usage:/, 'one param';
throws_ok { _send('simple',[],{},{},undef)  } qr/usage:/, 'too many params';
throws_ok { _send(undef,[],{},{to=>$to})    } qr/usage:/, 'template undefined';
throws_ok { _send(\'simple',[],{},{to=>$to})} qr/usage:/, 'template is a REF';
throws_ok { _send('simple',0,{},{to=>$to})  } qr/usage:/, 'headers is not ARRAYREF';
throws_ok { _send('simple',[],0,{to=>$to})  } qr/usage:/, 'tmpl_args is not HASHREF';
throws_ok { _send('simple',[to=>$to],{},0)  } qr/usage:/, 'mail_args is not HASHREF';

# Croak happened if user wish to render and send specific template
# (as example use full file name as param) and we lost ability find template and
# smart template type recognition
throws_ok { _send('simple.txt.tmpl',[],{},{to=>$to}) } qr/not found/, 'bad template name';

# - exception from sendmail processing error
throws_ok { _send('simple',[])              } qr/no recipients/;

# - 3 options of email format types:
my ($d, @parts);
my $txt_msg = 'text/plain; charset="UTF-8"; format="flowed"';
my $htm_msg = 'text/html; charset="UTF-8"; format="flowed"';

#   * txt
#     ** headers check
$d = _send('2a',[],{},{to=>$to});
is($d->{email}->content_type, $txt_msg, 'content type header for text message');

#   * html
#     ** headers check
$d = _send('2b',[],{},{to=>$to});
is($d->{email}->content_type, $htm_msg, 'content type header for html message');

#   * txt+html
#     ** headers check
($d, @parts) = _send('2c',[],{},{to=>$to});
like($d->{email}->content_type, qr{\Amultipart/alternative;}, 'content type header for html+txt multipart message');
is(scalar @parts, 2, 'got 2 parts');
is($parts[0]->content_type, $txt_msg, 'content type header for text part of multipart message');
is($parts[1]->content_type, $htm_msg, 'content type header for html part of multipart message');

# - default from:
#   * used correctly
my $from = 'from@somedomain';
$d = _send('2a',[from => $from],{},{to=>$to});
is($d->{email}->header('From'), $from, 'from field as param sent correctly');

#   * can be not set
$d = _send('2a',[],{},{to=>$to});
is($d->{email}->header('From'), _email::DEFAULT_FROM, 'from field (default) used from config file');

# - default envelope:
#   * used correctly
my $envelope = 'envelope@somedomain';
$d = _send('2a',[from => $from],{},{from => $envelope, to=>$to});
is($d->{envelope}{from}, $envelope, 'envelope field as param sent correctly');

#   * can be not set
$d = _send('2a',[from => $from],{},{to=>$to});
is($d->{envelope}{from}, _email::DEFAULT_ENVELOPE, 'envelope default field sent correctly');

# - bcc
my @bcc = ('bcc1@somedomain', 'bcc2@somedomain');
$d = _send('2a',[tO=>$to, bCc=>join q{,},@bcc]);
is_deeply($d->{envelope}{to}, [$to,@bcc],   'delivered to To: + Bcc:');
is($d->{email}->header('To'), $to,          'header To: is set');
is($d->{email}->header('Bcc'), undef,       'header Bcc: is not set');

# - unicode:
#   * From:, To:, Subject:
#   * inside template text
#   * inside template params
$d = _send('1',[from=>"Отправитель <$from>", to=>"Получатель <$to>", subject=>'Тема'], {name=>'Шаблон'});
is($d->{email}->header('From'),     "Отправитель <$from>",  'unicode From:');
is($d->{email}->header('To'),       "Получатель <$to>",     'unicode To:');
is($d->{email}->header('Subject'),  "Тема",                 'unicode Subject:');
is($d->{email}->body_str,           "Привет, Шаблон\n",     'unicode body');

# - BUG case-insensitive from:
$d = _send('1',[FroM=>"Отправитель <$from>", tO=>"Получатель <$to>", suBJect=>'Тема']);
unlike($d->{email}->as_string, qr/^from:\s*\Q${\_email::DEFAULT_FROM}\E\s*$/ms, 'BUG case-insensitive From:');


done_testing();


sub _send {
    _email::send(@_);
    my $d = Email::Sender::Simple->default_transport->shift_deliveries;
    $d->{email} = $d->{email}->cast('Email::MIME');
    return wantarray ? ($d, $d->{email}->parts) : $d;
}
