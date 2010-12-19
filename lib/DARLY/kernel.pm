package DARLY::kernel;

use Carp;
use Readonly;
use URI;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Scalar::Util qw( blessed refaddr reftype weaken );
use List::Util qw( first );

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

# Kernel stuff
Readonly our $KERNEL_ID     => 0;
Readonly our $DEFAULT_PORT  => 12345;
Readonly our $MAX_MSG_SIZE  => 65536;   # 64 KiB
Readonly our $MAX_BUF_SIZE  => 1**20;   # 1 MiB
my $KERNEL;
BEGIN {
    $KERNEL->{loop} = AE::cv();
}

sub run {
    my %opts = @_;

    # Kernel options
    #$opts{'tracker'} ||= undef;
    $opts{'bind'}   ||= undef;
    $opts{'port'}   ||= $DEFAULT_PORT;

    # Register kernel Actor
    my $KERNEL_CLASS = __PACKAGE__;
    $ACTOR{$KERNEL_ID} = [ $KERNEL_CLASS, $KERNEL, undef, undef ];
    $ALIAS{'kernel'} = { $KERNEL_ID => $ACTOR{$KERNEL_ID} };

    # Start listenting
    $KERNEL->{server} = tcp_server( $opts{'bind'}, $opts{'port'} => \&node_connect );

    # Connect tracker if need
    #if ( $opts{tracker} ) {
    #    my ($h,$p) = parse_hostport( $opts{tracker}, $DEFAULT_PORT );
    #    $kernel->{tracker} = tcp_connect( $h, $p => \&_tracker_connect );
    #}

    DEBUG && warn "Run kernel event loop";
    $KERNEL->{loop}->begin();
    $KERNEL->{loop}->recv();
    return '0 but true';
}

sub shutdown {
    DEBUG && warn "Shutdown kernel event loop";
    $KERNEL->{loop}->send();
    return '0 but true';
}

sub dispatch {
    my ($actor, $event, $args) = @_;
    my $code = $actor->[META][EVENT]{$event};
    return if !defined $code || reftype $code ne 'CODE';
    return $code->( defined $args ? @$args : () );
}

sub send {
    my ($actor, $event, $args) = @_;
    if ( $actor->[URL] ) {
        # TODO forward message to another node
    } else {
        dispatch( $actor, $event, $args );
    }
    return '0 but true';
}

sub request {
    my ($actor, $event, $args, $code) = @_;
    if ( $actor->[URL] ) {
        # TODO forward request to another node
    } else {
        $code->( dispatch( $actor, $event, $args ) );
    }
    return '0 but true';
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

    croak "Class to define event in is required to be actor"
        if !defined $class || !$class->isa('DARLY::actor');

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
    $KERNEL->{loop}->begin();

    return '0 but true';
}

sub actor_get {
    my $obj = shift;
    my $actor = $ACTOR{refaddr $obj};
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
    $KERNEL->{loop}->end();

    return '0 but true';
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
        [ $handle, $url, 0, 0 ];

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

    $handle->destroy();

    DEBUG && warn "Node $url disconnected";
    return '0 but true';
}

sub node_read {
    my $handle = shift;

    if ( length $handle->rbuf > $MAX_BUF_SIZE ) {
        DEBUG && warn "Read buffer overflow on handle $handle";
        node_disconnect($handle);
    }

    $handle->push_read( json => sub {
        my ($h,$msg) = @_;

        if ( !defined $msg || reftype $msg ne 'ARRAY' ) {
            node_disconnect( $h, 1, 'Bad message' );
            return;
        }

        my ($id,$event,$args,$responder) = @$msg;
        return unless defined $id && defined $event;
        my $actor = $ACTOR{$id};
        return unless defined $actor;

        $args = [ $args ] if defined $args && reftype $args ne 'ARRAY';
        my $result = eval { dispatch( $actor, $event, $args ) };
        if ( defined $responder ) {
            if ( $@ ) {
                # TODO send error message
            }
            # TODO if $result->isa(future)
        }
    });
}

1;

__END__

Meta ::= { Package -> ( Package, EVENTS{ event -> code }, TOPICS{ topic -> 1 } ) }

Actor ::= { refaddr<Obj> -> ( Meta, Obj, Addr, SUBS{ topic -> { refaddr<code> -> code } } ) }

Alias ::= { alias -> { refaddr<Obj> -> Obj } }

Node ::= { Addr -> { refaddr<Handle> -> ( Handle, Addr ) } }

Handle ::= { refaddr<Handle> -> ( Handle, Addr, Nin, Nout, ) ) }

Json ::= ( refaddr<Obj>, event, ( arg, ... ), refaddr<Res> )
Frame ::= ( Magic, Size, message )
