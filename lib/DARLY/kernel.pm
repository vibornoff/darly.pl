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
use DARLY::error;

use strict;
use warnings;

# Turn debug tracing on/off
use constant DEBUG => $ENV{DARLY_DEBUG} || 0;

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
Readonly::Scalar our $KERNEL_ID         => 0;
Readonly::Scalar our $DEFAULT_PORT      => 12345;
Readonly::Scalar our $DEFAULT_PROTOCOL  => 'json';
Readonly::Scalar our $MAX_MSG_SIZE      => 65536;   # 64 KiB
Readonly::Scalar our $MAX_BUF_SIZE      => 2**20;   # 1 MiB
my ($KERNEL, $LOOP);

sub init {
    my %opt = @_;

    my $KERNEL_CLASS = __PACKAGE__;
    $KERNEL = bless {}, $KERNEL_CLASS;

    # Kernel options
    #$KERNEL->{'tracker'}    = $opt{'tracker'}  || undef;
    $KERNEL->{'protocol'}   = $opt{'protocol'} || $DEFAULT_PROTOCOL;

    # Register kernel Actor
    $ACTOR{$KERNEL_ID} = [ $META{$KERNEL_CLASS}, undef, $KERNEL, undef ];
    $ALIAS{'kernel'} = { $KERNEL_ID => $ACTOR{$KERNEL_ID} };

    # Start listening if need
    for my $addr (@{$opt{'listen'}||[]} ) {
        push @{$KERNEL->{'server'}}, tcp_server( $addr->[0], $addr->[1] => \&node_connect );
        DEBUG && warn "Listen " . ($addr->[0]||'*') . ":$addr->[1]\n";
    }


    # Connect tracker if need
    #if ( $opt{'tracker'} ) {
    #    my ($h,$p) = @{$opt{'tracker'}};
    #    $KERNEL->{tracker} = tcp_connect( $h, $p => \&_tracker_connect );
    #}

    DEBUG && warn "Kernel initialized";

    return '0 but true';
}

sub loop {
    DEBUG && warn "Enter kernel event loop";
    init() if !$KERNEL;
    $LOOP = AE::cv();
    return $LOOP->recv();
}

sub shutdown {
    DEBUG && warn "Exit kernel event loop";
    $LOOP->send(@_);
    return '0 but true';
}

###############################################################################
# Meta-related stuff
###############################################################################

