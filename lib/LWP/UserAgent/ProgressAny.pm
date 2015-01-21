package LWP::UserAgent::ProgressAny;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Progress::Any;
use Scalar::Util qw(refaddr);

use parent 'LWP::UserAgent';

sub __get_task_name {
    my $resp = shift;

    # each response object has its own task, so we don't have problem with
    # parallel downloads
    my $task = __PACKAGE__; $task =~ s/::/./g;
    $task .= ".R" . refaddr($resp);
    $task;
}

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->add_handler(response_data => sub {
        my ($resp, $ua, $h, $data) = @_;

        my $task = __get_task_name($resp);

        my $progress = Progress::Any->get_indicator(task=>$task);
        unless ($self->{_pa_data}{set_target}++) {
            $progress->pos(0);
            if (my $cl = $resp->content_length) {
                $progress->target($cl);
            }
        }
        $progress->update(
            pos => $progress->pos() + length($data),
            message => "Downloading " . $resp->{_request}{_uri},
        );

        # so we are called again for the next chunk
        1;
    });

    $self->add_handler(response_done => sub {
        my ($resp, $ua, $h) = @_;

        my $task = __get_task_name($resp);

        my $progress = Progress::Any->get_indicator(task=>$task);
        $progress->finish;

        # cleanup so the number of tasks can be kept low. XXX we should do this
        # via API.
        no warnings 'once';
        delete $Progress::Any::indicators{$task};
    });

    $self;
}

1;
# ABSTRACT: LWP::UserAgent subclass that uses Progress::Any

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 SEE ALSO

L<LWP::UserAgent::ProgressBar> is a similar module. It uses L<Term::ProgressBar>
to display progress bar and introduces two new methods: C<get_with_progress> and
C<put_with_progress>.

