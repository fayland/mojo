package Mojo::Channel::HTTP::Server;

use Mojo::Base 'Mojo::Channel::HTTP';

sub incoming { shift->tx->req }

sub is_server { 1 }

sub outgoing { shift->tx->res }

1;

