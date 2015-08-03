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

_email - simple tool for sending modern looking emails

=head1 SYNOPSIS

    use _email;

    _email::send(TEMPLATE_FILE_NAME,
        [
            to        => EMAIL,
            subject   => SUBJECT,
        ],
        {
            user_name => 'Someone',
            message   => 'Hello world!',
        },
        {
            from      => FROM,
        },
    );

    file: TEMPLATE_FILE_NAME.txt.tmpl <<
    This is simple text email template file example.
    Welcome [%= $_{user_name} =%]
    [%= $_{message} =%]
    With best regards, you mailer.
    <<

    file: TEMPLATE_FILE_NAME.html.tmpl <<
    <html>
    <h1>Welcome [%= $_{user_name} =%]</h1>
    <i>[%= $_{message} =%]</i>
    With best regards, you mailer.
    </html>
    <<


=head1 DESCRIPTION

    Allow sending modern looking emails using mojo template
    tools and ability apply some common/default parameters to each
    function call.

    Realized ability looking for available template files according
    to recieved parameters and send multipart email message,
    with correctly updated headers, properly readeble based
    on client email reader configuration.

    Correctly processing BCC email parameters


=head1 INTERFACE 

    send("template_name", \@headers, \%tmpl_args, \%mail_args)


=head1 DIAGNOSTICS

=over

=item C<< usage: send("template_name", \@headers, \%tmpl_args, \%mail_args) >>

    function get wrong parameters

=item C<< %s or %s not found', $tmpl_txt, $tmpl_html >>

    can not find email template file
    template name parameter must not include any extension
    file extension will be added automatically
    here is template lookup logic searching for template file name:
    $TMPL_DIR/ + template_name + [.txt.tmpl] || [.html.tmpl] file extension

=item C<< email sending failed >>

    function get error during sending email process
    from Email::Sender::Simple module

=back


=head1 CONFIGURATION AND ENVIRONMENT

    module can work with out any configuration files,
    but looking for this configuration files:
    email/from
    and
    email/envelope
    and use it as default values for according email parameters

    by default module looking for templates at folder:
    templates/emails

    to be visible for module, template files must end by this extention:
    txt.tmpl - for text templates
    and
    html.tmpl - for html templates


=head1 DEPENDENCIES

    List::Util 1.33
    Email::Abstract
    Email::Address
    Email::MIME
    Email::Sender::Simple
    Mojo::Template
    Narada::Config


=head1 BUGS AND LIMITATIONS

    sending email to multiply addresses return no error if
    some email delivery failed/does not accepted, that's result of using
    Email::Sender::Simple::sendmail() function,
    using alternative function Email::Sender::Simple::try_to_sendmail()
    prevent partial delivery with no error or warning
    but hide internal sendmail error message
