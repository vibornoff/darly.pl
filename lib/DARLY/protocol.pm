package DARLY::protocol::JSON;

use Carp;
use AnyEvent;
use AnyEvent::Handle;
use JSON;

use strict;
use warnings;

use constant DEFAULT_DELIMITER      => "\r\n";      # CRLF
use constant DEFAULT_MAX_BUFFER_SIZE => 1048576;    # 1 MiB

sub anyevent_read_type {
    my $cb = $_[1];
    sub {
        my $hdl = $_[0];

        while ( ( my $idx = index $hdl->{rbuf}, DEFAULT_DELIMITER ) != -1 ) {
            my $message = substr( $hdl->{rbuf}, 0, $idx );
            substr( $hdl->{rbuf}, 0, $idx + length DEFAULT_DELIMITER ) = '';

            $message = eval { decode_json $message };
            if ($@) {
                $hdl->_error( Errno::EBADMSG, 1, $@ );
                return;
            }

            $cb->( $hdl, $message );
        }

        if ( length $hdl->{rbuf} > DEFAULT_MAX_BUFFER_SIZE ) {
            $hdl->_error( Errno::EOVERFLOW, 1, $@ );
            return;
        }
    };
}

sub anyevent_write_type {
    my ($handle, $message) = @_;

    $message = encode_json $message
        if ref $message;

    $message . DEFAULT_DELIMITER;
}

1;
