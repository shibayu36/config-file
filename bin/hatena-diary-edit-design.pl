#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp;
use Path::Class;
use WWW::HatenaLogin;
use Script::State;
use Config::Pit;
use HTTP::Cookies;
use IO::Prompt;
use DateTime;

use constant RES_DIR => dir("$ENV{HOME}/.hatenadiarydesign");

script_state my $cookie_jar;
script_state my $last_used;

my $config = pit_get('hatena.ne.jp', require => {
    username => 'username',
    password => 'password',
});

# 前から1日ぐらい経っていたら上書きするユーザを確認する
if ($last_used < time() - (60 * 60 * 12)) {
    my $yn = prompt "will override current style of " . $config->{username} . ", sure? [yN]";
    if ($yn !~ /y/) {
        exit 1;
    }
    $last_used = time();
}

my $hatena = WWW::HatenaLogin->new({
    username => $config->{username},
    password => $config->{password},
    mech_opt => {
        $cookie_jar ? (cookie_jar => $cookie_jar) : ()
    },
    nologin  => 1
});

my $designdetail = sprintf 'http://d.hatena.ne.jp/%s/designdetail', $config->{username};

my $client = $hatena->mech;
$client->get($designdetail);
if ($client->uri ne $designdetail) {
    $hatena->login;
    $client->get($designdetail);
}

my $form = $client->form_id('edit');
my $current = $form->value('style');
warn $current;

$cookie_jar = $hatena->cookie_jar;

sub update_design {
    my ($update) = @_;

    my $client = $hatena->mech;
    $client->get($designdetail);
    my $form = $client->form_id('edit');
    my $current = $form->value('style');

    if ($current ne $update) {
        # make backup
        my $backup = RES_DIR->file(sprintf "%s/backup/%s.css", $config->{username}, DateTime->now->strftime('%Y%m%d%H%M%S'));
        $backup->parent->mkpath;
        my $f = $backup->open('w');
        print $f $current;
        close $f;

        # and update
        $client->submit_form(
            form_id => $form->attr('id'),
            fields  => {
                style => $update,
            }
        );
    }
}

my $fh = File::Temp->new(SUFFIX => '.css');
print $fh $current;
close $fh;
my $observe = 1;
$SIG{CHLD} = sub { $observe = 0; wait; };
if (my $pid = fork) {
    close STDOUT;
    close STDERR;
    # parent
    while ($observe) {
        sleep 1;
        eval {
            my $update = file($fh->filename)->slurp;
            if ($current ne $update) {
                $current = $update;
                update_design($update);
            }
        };
    }
} else {
    # child
    exec $ENV{EDITOR}, $fh->filename;
}
