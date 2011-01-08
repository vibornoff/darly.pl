package DARLY::actor;

use Carp;
use Scalar::Util qw( refaddr reftype blessed );
use URI;

require DARLY::kernel;

use strict;
use warnings;

# Turn debug tracing on/off
use constant DEBUG => $ENV{DARLY_DEBUG} || 0;

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

    my $actor = DARLY::kernel::actor_get($self);
    return $self unless defined $actor;

    if ( my $url = DARLY::kernel::actor_url($actor) ) {
        return "$url";
    } elsif ( my $alias = DARLY::kernel::actor_alias($actor) ) {
        return 'darly:///' . $alias . ( DEBUG ? '#' . blessed($self) : '' );
    } else {
        return 'darly:///' . refaddr($self) . ( DEBUG ? '#' . blessed($self) : '' );
    }
}

sub spawn {
    my ($self,$alias) = @_;
    croak "Alias '$alias' is empty" if defined $alias && !length $alias;
    $self = $self->new( @_[2..$#_] ) unless ref $self;
    my $actor = DARLY::kernel::actor_spawn(ref $self, $self, undef);
    DARLY::kernel::actor_alias($actor, $alias) if $alias;
    return $self;
}

sub reference {
    my ($self,$url) = @_;
    croak "Url '$url' is empty" if defined $url && !length $url;
    $self = $self->new( @_[2..$#_] ) unless ref $self;
    DARLY::kernel::actor_spawn(ref $self, $self, URI->new($url));
    return $self;
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
    my ($self, $rcpt, $event, $args) = @_;
    $rcpt //= $self;

    my $sender = DARLY::kernel::actor_get($self);
    croak "Can't call method 'request' on non-spawned actor"
        unless defined $sender;

    croak "Recipient required" if !defined $rcpt;
    my $recipient = ( ref $rcpt && blessed $rcpt && $rcpt->isa('DARLY::actor') )
                    ? DARLY::kernel::actor_get($rcpt)
                    : DARLY::kernel::actor_spawn( 'DARLY::actor', DARLY::actor->new(), URI->new($rcpt) );
    croak "Can't request event to non-spawned actor '$rcpt'"
        unless defined $recipient;

    croak "Event required" if !defined $event || !length $event;

    $args = [ $args ] if defined $args && ( !ref $args || reftype $args ne 'ARRAY' );

    return DARLY::kernel::actor_send( $sender, $recipient, $event, $args );
}

sub request {
    my ($self, $rcpt, $event, $args, $cb) = @_;
    $rcpt //= $self;

    my $sender = DARLY::kernel::actor_get($self);
    croak "Can't call method 'request' on non-spawned actor"
        unless defined $sender;

    croak "Recipient required" if !defined $rcpt;
    my $recipient = ( ref $rcpt && blessed $rcpt && $rcpt->isa('DARLY::actor') )
                    ? DARLY::kernel::actor_get($rcpt)
                    : DARLY::kernel::actor_spawn( 'DARLY::actor', DARLY::actor->new(), URI->new($rcpt) );
    croak "Can't request event to non-spawned actor '$rcpt'"
        unless defined $recipient;

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
