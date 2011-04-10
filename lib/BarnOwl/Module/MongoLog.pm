use local::lib;
use warnings;
use strict;

package BarnOwl::Module::MongoLog;
our $VERSION = 0.1;

use BarnOwl;
use BarnOwl::Hooks;

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

sub handle_message {
    my $m = shift;
    if (!$messages) {
        return;
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