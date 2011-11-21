package DARLY::future;
use base 'DARLY::actor';

use Carp;
use AnyEvent;
use Scalar::Util qw( refaddr reftype );

use strict;
use warnings;

use constant CV => 0;
use constant CB => 1;

my %INNER;

sub _fire {
    my ($inner, $event) = splice @_, 0, 2;

    if ( $inner->[CB] ) {
        my $err = $@;
        @_ = eval { local $@ = $err; $inner->[CB]->(@_) };
        if ( $err = $@ ) {
            $event = 'error';
            @_ = ( 'Error', $@ );
        }
    }

    $inner->[CV]->send( $event, \@_ );
}

sub new {
    my $class = shift; $class = ref $class || $class;
    my $cb = shift;

    croak "Argument is not a CODE reference"
        if ref $cb && reftype $cb ne 'CODE';

    my $inner = [ AE::cv(), $cb ];
    my $self = bless sub { _fire( $inner, 'result', @_ ) }, $class;
    $INNER{refaddr $self} = $inner;

    return $self;
}

sub DESTROY {
    my $self = shift;
    my $inner = delete $INNER{refaddr $self};

    $self->shutdown();

    unless ( $inner->[CV]->ready ) {
        $inner->[CB]->() if $inner->[CB];
        $inner->[CV]->send();
    }
}

sub result {
    my $self = shift;
    my $inner = $INNER{refaddr $self};
    _fire( $inner, 'result', @_ );
}

sub error {
    my $self = shift;
    my $inner = $INNER{refaddr $self};
    local $@ = DARLY::error->new(@_);
    _fire( $inner, 'error' );
}

sub cv {
    my $self = shift;
    my $inner = $INNER{refaddr $self};
    return $inner->[CV];
}

1;

__END__

=pod

Let's assume we have an actor package with 'delayed_echo' handler that delays
echoing back its arguments for the specified timeout. Here we hold reference
to C<$t> in the future's callback to avoid dereferencing and destroying
timer object before timeout is elapsed.

 event 'delayed_echo' => sub {
    my ($actor, $sender, $delay, $message) = @_;
    my ($t,$f); $t = AE::timer $delay, 0, $f = future { $t = undef; return $message };
    return $f;
 }

Take a look that the event handler returns the future object saying that request result
would be available later. Now at other place we can request 'delayed_echo' event:

 $actor->request(
    'delayed_echo', [ 3, 'hello!' ]
        => sub { say "Got $_[-1]" }
 );

=cut
