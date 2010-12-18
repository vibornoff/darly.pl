package URI::darly;
use base 'URI::_server';

require DARLY::kernel;

use strict;
use warnings;

sub default_port { ${DARLY::kernel::DEFAULT_PORT} }

1;
