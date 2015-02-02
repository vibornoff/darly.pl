#!/usr/bin/env perl
use lib::abs qw( lib ../lib );

use strict;
use warnings;

use Test::More;

use AnyEvent;
use DARLY;

my $f = future { 3 };
ok ( $f, "Create future object" );
ok ( $f->isa('DARLY::actor'), "future is an actor" );
ok ( $f = 1, "Dereference future object" );

$f = future;
ok( $f, "Create naked future object" );
ok ( $f = 1, "Dereference naked future object" );

my ($t,$r);
$t = AE::timer 1, 0, $f = future { 1 };
ok ( $f, "Create 1sec-delayed future object" );
$f->cv->cb( sub { @_ = shift->recv; $r = $_[0]; });
ok ( $f->cv->recv,  "Wait for delayed future" );
is ( "$r", '1', "Got right result and value from the future" );

$t = AE::timer 2, 0, $f = future { 2 };
ok ( $f, "Create 2sec-delayed future object" );
( my $f2 = future )->($f);
ok( $f2, "Create proxy future object" );
$f2->cv->cb( sub { @_ = shift->recv; $r = $_[0]; } );
ok ( $f2->cv->recv,  "Wait on proxy future" );
is ( "$r", '2', "Got right result and value from the proxy future" );

# TODO call future as coderef

# TODO send 'result' event to future

# TODO send 'error' event to future

# TODO early dereference future object

done_testing();