sub meta_extend {
    my ($class, $super) = @_;

    no strict 'refs';
    $super //= first { $_->isa('DARLY::actor') } @{"$class\::ISA"};
    croak "Superclass required to extend from"
        if !defined $super;

    $META{$class} //= [ $class, { %{$META{$super}[EVENT]} }];
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

#sub meta_topic {
#}

###############################################################################
# Actor-related stuff
###############################################################################

sub actor_spawn {
    my ($class, $obj, $url) = @_;

    my $actor = [ $META{$class} || $META{'DARLY::actor'}, $url, $obj, undef ];
    $ACTOR{refaddr $obj} = $actor;
    weaken $actor->[OBJECT];

    DEBUG && warn "Spawn new actor $obj";

    return $actor;
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
    my ($actor, $alias) = @_;
    my $obj = $actor->[OBJECT];

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
    my ($actor, $url) = @_;

    if ( @_ > 1 ) {
        $actor->[URL] = $url;
    }

    return $actor->[URL];
}

sub actor_shutdown {
    my $actor = shift;

    my $obj = $actor->[OBJECT];
    return unless defined $obj;

    if ( my $alias = $actor->[ALIAS] ) {
        delete $ALIAS{$alias}{refaddr $obj};
        delete $ALIAS{$alias} if !keys %{$ALIAS{$alias}};
        # TODO Update upstream;
    }

    DEBUG && warn "Shutdown actor $obj";

    return '0 but true';
}

sub actor_dispatch {
    my ($recipient, $sender, $event, $args) = @_;

    my $code = $recipient->[META][EVENT]{$event};
    DARLY::error->throw( 'DispatchError', "$recipient->[OBJECT]: No handler for event '$event'" )
        if !defined $code || ( ref $code && reftype $code ne 'CODE' );

    $sender = $sender->[OBJECT] if ref $sender && reftype $sender eq 'ARRAY';
    $recipient = $recipient->[OBJECT];

    local ${DARLY::Sender} = $sender;
    return $code->( $recipient, defined $args ? @$args : () );
}

sub actor_send {
    my ($sender, $recipient, $event, $args) = @_;

    while ( $recipient->[URL] && !$recipient->[URL]->authority ) {
        my $next = actor_resolve( substr( $recipient->[URL]->path, 1 ) );
        DARLY::error->throw( 'DispatchError', "$recipient->[OBJECT]: can't resolve to local actor" )
            unless defined $next;
        $recipient = $next;
    }

    if ( my $url = $recipient->[URL] ) {
        my $h = node_handle($url); my $ha = refaddr $h;
        $sender = $sender->[ALIAS] || refaddr $sender->[OBJECT];
        $recipient = substr( $url->path, 1 );
        $h->push_write( $KERNEL->{'protocol'} => [ $recipient, $event, $args, $sender ]);
    } else {
        eval { actor_dispatch( $recipient, $sender, $event, $args ) };
        if ( my $error = $@ ) {
            DEBUG && warn $error;
            $error = [ 'Error', "$error" ] if !ref $error || reftype $error ne 'ARRAY';
            kernel_error( $KERNEL, undef, @{$error}[0..1] );
        }
    }

    return '0 but true';
}

sub actor_request {
    my ($sender, $recipient, $event, $args, $code) = @_;

    while ( $recipient->[URL] && !$recipient->[URL]->authority ) {
        my $next = actor_resolve( substr( $recipient->[URL]->path, 1 ) );
        DARLY::error->throw( 'DispatchError', "$recipient->[OBJECT]: can't resolve to local actor" )
            unless defined $next;
        $recipient = $next;
    }

    if ( my $url = $recipient->[URL] ) {
        my ($h, $ha, $f, $fa);

        $h = node_handle($url);
        $ha = refaddr $h;

        $f = 'DARLY::future'->spawn( undef, sub {
                delete $HANDLE{$ha}[REFS]{$fa};
                goto $code if $code;
                return @_;
            });
        $fa = refaddr $f;

        $HANDLE{$ha}[REFS]{$fa} = $f;
        weaken $HANDLE{$ha}[REFS]{$fa};

        $sender = $sender->[ALIAS] || refaddr $sender->[OBJECT];
        $recipient = substr( $url->path, 1 );
        $h->push_write( $KERNEL->{'protocol'} => [ $recipient, $event, $args, $sender, $fa ]);

        return $f;
    } else {
        @_ = eval {
            @_ = actor_dispatch( $recipient, $sender, $event, $args );
            return $code ? $code->(@_) : @_;
        };
        if ( my $error = $@ ) {
            DEBUG && warn $error;
            $error = [ 'Error', "$error" ] if !ref $error || reftype $error ne 'ARRAY';
            kernel_error( $KERNEL, undef, @{$error}[0..1] );
        }
        return @_;
    }
}

###############################################################################
# Node-related stuff
###############################################################################

sub node_handle {
    my $url = shift;
    my $handle;

    my $authority = $url->authority;
    if ( $NODE{$authority} && keys %{$NODE{$authority}} ) {
        $handle = (values %{$NODE{$authority}})[0][HANDLE];
    } else {
        $handle = AnyEvent::Handle->new(
            connect => [ $url->host, $url->port ],
            on_error => \&node_disconnect,
            on_eof  => \&node_disconnect,
            on_read => \&node_read,
        );

        $HANDLE{refaddr $handle} =
        $NODE{$authority}{refaddr $handle} =
            [ $handle, $url, 0, 0, {} ];
    }

    return $handle;
}

sub node_connect {
    my ($handle, $host, $port) = @_;

    $handle = AnyEvent::Handle->new(
        fh => $handle,
        on_error => \&node_disconnect,
        on_eof  => \&node_disconnect,
        on_read => \&node_read,
    );

    my $url = URI->new("darly://$host:$port/");
    my $authority = $url->authority;
    $HANDLE{refaddr $handle} =
    $NODE{$authority}{refaddr $handle} =
        [ $handle, $url, 0, 0, {} ];

    DEBUG && warn "Node $authority connected";
    return '0 but true';
}

sub node_disconnect {
    my ($handle, $fatal, $message) = @_;

    my $entry = delete $HANDLE{refaddr $handle};
    return unless defined $entry;

    my $url = $entry->[URL];
    my $authority = $url->authority;
    delete $NODE{$authority}{refaddr $handle};
    delete $NODE{$authority} if !keys %{$NODE{$authority}};

    actor_dispatch( $_, 'error', [ 'IOError', "Node disconnected" . ( $message ? ": $message" : '' ) ])
        for grep { $ACTOR{refaddr $_} } values %{$entry->[REFS]};

    $handle->destroy();

    DEBUG && warn "Node $authority disconnected" . ( $message ? ": $message" : '' );
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

        my ($dest,$event,$args,$sender,$responder) = @$msg;
        if ( !defined $dest || !defined $event ) {
            DEBUG && warn "Actor and event are required";
            $h->push_write( $KERNEL->{'protocol'} => [ $responder || $KERNEL_ID, 'error', [ 'DispatchError', "Actor and event are required" ]]);
            return;
        }

        my $recipient = actor_resolve($dest);
        if ( !defined $recipient ) {
            DEBUG && warn "No such actor '$dest'";
            $h->push_write( $KERNEL->{'protocol'} => [ $responder || $KERNEL_ID, 'error', [ 'DispatchError', "No such actor '$dest'" ]]);
            return;
        }

        # TODO To spawn or not to spawn ?
        my $sender_url;
        if ( defined $sender ) {
            $sender_url = $HANDLE{refaddr $h}[URL]->clone();
            $sender_url->path("/$sender");
        }

        eval {
            $args = [ $args ] if defined $args && ( !ref $args || reftype $args ne 'ARRAY' );
            if ( defined $responder ) {
                my @result = actor_dispatch( $recipient, $sender_url, $event, $args );
                if ( ref $result[0] && blessed $result[0] && $result[0]->isa('DARLY::future') ) {
                    my $ha = refaddr $h;
                    my $ra = refaddr $result[0];
                    $HANDLE{$ha}[REFS]{$ra} = $result[0];
                    $result[0]->cv->cb( sub {
                        $HANDLE{$ha}[HANDLE]->push_write( $KERNEL->{'protocol'} => [ $responder, ( $_[0]->recv )]);
                        delete $HANDLE{$ha}[REFS]{$ra};
                    });
                } else {
                    $h->push_write( $KERNEL->{'protocol'} => [ $responder, 'result', \@result ]);
                }
            } else {
                actor_dispatch( $recipient, $sender_url, $event, $args );
            }
        };

        if ( my $error = $@ ) {
            DEBUG && warn $error;        
            $error = [ 'Error', "$error" ] if !ref $error || reftype $error ne 'ARRAY';
            $h->push_write( $KERNEL->{'protocol'} => [ $responder || $KERNEL_ID, 'error', [ @{$error}[0..1] ]]);
        }
    });
}

