package Mojo::Channel::HTTP::Client;

use Mojo::Base 'Mojo::Channel::HTTP';

sub close {
  my ($self, $close) = @_;

  # Premature connection close
  my $res = $self->tx->res->finish;
  if ($close && !$res->code && !$res->error) {
    $res->error({message => 'Premature connection close'});
  }

  # 4xx/5xx
  elsif ($res->is_status_class(400) || $res->is_status_class(500)) {
    $res->error({message => $res->message, code => $res->code});
  }

  return $self->SUPER::close;
}

sub incoming { shift->tx->res }

sub outgoing { shift->tx->req }

sub read {
  my ($self, $chunk) = @_;

  # Skip body for HEAD request
  my $res = $self->tx->res;
  $res->content->skip_body(1) if uc $self->tx->req->method eq 'HEAD';
  return unless $res->parse($chunk)->is_finished;

  # Unexpected 1xx response
  return $self->{state} = 'finished'
    if !$res->is_status_class(100) || $res->headers->upgrade;
  $self->tx->_handle_unexpected;
  return if (my $leftovers = $res->content->leftovers) eq '';
  $self->read($leftovers);
}

sub write {
  my $self = shift;

  # Client starts writing right away
  $self->{state} ||= 'write';
  $self->SUPER::write;
}

1;
