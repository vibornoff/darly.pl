use inc::Module::Install;

name            'DARLY';
all_from        'lib/DARLY.pm';

requires        'AnyEvent';

test_requires   'lib::abs';
test_requires   'Test::More';

recommends      'EV';

auto_install;
WriteAll;