###############################################################################
# Kernel's actor event handlers
###############################################################################

sub kernel_result {
    splice @_, 0, 2;
    DEBUG && warn "Got result: @_";
}

sub kernel_error {
    splice @_, 0, 2;
    ${DARLY::LastError} = $_[0];
    ${DARLY::LastErrorMessage} = $_[1];
    DEBUG && warn "Got error: $_[0]: $_[1]";
}

###############################################################################
# Static initialization
###############################################################################

BEGIN {
    $META{'DARLY::actor'} = [ 'DARLY::actor', {} ];

    $META{'DARLY::future'} = [ 'DARLY::future', {
        result  => \&DARLY::future::result,
        error   => \&DARLY::future::error,
    }];

    $META{'DARLY::kernel'} = [ 'DARLY::kernel', {
        result  => \&kernel_result,
        error   => \&kernel_error,
    }];
}

1;

__END__

=head1 INTERNALS

META ::= { Package -> ( Package, EVENTS{ event -> code }, TOPICS{ topic -> 1 } ) }

ACTOR ::= { refaddr<Obj> -> ( Meta, url, Obj, alias, SUBS{ topic -> { refaddr<code> -> code } } ) }

ALIAS ::= { alias -> { refaddr<Obj> -> Obj } }

NODE ::= { authority<url> -> { refaddr<Handle> -> ( Handle, url, Nin, Nout, REFS{ refaddr<Obj> -> Obj } ) } }

HANDLE ::= { refaddr<Handle>        -> ( Handle, url, Nin, Nout, REFS{ refaddr<Obj> -> Obj } ) ) }

message ::= ( refaddr<Obj> || alias, event, ( arg, ... ), refaddr<Res> )

=cut
