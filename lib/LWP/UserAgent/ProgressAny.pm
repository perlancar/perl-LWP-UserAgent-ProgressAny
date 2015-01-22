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

sub __add_handlers {
    my $ua = shift;

    $ua->add_handler(response_data => sub {
        my ($resp, $ua, $h, $data) = @_;

        my $task = __get_task_name($resp);

        my $progress = Progress::Any->get_indicator(task=>$task);
        unless ($ua->{_pa_data}{set_target}++) {
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

    $ua->add_handler(response_done => sub {
        my ($resp, $ua, $h) = @_;

        my $task = __get_task_name($resp);

        my $progress = Progress::Any->get_indicator(task=>$task);
        $progress->finish;

        # cleanup so the number of tasks can be kept low. XXX we should do this
        # via API.
        no warnings 'once';
        #delete $Progress::Any::indicators{$task};
    });
}

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    __add_handlers($self);
    $self;
}

1;
# ABSTRACT: See progress for your LWP::UserAgent requests

=head1 SYNOPSIS

Use as L<LWP::UserAgent> subclass:

 use LWP::UserAgent::ProgressAny;
 use Progress::Any::Output;

 my $ua = LWP::UserAgent::ProgressAny->new;
 Progress::Any::Output->set("TermProgressBarColor");
 my $resp = $ua->get("http://example.com/some-big-file");
 # you will see a progress bar in your terminal

Use with standard LWP::UserAgent or other subclasses:

 use LWP::UserAgent;
 use LWP::UserAgent::ProgressAny;
 use Progress::Any::Output;

 my $ua = LWP::UserAgent->new;
 LWP::UserAgent::ProgressAny::__add_handlers($ua);
 Progress::Any::Output->set("TermProgressBarColor");
 my $resp = $ua->get("http://example.com/some-big-file");


=head1 DESCRIPTION

This module lets you see progress indicators when you are doing requests with
L<LWP::UserAgent>.

This module uses L<Progress::Any> framework.


=head1 SEE ALSO

L<LWP::UserAgent::ProgressBar> (LU::PB) is a similar module. It uses
L<Term::ProgressBar> to display progress bar and introduces two new methods:
C<get_with_progress> and C<put_with_progress>. Compared to
LWP::UserAgent::ProgressAny (LU::PA): LU::PA uses L<Progress::Any> so you can
get progress notification via means other than terminal progress bar simply by
choosing another progress output. LU::PA is also more transparent, you don't
have to use a different method to do requests.
