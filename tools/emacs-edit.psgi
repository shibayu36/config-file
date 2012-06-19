# -*- mode:perl -*-
use strict;
use warnings;
use feature qw/ :5.10 /;
use File::Temp qw/ tempfile /;
use IO::File::WithPath;

my ($client) = grep { -e $_ } qw(
    /usr/local/bin/emacsclient
);
die "client not found" unless $client;

sub {
    my $env = shift;
    my ($status, $headers, $body)
        = ( 200, [ "Conetnt-Type" => "text/plain" ], undef );
    given ($env->{PATH_INFO}) {
        when (qr{^/status}) {
            $body = [ "OK" ];
        }
        when (qr{^/edit}) {
            # HTTP body をテンポラリファイルに書き込む
            my ($tmpfh, $tmpfile) = tempfile();
            my $buf;
            print $tmpfh $buf while read $env->{"psgi.input"}, $buf, 4096;
            close $tmpfh;

            # emacsclient 起動
            system($client, $tmpfile) != 0
                and warn $!;

            # テンポラリファイルの内容を送信
            push @$headers, ( "Content-Length" => -s $tmpfile );
            $body = IO::File::WithPath->new($tmpfile);
            unlink $tmpfile;
        }
        default {
            $status = 404;
            $body   = [ "NotFound" ];
        }
    }
    return [ $status, $headers, $body ];
}
