#!/usr/bin/env perl
use strict;
use warnings;
use utf8;

use Test::More;
use Test::UsedModules;

my $commit_range = shift @ARGV || 'origin/devel...HEAD';

open my $fh, '-|', 'git', "diff", "--stat", "--name-only", $commit_range or die "Can't open pipe: $!";
my $changed_files = [
    map { chomp $_; $_ } <$fh>,
];
close $fh;

my $target_files = [ grep { $_ =~ /(?:\.pm|\.t)\z/ } @$changed_files ];
for my $file (@$target_files) {
    used_modules_ok($file);
}

done_testing();
