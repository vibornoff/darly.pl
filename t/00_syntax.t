#!/usr/bin/env perl
use lib::abs qw( ../lib 00_syntax );

use strict;
use warnings;

use Test::More;

use_ok('DARLY');
use_ok('URI::darly');
use_ok('TestActor');

my $anonymous = TestActor->spawn();
ok( $anonymous, "Spawn anonymous actor" );
ok( $anonymous->alias('anonymous'), "Alias anonymous actor" );
ok( $anonymous->alias(undef), "Unalias anonymous actor" );
ok( $anonymous = 1, "Dereference anonymous actor" );

my $aliased = TestActor->spawn('aliased');
ok( $aliased, "Spawn aliased actor" );

ok( $aliased->send( undef, 'bar', [ 'blah' ]), "Send 'bar' event to actor" );
ok( $testvar eq 'blah', "\$testvar got right value 'blah'" );

ok( $aliased->send( undef, 'baz', [ ]), "Send 'baz' event to actor" );
ok( $testvar eq $aliased, "\$testvar got right value '$aliased'" );

ok( $aliased->request( undef, 'bar', [ 'blah' ] => sub { $testvar = 'damn'  }), "Request actor's event" );
ok( $testvar eq 'damn', "\$testvar got right value 'damn'" );

my $nearref = TestActor->reference('darly:///aliased');
ok( $nearref,                                               'Create near reference'     );
ok( $nearref->url->path eq '/aliased',                      'Local url path correct'    );
ok( !defined $nearref->url->host,                           'Local url host undefined'  );
ok( !defined $nearref->url->port,                           'Local url port undefined'  );

ok( $nearref->send( undef, 'bar', [ 'woof!' ]), "Send 'bar' event to actor reference" );
ok( $testvar eq 'woof!', "\$testvar got right value 'woof!'" );

my $test = "Send to non-existent event hahdler";
eval { $nearref->send( undef, 'zap', [] ) };
$test .= $@ ? ": $@" : '';
if ( ref $@ && $@->[0] eq 'DispatchError' ) {
    pass($test);
} else {
    fail($test);
}

my $farref = TestActor->reference('darly://1.2.3.4:444/foo');
ok( $farref,                                                'Create far reference'      );
ok( $farref->url->path eq '/foo',                           'Remote url path correct'   );
ok( $farref->url->host eq '1.2.3.4',                        'Remote url host correct'   );
ok( $farref->url->port eq '444',                            'Remote url port correct'   );

ok( $aliased->shutdown() || 1, "Shutdown actor" );

DARLY::run();

done_testing();
