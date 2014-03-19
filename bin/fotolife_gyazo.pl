#!/usr/bin/env perl

use Config::Pit;
use IPC::Run qw(run);
use WebService::Hatena::Fotolife;
use Path::Tiny;
use LWP::UserAgent;

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

    my $foto_url = get_image_url($username, $date);

    run(['echo', $foto_url], '|', [qw(pbcopy)]);
    system "open $foto_url";
    print "Successfully uploaded: $foto_url\n";
}

sub get_image_url {
    my ($username, $date) = @_;

    my $url_base = sprintf(
        "http://f.st-hatena.com/images/fotolife/%s/%s/%s/",
        substr($username, 0, 1),
        $username,
        substr($date, 0, 8),
    );
    my $original_image_url = $url_base . "$date\_original.png";
    my $image_url = $url_base . "$date.png";

    my $ua = LWP::UserAgent->new;
    for my $url ($original_image_url, $image_url) {
        return $url if $ua->head($url)->is_success;
    }
}
