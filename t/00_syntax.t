#!/usr/bin/env perl
use lib::abs qw( ../lib 00_syntax );

use strict;
use warnings;

use Test::More;

use_ok('DARLY');
use_ok('DARLY::kernel');
use_ok('DARLY::actor');

{
    package Syntax;
    use DARLY;

    topic 'foo';
    event 'bar' => sub {
    };
}

ok( Syntax->meta(), "get meta" );

done_testing();
