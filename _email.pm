package _email;
use Mojo::Base -strict;
use Carp;

use List::Util 1.33 qw( none pairkeys );
use Email::Abstract;
use Email::Address;
use Email::MIME;
use Email::Sender::Simple qw( sendmail );
use Mojo::Template;
use Narada::Config qw( get_config_line );

our $TMPL_DIR = 'templates/emails';
use constant EXT_TXT            => 'txt.tmpl';
use constant EXT_HTML           => 'html.tmpl';
use constant DEFAULT_FROM       => get_config_line('email/from');
use constant DEFAULT_ENVELOPE   => get_config_line('email/envelope');
use constant ATTRIBUTES         => {
    txt     => {
        content_type    => 'text/plain',
        disposition     => 'attachment',
        charset         => 'UTF-8',
        encoding        => '8bit',
        format          => 'flowed'
    },
    html    => {
        content_type    => 'text/html',
        disposition     => 'attachment',
        charset         => 'UTF-8',
        encoding        => '8bit',
        format          => 'flowed'
    },
};


sub send { ## no critic (ProhibitBuiltinHomonyms)
    my ($tmpl, $headers, $tmpl_args, $mail_args) = @_;
    $headers    //= [];
    $tmpl_args  //= {};
    $mail_args  //= {};
    croak 'usage: send("template_name", \@headers, \%tmpl_args, \%mail_args)'
        if !defined $tmpl || ref $tmpl
        || ref $headers ne 'ARRAY'
        || ref $tmpl_args ne 'HASH'
        || ref $mail_args ne 'HASH'
        || @_ < 2 || @_ > 4; ## no critic (ProhibitMagicNumbers)

    if (none {lc $_ eq 'from'} pairkeys @{$headers}) {
        $headers = [ @{$headers}, from => DEFAULT_FROM ];
    }
    $mail_args->{from} //= DEFAULT_ENVELOPE;

    my $message;
    my $tmpl_txt    = sprintf '%s/%s.%s', $TMPL_DIR, $tmpl, EXT_TXT;
    my $tmpl_html   = sprintf '%s/%s.%s', $TMPL_DIR, $tmpl, EXT_HTML;
    if (-e $tmpl_txt && -e $tmpl_html) {
        my $parts = [
            Email::MIME->create(
                attributes  => ATTRIBUTES->{txt},
                body_str    => _render($tmpl_txt, $tmpl_args),
            ),
            Email::MIME->create(
                attributes  => ATTRIBUTES->{html},
                body_str    => _render($tmpl_html, $tmpl_args),
            ),
        ];
        $message = Email::MIME->create(
            header_str  => $headers,
            attributes  => {
                content_type => 'multipart/alternative', # parts order important
            },
            parts       => $parts,
        );
    }
    elsif (-e $tmpl_txt) {
        $message = Email::MIME->create(
            header_str  => $headers,
            attributes  => ATTRIBUTES->{txt},
            body_str    => _render($tmpl_txt, $tmpl_args),
        );
    }
    elsif (-e $tmpl_html) {
        $message = Email::MIME->create(
            header_str  => $headers,
            attributes  => ATTRIBUTES->{html},
            body_str    => _render($tmpl_html, $tmpl_args),
        );
    }
    else {
        croak sprintf '%s or %s not found', $tmpl_txt, $tmpl_html;
    }

    if (!$mail_args->{to}) {
        my $email = Email::Abstract->new($message);
        $mail_args->{to} = [
            map  { $_->address                  }
            grep { defined                      }
            map  { Email::Address->parse($_)    }
            map  { $email->get_header($_)       }
            qw( to cc bcc )
        ];
        $message->header_set('bcc');
    }
    my $res = sendmail($message, $mail_args);
    croak 'email sending failed' if !$res;
    return $res;
}

sub _render {
    my ($tmpl, $args) = @_;
    state $mt = Mojo::Template->new->tag_start('[%')->tag_end('%]')->auto_escape(1);
    local %_ = %{ $args };
    return $mt->render_file($tmpl);
}

1; # Magic true value required at end of module
__END__

=head1 NAME

_email - send emails using Mojo templates

=head1 SYNOPSIS

    use _email;

    _email::send('TEMPLATE_NAME',
        [
            To        => 'receiver@domain.tld',
            To        => 'someone@domain.tld',
            BCC       => 'boss@domain.tld',
            Subject   => 'Mail subject',
        ],
        {
            user_name => 'Someone',
            message   => 'Hello world!',
        },
        {
            from      => 'sender@domain.tld',
        },
    );

    $ cat > templates/emails/TEMPLATE_NAME.txt.tmpl <<'EOF'
    This is simple text email template file example.
    Welcome [%= $_{user_name} =%]
    [%= $_{message} =%]
    With best regards, your mailer.
    EOF

    $ cat > templates/emails/TEMPLATE_NAME.html.tmpl <<'EOF'
    <html>
    <h1>Welcome [%= $_{user_name} =%]</h1>
    <i>[%= $_{message} =%]</i>
    With best regards, your mailer.
    </html>
    EOF


=head1 DESCRIPTION

Send email according to available .txt and/or .html Mojo templates:
if both templates available then send multipart email, otherwise
send plain email with correct Content-Type.

Support BCC email header.


=head1 INTERFACE

=over

=item send

    send($template_name, \@headers, \%tmpl_args, \%mail_args)

Send email using template files
C<"templates/emails/$template_name.txt.tmpl"> and/or
C<"templates/emails/$template_name.html.tmpl"> (at least one of them must
exists).

C<@headers> should contain pairs of header name (case-insensitive) and value.
If it doesn't contain header "From" then it will be set to content of
C<config/email/from> file.

C<%tmpl_args> will be available in templates as C<%_> while rendering them.

C<%mail_args> will be used as second param for
Email::Sender::Simple::sendmail(). If it doesn't contain key "from" then
it will be set to content of C<config/email/envelope> file. If it doesn't
contain key "to" then it'll be set to joined list of emails found in
C<@headers> keys "To", "CC" and "BCC"; then key "BCC" will be removed from
C<@headers>.

=back


=head1 DIAGNOSTICS

=over

=item C<< usage: send("template_name", \@headers, \%tmpl_args, \%mail_args) >>

send() was called with wrong parameters.

=item C<< %s or %s not found', $tmpl_txt, $tmpl_html >>

Can not find email template file.

=item C<< email sending failed >>

Email::Sender::Simple::sendmail() fail.

=back


=head1 CONFIGURATION AND ENVIRONMENT

    config/email/from
    config/email/envelope
    templates/emails/*.txt.tmpl
    templates/emails/*.html.tmpl


=head1 DEPENDENCIES

    Email::Abstract
    Email::Address
    Email::MIME
    Email::Sender::Simple
    List::Util 1.33
    Mojo::Template
    Narada::Config


=head1 BUGS AND LIMITATIONS

Sending email to multiple addresses return no error if
some email delivery failed/does not accepted, that's result of using
Email::Sender::Simple::sendmail() function.
