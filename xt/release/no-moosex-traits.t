#!perl
#
# Tests that things work ok without MooseX::Traits installed
#
use strict;
use warnings;
use Test::More tests => 2;
use Test::Exception;
use Module::Mask;
our $mask;
BEGIN { $mask = new Module::Mask ('MooseX::Traits') }
use_ok('Server::Control');
throws_ok { Server::Control->new_with_traits() } qr/MooseX::Traits could not be loaded/;
