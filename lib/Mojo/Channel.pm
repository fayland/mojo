package Mojo::Channel;

use Mojo::Base -base;

sub read { die 'meant to be overloaded by subclass' }

sub write { die 'meant to be overloaded by subclass' }

1;

