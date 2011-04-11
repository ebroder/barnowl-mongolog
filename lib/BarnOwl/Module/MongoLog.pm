use local::lib;
use warnings;
use strict;

package BarnOwl::Module::MongoLog;
our $VERSION = 0.1;

use BarnOwl;
use BarnOwl::Hooks;

use boolean;
use DateTime;
use MongoDB;

our $messages = undef;

sub fail {
    my $msg = shift;
    $messages = undef;
    BarnOwl::admin_message('MongoLog Error', $msg);
    die("MongoLog Error: $msg\n");
}

sub config {
    my ($conn, $db);
    eval {
        $conn = MongoDB::Connection->new('host' => 'mongodb://localhost:41803');
    };
    if ($@) {
        fail("Unable to connect: $@");
    }

    $db = $conn->barnowl;
    $messages = $db->messages;
}

sub to_boolean {
    return not(defined $_[0]) ? false :
        "$_[0]" ? true : false;
}

sub handle_message {
    my $m = shift;
    if (!$messages) {
        return;
    }

    $m = {%{$m}};

    delete $m->{'id'};
    delete $m->{'deleted'};
    delete $m->{'zwriteline'};
    delete $m->{'isprivate'};
    delete $m->{'isauto'};
    if (exists($m->{'unix_time'})) {
        $m->{'time'} = DateTime->from_epoch(epoch => $m->{'unix_time'});
        delete $m->{'unix_time'};
    }

    foreach (qw/should_wordwrap private/) {
        if (exists($m->{$_})) {
            $m->{$_} = to_boolean($m->{$_});
        }
    }

    # I don't care about ZAUTH_FAILED vs. ZAUTH_NO, so I'm just going
    # to collapse them
    if (exists($m->{'auth'})) {
        $m->{'auth'} = to_boolean($m->{'auth'} == 'YES');
    }

    if ($m->{'login'} eq 'none') {
        delete $m->{'login'};
    }

    $messages->insert($m);
}

config;

eval {
    $BarnOwl::Hooks::receiveMessage->add('BarnOwl::Module::MongoLog::handle_message');
};
if ($@) {
    $BarnOwl::Hooks::receiveMessage->add(\&handle_message);
}

1;
