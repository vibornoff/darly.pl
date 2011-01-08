#!/usr/bin/env perl
use lib::abs qw( ../lib 00_syntax );

use strict;
use warnings;

use Test::More;

use AnyEvent;
use DARLY;

my $f = future { 3 };
ok ( $f, "Create future object" );
ok ( $f->isa('DARLY::actor'), "future is an actor" );
ok ( $f = 1, "Dereference future object" );

my ($t,$r,$v);
$t = AE::timer 3, 0, $f = future { 3 };
ok ( $f, "Create delayed future object" );
$f->cv->cb( sub { @_ = shift->recv; $r = $_[0]; $v = $_[1][0]; });
ok ( $f->cv->recv,  "Wait future for 3 sec" );
is ( "$r$v", 'result3', "Got right result and value from future" );

# TODO call future as coderef

# TODO send 'result' event to future

# TODO send 'error' event to future

# TODO early dereference future object

done_testing();
