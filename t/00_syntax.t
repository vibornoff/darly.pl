#!/usr/bin/env perl
use lib::abs qw( ../lib 00_syntax );

use strict;
use warnings;

use Test::More;

use_ok('DARLY');
use_ok('DARLY::kernel');
use_ok('DARLY::actor');
use_ok('DARLY::future');

my $testvar;
{
    package Syntax;
    use DARLY;

    topic 'foo';
    event 'bar' => sub {
        return $testvar = $_[-1];
    };
}

ok( Syntax->meta(), "get meta" );

my $anonymous = Syntax->spawn();
ok( $anonymous, "Spawn anonymous actor" );
ok( $anonymous->alias('anonymous'), "Alias actor" );
undef $anonymous;

my $aliased = Syntax->spawn('aliased');
ok( $aliased, "Spawn aliased actor" );

ok( $aliased->send( 'bar', [ 'blah' ]), "Send event to actor" );
ok( $testvar eq 'blah', "\$testvar got right value" );

ok( $aliased->request( 'bar', [ 'blah' ] => sub { $testvar = 'damn'  }), "Request actor's event" );
ok( $testvar eq 'damn', "\$testvar got right value" );

ok( $aliased->shutdown(), "Shutdown actor" );

DARLY::loop();

done_testing();
