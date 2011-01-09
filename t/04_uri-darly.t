#!/usr/bin/env perl
use lib::abs qw( lib ../lib );

use strict;
use warnings;

use Test::More;
use URI;

my $uri;

$uri = URI->new('darly://example.com:123/foo');
ok( $uri, "Create URI" );
is( $uri->scheme, 'darly', "URI scheme is correct" );
is( $uri->authority, 'example.com:123', "URI authority is correct" );
is( $uri->host, 'example.com', "URI host is correct" );
is( $uri->port, 123, "URI port is correct" );
is( $uri->path, '/foo', "URI path is correct" );

$uri = URI->new('darly://example.com/bar');
ok( $uri, "Create another URI" );
is( $uri->port, 12345, "Another URI port is correct" );

$uri = URI->new('darly:///baz');
ok( $uri, "Create local URI" );
is( $uri->scheme, 'darly', "Local URI scheme is correct" );
is( $uri->authority, '', "Local URI authority is correct" );
is( $uri->host, undef, "Local URI host is correct" );
is( $uri->port, undef, "Local URI port is correct" );
is( $uri->path, '/baz', "Local URI path is correct" );

done_testing();
