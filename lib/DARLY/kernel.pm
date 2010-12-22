package DARLY::kernel;

use Carp;
use Readonly;
use URI;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Scalar::Util qw( blessed refaddr reftype weaken );
use List::Util qw( first );

use DARLY::actor;
use DARLY::future;

use strict;
use warnings;

# Turn debug tracing on/off
use constant DEBUG => 1;

# Actor class meta
my %META;
# Meta members
use constant CLASS  => 0;
use constant EVENT  => 1;
#use constant TOPIC  => 2;

# Actors and aliases
my (%ACTOR,%ALIAS);
# Actor members
use constant META   => 0;
use constant URL    => 1;
use constant OBJECT => 2;
use constant ALIAS  => 3;
#use constant SUBS   => 4;

# Active handles and connected nodes
my (%HANDLE,%NODE);
# Handle struct members
use constant HANDLE => 0;
#use constant URL    => 1; #already defined
use constant NIN    => 2;
use constant NOUT   => 3;
use constant REFS   => 4;

# Kernel stuff
Readonly our $KERNEL_ID     => 0;
Readonly our $DEFAULT_PORT  => 12345;
Readonly our $DEFAULT_PROTOCOL => 'json';
Readonly our $MAX_MSG_SIZE  => 65536;   # 64 KiB
Readonly our $MAX_BUF_SIZE  => 2**20;   # 1 MiB
my $KERNEL;

sub run {
    my %opts = @_;

    # Kernel options
    #$KERNEL->{'tracker'}    = $opts{'tracker'}  || undef;
    $KERNEL->{'bind'}       = $opts{'bind'}     || undef;
    $KERNEL->{'port'}       = $opts{'port'}     || $DEFAULT_PORT;
    $KERNEL->{'protocol'}   = $opts{'protocol'} || $DEFAULT_PROTOCOL;

    # Register kernel Actor
    my $KERNEL_CLASS = __PACKAGE__;
    $ACTOR{$KERNEL_ID} = [ $META{$KERNEL_CLASS}, undef, $KERNEL, undef ];
    $ALIAS{'kernel'} = { $KERNEL_ID => $ACTOR{$KERNEL_ID} };

    # Start listenting
    $KERNEL->{'server'} = tcp_server( $KERNEL->{'bind'}, $KERNEL->{'port'} => \&node_connect );

    # Connect tracker if need
    #if ( $opts{tracker} ) {
    #    my ($h,$p) = parse_hostport( $opts{tracker}, $DEFAULT_PORT );
    #    $kernel->{tracker} = tcp_connect( $h, $p => \&_tracker_connect );
    #}

    DEBUG && warn "Run kernel event loop";
    $KERNEL->{'loop'}->begin();
    $KERNEL->{'loop'}->recv();
    return '0 but true';
}

sub shutdown {
    DEBUG && warn "Shutdown kernel event loop";
    $KERNEL->{'loop'}->send();
    return '0 but true';
}

sub dispatch {
    my ($actor, $event, $args) = @_;

    my $code = $actor->[META][EVENT]{$event};
    die "Actor '$actor->[OBJECT]': No handler for event '$event'"
        if !defined $code || ( ref $code && reftype $code ne 'CODE' );

    return $code->( $actor->[OBJECT], defined $args ? @$args : () );
}

sub send {
    my ($actor, $event, $args) = @_;

    if ( my $url = $actor->[URL] ) {
        my $h = node_handle($url); my $ha = refaddr $h;
        $h->push_write( $KERNEL->{'protocol'} => [ substr($url->path,1), $event, $args ]);
    } else {
        dispatch( $actor, $event, $args );
    }

    return '0 but true';
}

sub request {
    my ($actor, $event, $args, $code) = @_;

    if ( my $url = $actor->[URL] ) {
        my ($h, $ha, $f, $fa);

        $h = node_handle($url);
        $ha = refaddr $h;

        $f = 'DARLY::future'->spawn( undef, sub {
                delete $HANDLE{$ha}[REFS]{$fa};
                goto $code;
            });
        $fa = refaddr $f;

        $HANDLE{$ha}[REFS]{$fa} = $f;
        weaken $HANDLE{$ha}[REFS]{$fa};

        $h->push_write( $KERNEL->{'protocol'} => [ substr($url->path,1), $event, $args, $fa ]);
        return $f;
    } else {
        $code->( dispatch( $actor, $event, $args ) );
        return '0 but true';
    }
}

