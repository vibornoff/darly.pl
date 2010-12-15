use inc::Module::Install;

name        'DARLY';
all_from    'lib/DARLY.pm';

requires    'AnyEvent';

recommends  'EV';

auto_install;
WriteAll;
