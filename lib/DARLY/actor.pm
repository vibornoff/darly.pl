package DARLY::actor;

use Carp;
use Scalar::Util qw( refaddr reftype blessed );
use URI;

require DARLY::kernel;

use strict;
use warnings;

# Turn debug tracing on/off
use constant DEBUG => $ENV{DARLY_DEBUG} || 0;

# Partial import constants
use constant URL    => &DARLY::kernel::URL;
use constant OBJECT => &DARLY::kernel::OBJECT;

use overload (
    '""' => \&stringify,
    fallback => 1,
);

sub new {
    my $class = shift; $class = ref $class || $class;
    return bless { @_ }, $class;
}

sub DESTROY {
    my $self = shift;
    $self->shutdown();
}

sub stringify {
    my $self = shift;
    return $self unless ref $self;

    if ( defined( my $actor = DARLY::kernel::actor_get($self) ) ) {
        if ( defined( my $url = DARLY::kernel::actor_url($actor) ) ) {
            return "$url";
        }
        elsif ( defined( my $alias = DARLY::kernel::actor_alias($actor) ) ) {
            return 'darly:///' . $alias . ( DEBUG ? '#' . blessed($self) : '' );
        }
    }

    return 'darly:///' . refaddr($self) . ( DEBUG ? '#' . blessed($self) : '' );
}

sub spawn {
    my ($self,$alias) = @_;
    croak "Alias is empty" if defined $alias && !length $alias;
    $self = $self->new( @_[2..$#_] ) unless ref $self;
    my $actor = DARLY::kernel::actor_spawn( ref $self, $self, undef, $alias );
    return $self;
}

sub reference {
    my ($self,$url) = @_;
    croak "Url is empty" if defined $url && !length $url;
    $self = $self->new( @_[2..$#_] ) unless ref $self;
    DARLY::kernel::actor_spawn( ref $self, $self, URI->new($url), undef );
    return $self;
}

sub resolve {
    my ($self,$what) = @_;
    $what //= $self;

    croak "Argument required" if !ref $what && !length $what;

    $what = URI->new($what) if !blessed $what;
    my $ra = $what->isa('DARLY::actor') ? DARLY::kernel::actor_get($what)
                                        : DARLY::kernel::actor_ref(undef, $what);
    return if !defined $ra;

    while ( defined $ra->[URL] && !$ra->[URL]->authority ) {
        my $rn = DARLY::kernel::actor_resolve( substr($ra->[URL]->path, 1) );
        return if !defined $rn;
        $ra = $rn;
    }

    return $ra->[OBJECT];
}

sub shutdown {
    my $self = shift;
    my $actor = DARLY::kernel::actor_get($self) or return;
    return DARLY::kernel::actor_shutdown($actor);
}

sub alias {
    my $self = shift;
    croak "Alias '$_[0]' is empty" if defined $_[0] && !length $_[0];
    my $actor = DARLY::kernel::actor_get($self) or return;
    return DARLY::kernel::actor_alias($actor,@_);
}

sub url {
    my $self = shift;
    croak "Url '$_[0]' is empty" if defined $_[0] && !length $_[0];
    my $actor = DARLY::kernel::actor_get($self) or return;
    $_[0] = URI->new($_[0]) if @_ > 0 && !ref $_[0];
    return DARLY::kernel::actor_url($actor,@_);
}

sub send {
    my ($self, $rcpt, $event) = splice @_, 0, 3;
    my $args = @_ > 0 ? shift : [];

    my $sender = DARLY::kernel::actor_get($self);
    croak "Can't call method 'send' on non-spawned actor"
        if !defined $sender;

    croak "Event required" if !defined $event || !length $event;

    $args = [ $args ] if defined $args && ( !ref $args || reftype $args ne 'ARRAY' );

    $rcpt = [ $rcpt ] if ref $rcpt ne 'ARRAY';

    my %hash;
    R: for my $r ( @$rcpt ) {
        $r //= $self;
        $r   = URI->new($r) if !blessed $r;

        my $ra = $r->isa('DARLY::actor') ? DARLY::kernel::actor_get($r)
                                         : DARLY::kernel::actor_ref(undef, $r);
        if ( !defined $ra ) {
            warn "Can't send '$event' event to a non-spawned local actor '$r'";
            next R;
        }

        while ( defined $ra->[URL] && !$ra->[URL]->authority ) {
            my $rr = DARLY::kernel::actor_resolve( substr($ra->[URL]->path, 1) );
            if ( !defined $rr ) {
                warn "Can't send '$event' event to a non-resolvable local actor '$r'";
                next R;
            }
            $ra = $rr;
        }

        my ($key, $subkey) = ( '', refaddr $ra );
        ($key, $subkey) = ( $ra->[URL]->scheme.'://'.$ra->[URL]->authority, substr($ra->[URL]->path, 1) ) if defined $ra->[URL];
        $hash{$key}{$subkey} = $ra;
    }

    return DARLY::kernel::actor_send( $sender, \%hash, $event, $args );
}

sub request {
    my ($self, $rcpt, $event) = splice @_, 0, 3;
    my $args = @_ > 0 ? shift : [];
    my $cb   = shift;
    $rcpt  //= $self;

    my $sender = DARLY::kernel::actor_get($self);
    croak "Can't call method 'request' on non-spawned actor"
        unless defined $sender;

    croak "Recipient required" if !defined $rcpt;
    my $recipient = ( ref $rcpt && blessed $rcpt && $rcpt->isa('DARLY::actor') )
                    ? DARLY::kernel::actor_get($rcpt)
                    : DARLY::kernel::actor_ref( undef, URI->new($rcpt) );

    croak "Can't request event to non-spawned local actor '$rcpt'"
        unless defined $recipient;

    while ( defined $recipient->[URL] && !$recipient->[URL]->authority ) {
        my $next = DARLY::kernel::actor_resolve( substr($recipient->[URL]->path, 1) );
        DARLY::error->throw( 'DispatchError', "$recipient->[OBJECT]: can't resolve to local actor" )
            unless defined $next;
        $recipient = $next;
    }

    croak "Event required" if !defined $event || !length $event;

    croak "Callback must be code ref" if defined $cb && ref $cb ne 'CODE' && !( blessed $cb && $cb->isa('DARLY::actor') );

    $args = [ $args ] if defined $args && ( !ref $args || reftype $args ne 'ARRAY' );

    return DARLY::kernel::actor_request( $sender, $recipient, $event, $args, $cb );
}

=pod

sub subscribe {
    my $self = shift;
    warn "TODO implement DARLY::actor::subscribe() method";
    return $self;
}

sub unsubscribe {
    my $self = shift;
    warn "TODO implement DARLY::actor::unsubscribe() method";
    return $self;
}

=cut

1;
