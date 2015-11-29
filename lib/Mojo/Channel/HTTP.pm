package Mojo::Channel::HTTP;

use Mojo::Base 'Mojo::Channel';

has tx => sub { Mojo::Transaction->new };

sub close {
  my $self = shift;
  $self->{state} = 'finished';
  $self->tx->_announce_finish;
}

sub incoming { die 'meant to be overloaded by subclass' }

sub is_finished { (shift->{state} // '') eq 'finished' }

sub is_server { undef }

sub is_writing { (shift->{state} // 'write') eq 'write' }

sub outgoing { die 'meant to be overloaded by subclass' }

sub resume {
  my $self = shift;
  $self->{state} = 'write';
  $self->tx->_announce_resume;
}

sub write {
  my $self = shift;
  return '' unless $self->{state} eq 'write';

  # Nothing written yet
  $self->{$_} ||= 0 for qw(offset write);
  my $msg = $self->outgoing;
  @$self{qw(http_state write)} = ('start_line', $msg->start_line_size)
    unless $self->{http_state};

  # Start-line
  my $chunk = '';
  $chunk .= $self->_start_line($msg) if $self->{http_state} eq 'start_line';

  my $server = $self->is_server;

  # Headers
  $chunk .= $self->_headers($msg, $server) if $self->{http_state} eq 'headers';

  # Body
  $chunk .= $self->_body($msg, $server) if $self->{http_state} eq 'body';

  return $chunk;
}

sub _body {
  my ($self, $msg, $finish) = @_;

  # Prepare body chunk
  my $buffer = $msg->get_body_chunk($self->{offset});
  my $written = defined $buffer ? length $buffer : 0;
  $self->{write} = $msg->content->is_dynamic ? 1 : ($self->{write} - $written);
  $self->{offset} += $written;
  if (defined $buffer) { delete $self->{delay} }

  # Delayed
  else {
    if   (delete $self->{delay}) { $self->{state} = 'paused' }
    else                         { $self->{delay} = 1 }
  }

  # Finished
  $self->{state} = $finish ? 'finished' : 'read'
    if $self->{write} <= 0 || defined $buffer && $buffer eq '';

  return defined $buffer ? $buffer : '';
}

sub _headers {
  my ($self, $msg, $head) = @_;

  # Prepare header chunk
  my $buffer = $msg->get_header_chunk($self->{offset});
  my $written = defined $buffer ? length $buffer : 0;
  $self->{write} -= $written;
  $self->{offset} += $written;

  # Switch to body
  if ($self->{write} <= 0) {
    $self->{offset} = 0;

    # Response without body
    if ($head && $self->tx->is_empty) { $self->{state} = 'finished' }

    # Body
    else {
      $self->{http_state} = 'body';
      $self->{write} = $msg->content->is_dynamic ? 1 : $msg->body_size;
    }
  }

  return $buffer;
}

sub _start_line {
  my ($self, $msg) = @_;

  # Prepare start-line chunk
  my $buffer = $msg->get_start_line_chunk($self->{offset});
  my $written = defined $buffer ? length $buffer : 0;
  $self->{write} -= $written;
  $self->{offset} += $written;

  # Switch to headers
  @$self{qw(http_state write offset)} = ('headers', $msg->header_size, 0)
    if $self->{write} <= 0;

  return $buffer;
}

1;

