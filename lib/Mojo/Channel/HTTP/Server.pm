package Mojo::Channel::HTTP::Server;

use Mojo::Base 'Mojo::Channel::HTTP';

sub incoming { shift->tx->req }

sub is_server { 1 }

sub outgoing { shift->tx->res }

sub read {
  my ($self, $chunk) = @_;
  my $tx = $self->tx;

  # Parse request
  my $req = $tx->req;
  $req->parse($chunk) unless $req->error;
  $self->{state} ||= 'read';

  # Generate response
  return unless $req->is_finished && !$self->{handled}++;
  $tx->_announce_request;
}

1;

