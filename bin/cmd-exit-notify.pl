#!/usr/bin/env perl
use strict;
use warnings;

my $lastcmd = join ' ', @ARGV;

my $current = $ENV{WINDOW} or exit;

my $windows = qx{ tmux list-windows };

my $active;
for my $win (split "\n", $windows) {
    if ($win =~ /^(\d+):.*\(active\)$/) {
        $active = $1;
        last;
    }
}

if ($current != $active) {
    open my $fh, "|/usr/local/bin/growlnotify -t 'GNU screen window $current'" or die $!;
    print $fh sprintf 'command done: "%s"', $lastcmd;
    print $fh "\n";
    close $fh;
}