sub meta_extend {
    my ($class, $super) = @_;

    no strict 'refs';
    $super //= first { $_->isa('DARLY::actor') } @{"$class\::ISA"};
    croak "Superclass required to extend from"
        if !defined $super;

    $META{$class} = [ $class, { %{$META{$super}[EVENT]} }];
}

sub meta_event {
    my ($class, $event, $code) = (
        ( $_[0]->isa('DARLY::actor')
            ? () : (caller)[0] ),
        @_,
    );

    croak "Class required to define event in"
        if !defined $class;

    $META{$class}[EVENT]{$event} = $code;
}

=pod
sub meta_topic {
}
=cut

sub actor_spawn {
    my ($class, $obj, $url) = @_;

    my $actor = [ $META{$class}, $url, $obj, undef ];
    $ACTOR{refaddr $obj} = $actor;
    weaken $actor->[OBJECT] if ref $obj;

    DEBUG && warn "Spawn new actor $obj";
    $KERNEL->{'loop'}->begin();

    return '0 but true';
}

sub actor_get {
    my $obj = shift;
    my $actor = $ACTOR{refaddr $obj};
    return $actor;
}

sub actor_resolve {
    my $id_or_alias = shift;
    my $actor = $ACTOR{$id_or_alias};

    if ( !defined $actor && exists $ALIAS{$id_or_alias} ) {
        # FIXME more reliable alias->actor resolution method later
        my $ra = (keys %{$ALIAS{$id_or_alias}})[0];
        $actor = $ACTOR{$ra};
    }

    return $actor;
}

sub actor_alias {
    my ($obj, $alias) = @_;

    my $actor = $ACTOR{refaddr $obj};
    return if !defined $actor;

    if ( @_ > 1 ) {
        if ( defined $alias ) {
            $ALIAS{$alias}{refaddr $obj} = $obj;
        }
        elsif ( $alias = $actor->[ALIAS] ) {
            delete $ALIAS{$alias}{refaddr $obj};
            delete $ALIAS{$alias} if !keys %{$ALIAS{$alias}};
        }
        $actor->[ALIAS] = $alias;
        # TODO Update upstream;
    }

    return $actor->[ALIAS];
}

sub actor_url {
    my ($obj, $url) = @_;

    my $actor = $ACTOR{refaddr $obj};
    return if !defined $actor;

    if ( @_ > 1 ) {
        $actor->[URL] = ref $url ? $url : URI->new($url);
    }

    return $actor->[URL];
}

sub actor_shutdown {
    my $obj = shift;

    my $actor = delete $ACTOR{refaddr $obj};
    return if !defined $actor;

    if ( my $alias = $actor->[ALIAS] ) {
        delete $ALIAS{$alias}{refaddr $obj};
        delete $ALIAS{$alias} if !keys %{$ALIAS{$alias}};
        # TODO Update upstream;
    }

    DEBUG && warn "Shutdown actor $obj";
    $KERNEL->{'loop'}->end();

    return '0 but true';
}

sub node_handle {
    my $url = shift;
    my $handle;

    if ( $NODE{$url}  && keys %{$NODE{$url}} ) {
        $handle = (values %{$NODE{$url}})[0][HANDLE];
    } else {
        $handle = AnyEvent::Handle->new(
            connect => [ $url->host, $url->port ],
            on_error => \&node_disconnect,
            on_eof  => \&node_disconnect,
            on_read => \&node_read,
        );

        $HANDLE{refaddr $handle} =
        $NODE{$url}{refaddr $handle} =
            [ $handle, $url, 0, 0, {} ];
    }

    return $handle;
}

sub node_connect {
    my ($handle, $addr, $port) = @_;

    $handle = AnyEvent::Handle->new(
        fh => $handle,
        on_error => \&node_disconnect,
        on_eof  => \&node_disconnect,
        on_read => \&node_read,
    );

    my $url = URI->new("darly://$addr:$port/");
    $HANDLE{refaddr $handle} =
    $NODE{$url}{refaddr $handle} =
        [ $handle, $url, 0, 0, {} ];

    DEBUG && warn "Node $url connected";
    return '0 but true';
}

