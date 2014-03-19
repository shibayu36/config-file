#!/usr/bin/env perl

use Config::Pit;
use IPC::Run qw(run);
use WebService::Hatena::Fotolife;
use Path::Tiny;

my $config = pit_get("f.hatena.ne.jp", require => {
    username   => "username",
    upload_key => "upload_key",
    folder     => "folder",
});
my $username   = $config->{username};
my $upload_key = $config->{upload_key};
my $folder     = $config->{folder};

my $file = path('/tmp/screencapture.png');
$file->remove;
system "screencapture -i $file";

if ($file->exists) {
    my $hatena = WebService::Hatena::Fotolife->new;
    $hatena->username($username);
    $hatena->password($upload_key);

    my ($date) =  $hatena->createEntry(
        title    => $ARGV[0],
        filename => $file,
        folder   => $folder,
    ) =~ /(\d{14})$/;
    my $url = sprintf(
        "http://f.st-hatena.com/images/fotolife/%s/%s/%s/%s_original.png",
        substr($username, 0, 1),
        $username,
        substr($date, 0, 8),
        $date,
    );

    run(['echo', $url], '|', [qw(pbcopy)]);
    system "open $url";
    print "Successfully uploaded: $url\n";
}
