package Mojo::Channel::HTTP::Client;

use Mojo::Base 'Mojo::Channel::HTTP';

sub incoming { shift->tx->res }

sub is_server { undef }

sub outgoing { shift->tx->req }

sub _write {
  my $self = shift;

  # Client starts writing right away
  $self->{state} ||= 'write';
  $self->SUPER::write;
}

1;
