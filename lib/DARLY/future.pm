package DARLY::future;
use base 'DARLY::actor';
use DARLY::error;

use Carp;
use AnyEvent;
use Scalar::Util qw( blessed refaddr reftype weaken );

use strict;
use warnings;

use constant CV => 0;
use constant CB => 1;

my %INNER;

sub _resolve {
    my $cv = shift;

    my @result = map { [ $_ ] } @_;

    $cv->begin( sub {
        shift->send( map { @$_ } @result );
    });

    for my $i ( 0 .. $#result ) {
        my $r = $result[$i][0];
        next if !ref $r || !blessed $r || !$r->isa(__PACKAGE__);
        $cv->begin();
        $r->cv->cb( sub {
            eval { $result[$i] = [ shift->recv ] };
            return $cv->croak($@) if $@;
            $cv->end();
        });
    }

    $cv->end();
}

sub _fire {
    my $inner = shift;

    if ( $inner->[CB] ) {
        my @args = map { [ $_ ] } @_;
        my $error = $@;

        $inner->[CV]->begin( sub {
            return unless defined $inner;
            my $cv = shift;
            my @result = eval { $@ = $error; $inner->[CB]->( $error ? () : map { @$_ } @args ) };
            return $cv->croak($@) if $@;
            _resolve( $cv, @result );
        });
        weaken $inner;

        for my $i ( 0 .. $#args ) {
            my $r = $args[$i][0];
            next if !ref $r || !blessed $r || !$r->isa(__PACKAGE__);
            $inner->[CV]->begin();
            $r->cv->cb( sub {
                eval { $args[$i] = [ shift->recv ] };
                $error = $@ if $@;
                $inner->[CV]->end();
            });
        }

        $inner->[CV]->end();
    }
    else {
        return $inner->[CV]->croak($@) if $@;
        _resolve( $inner->[CV], @_ );
    }
}

sub new {
    my $class = shift; $class = ref $class || $class;
    my $cb = shift;

    croak "Argument is not a CODE reference"
        if ref $cb && reftype $cb ne 'CODE';

    my $inner = [ AE::cv(), $cb ];
    my $self = bless sub { local $@; _fire( $inner, @_ ) }, $class;
    $INNER{refaddr $self} = $inner;

    return $self;
}

sub DESTROY {
    my $self = shift;
    my $inner = delete $INNER{refaddr $self};

    $self->shutdown();

    my $cv = $inner && $inner->[CV];
    $cv->croak('DESTROY') if defined $cv && !$cv->ready;
}

sub result {
    my ($self, undef, undef) = splice @_, 0, 3; # sender && event
    my $inner = delete $INNER{refaddr $self};
    local $@;
    _fire( $inner, @_ );
}

sub error {
    my ($self, undef, undef) = splice @_, 0, 3; # sender && event
    my $inner = $INNER{refaddr $self};
    local $@ = ( @_ > 1 ) ? DARLY::error->new(@_) : $_[-1];
    _fire( $inner );
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
