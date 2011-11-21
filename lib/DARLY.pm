package DARLY;

our $VERSION = '1.00';

use Carp;
use AnyEvent::Socket;

use DARLY::kernel;
use DARLY::actor;
use DARLY::future;
use DARLY::error;

use strict;
use warnings;

our $Sender;

our $LastError;
our $LastErrorMessage;

sub import {
    my $caller = (caller)[0];
    return if $caller =~ /^DARLY/;

    no strict 'refs';
    #*{"$caller\::topic"} = *topic;
    *{"$caller\::on"}     = *on;
    *{"$caller\::future"} = *future;
    *{"$caller\::sender"} = *sender;

    push @{"$caller\::ISA"}, 'DARLY::actor'
        if !$caller->isa('DARLY::actor');

    my $caller_ref = $caller . '_ref';
    push @{"$caller_ref\::ISA"}, $caller
        if !$caller_ref->isa($caller);

    DARLY::kernel::meta_extend($caller);
}

#sub topic($)    { }
sub on($;&)     { goto \&DARLY::kernel::meta_on }
sub future(;&)  { unshift @_, 'DARLY::future'; goto \&DARLY::future::new }
sub sender()    { $Sender }

sub init(%) {
    my %opt = @_;

    # Process 'listen' option
    if ( exists $opt{'listen'} ) {
        croak "Can't listen '$opt{listen}': bad address"
            if ref $opt{'listen'} && ref $opt{'listen'} ne 'ARRAY';

        my %addr;

        if ( ref $opt{'listen'} ) {
            for my $addr ( @{$opt{'listen'}} ) {
                my ($host,$port) = parse_hostport $addr;
                croak "Can't listen '$addr': bad address" if !defined $host;
                $addr{$host,$port} = [ $host, $port ];
            }
        } else {
            $addr{':'} = [ undef, ${DARLY::kernel::DEFAULT_PORT} ];
        }

        $opt{'listen'} = [ values %addr ];
    }

    DARLY::kernel::init(%opt);
}

sub loop() {
    DARLY::kernel::loop();
}

sub run(%) {
    init(@_);
    loop();
}

sub shutdown(_) {
    DARLY::kernel::shutdown();
}

1;

__END__

=head1 NAME

DARLY - Distributed Actor Runtime Library

=head1 SYNOPSIS

 package MyChatServer;
 use DARLY;
 
 topic 'history';
 
 on 'say' => sub {
    my ($chat,$who,$phrase) = @_;
    my $entry = [ time, $who, $phrase ];
    push @{$chat->{entries}}, $entry;
    $chat->notify( 'history', $entry );
 };
 
 on 'get_history' => sub {
    my ($chat,$lines) = @_;
    return [ @{$chat->{entries}}[ -$lines .. -1 ] ];
 };
 
 INIT {
    MyChatServer->spawn('Server#1');
 };

 package main;
 use MyChatServer;
 use AnyEvent;
 
 my $client = MyChatServer->reference('Server#1');
 $client->request( 'get_history', [ 10 ] => sub {
    my ($client,$entries) = @_;
    printf( "%s, %s: %s\n", @$_ ) for @$entries;
    $client->subscribe( 'history' => sub {
        my ($client,$entry) = @_;
        printf "%s, %s: %s\n", @$entry;
    });
 });
 
 my $io = AE::io *STDIN, 0 => sub {
    my $phrase = <STDIN>;
    $client->send( 'say', 'MyNickName', $phrase );
 };
 
 DARLY::run(); # or AE::cv->recv();

=head1 DESCRIPTION

TODO Write about Actor Model.

=head1 METHODS

=head2 on $event [, \&handler ]

Declare new handler for a message C<$event> and an optional callback C<\&handler>
in the caller's package. Messages are can be either notified by C<send> method
or requested by C<request> method of an L<actor|DARLY::actor> object.

C<on> is exported when DARLY is C<use>'ed.

=head2 future [ \&callback ]

Spawn new L<future|DARLY::future>-object with an optional filtering callback C<\&callback>.
Future object can be returned from event handler saying that there is no immediately
available result, but that result would be available later.

C<future> is exported when DARLY is C<use>'ed.

=head2 sender

When calling from the message handler callback, returns current message sender.
Returns C<undef> when calling outside of the event handler callback or when
there is no sender associated with the message.

C<sender> is exported when DARLY is C<use>'ed.

=head2 init( %options )

Initialize or reinitialize DARLY. Allowed options are:

=over 4

=item listen => 1 | \( "host:port", ... )

Allow listening for inter-node connections. Expect reference to array of I<host:port>
addresses to bind to. Other true value means to listen on default port I<12345>.

=back

=head2 loop()

Enter into event loop.

=head2 run( %options )

Shorthand for C<init> and C<loop> calls.

=head2 shutdown

Exit from event loop.

=head1 SEE ALSO

L<POE>

=head1 AUTHOR

Artem S Vybornov <vybornov@gmail.com>

=head1 LICENSE

This library is free software.
You can redistribute it and/or modify it under the same terms as Perl itself.

=cut