sub node_disconnect {
    my ($handle, $fatal, $message) = @_;

    my $entry = delete $HANDLE{refaddr $handle};
    return unless defined $entry;

    my $url = $entry->[URL];
    delete $NODE{$url}{refaddr $handle};
    delete $NODE{$url} if !keys %{$NODE{$url}};

    dispatch( $_, 'error', "Node disconnected" . ( $message ? ": $message" : '' ) )
        for grep { $ACTOR{refaddr $_} } values %{$entry->[REFS]};

    $handle->destroy();

    DEBUG && warn "Node $url disconnected" . ( $message ? ": $message" : '' );
    return '0 but true';
}

sub node_read {
    my $handle = shift;

    if ( length $handle->rbuf > $MAX_BUF_SIZE ) {
        DEBUG && warn "Read buffer overflow on handle $handle";
        node_disconnect($handle);
    }

    $handle->push_read( $KERNEL->{'protocol'} => sub {
        my ($h,$msg) = @_;

        if ( !defined $msg || reftype $msg ne 'ARRAY' ) {
            node_disconnect( $h, 1, 'Bad message' );
            return;
        }

        my ($dest,$event,$args,$responder) = @$msg;
        if ( !defined $dest || !defined $event ) {
            DEBUG && warn "Actor and event are required";
            $h->push_write( $KERNEL->{'protocol'} => [ $responder || $KERNEL_ID, 'error', "Actor and event are required" ]);
            return;
        }

        my $actor = actor_resolve($dest);
        if ( !defined $actor ) {
            DEBUG && warn "No such actor '$dest'";
            $h->push_write( $KERNEL->{'protocol'} => [ $responder || $KERNEL_ID, 'error', "No such actor '$dest'" ]);
            return;
        }

        $args = [ $args ] if defined $args && ( !ref $args || reftype $args ne 'ARRAY' );
        my $result = eval { dispatch( $actor, $event, $args ) };
        DEBUG && $@ && warn $@;
        if ( defined $responder ) {
            if ( $@ ) {
                $h->push_write( $KERNEL->{'protocol'} => [ $responder, 'error', $@ ]);
            } else {
                if ( ref $result && blessed $result && $result->isa('DARLY::future') ) {
                    my $ha = refaddr $h;
                    my $ra = refaddr $result;
                    $HANDLE{$ha}[REFS]{$ra} = $result;
                    $result->cv->cb( sub {
                        $HANDLE{$ha}[HANDLE]->push_write( $KERNEL->{'protocol'} => [ $responder, ( $_[0]->recv )]);
                        delete $HANDLE{$ha}[REFS]{$ra};
                    });
                } else {
                    $h->push_write( $KERNEL->{'protocol'} => [ $responder, 'result', $result ]);
                }
            }
        }
    });
}

sub kernel_error {
    DEBUG && do {
        my (undef, $error) = @_;
        warn "Got error from foreign node: $error";
    }
}

sub kernel_echo {
    my (undef, $arg) = @_;
    die "Expected" if rand(1) < 0.5;
    return $arg;
}

sub kernel_delayed_echo {
    my (undef, $delay, $arg) = @_;
    my ($t,$f); $t = AE::timer $delay, 0, $f = 'DARLY::future'->new(sub{ undef $t; return $arg });
    return $f;
}

BEGIN {
    $META{'DARLY::actor'} = [ 'DARLY::actor', {} ];

    $META{'DARLY::future'} = [ 'DARLY::future', {
        result  => \&DARLY::future::result,
        error   => \&DARLY::future::error,
    }];

    $META{'DARLY::kernel'} = [ 'DARLY::kernel', {
        error       => \&kernel_error,
        echo        => \&kernel_echo,
        delayed_echo => \&kernel_delayed_echo,
    }];

    $KERNEL->{'loop'} = AE::cv();
}

1;

__END__

Meta ::= { Package -> ( Package, EVENTS{ event -> code }, TOPICS{ topic -> 1 } ) }

Actor ::= { refaddr<Obj> -> ( Meta, Obj, Addr, SUBS{ topic -> { refaddr<code> -> code } } ) }

Alias ::= { alias -> { refaddr<Obj> -> Obj } }

Node ::= { Addr -> { refaddr<Handle> -> ( Handle, Addr, Nin, Nout, { refaddr<Obj> -> Obj } ) } }

Handle ::= { refaddr<Handle>        -> ( Handle, Addr, Nin, Nout, { refaddr<Obj> -> Obj } ) ) }

message ::= ( refaddr<Obj> || alias, event, ( arg, ... ), refaddr<Res>, ... )
