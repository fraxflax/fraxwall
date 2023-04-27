#!/usr/bin/perl -w
# $Id: collect_ips.pl,v 1.29 2010-12-29 20:30:49 root Exp $
use strict;
use Mysql;
use Net::DNS;
use Net::DNS::RR;

# Remove ips after stale seconds
my $stale= 604800; # One week: 60*60*24*7 == 604800

# Define host names to look up
my @hosts= (
	    'autodesk.subscribenet.com',
	    'client.akamai.com',
	    'subscription.autodesk.com',
	    'a248.e.akamai.net',
	    'a510.v5372f.c5372.g.vm.akamaistream.net',
	    'a659.v231465.c23146.g.vm.akamaistream.net',
	    'cdimage.debian.org',
	    'cdo.earthcache.net',
	    'crl.microsoft.com',

	    # Eidos / SQEX
	    'connect.eidos.co.uk',
	    'kl2-live-game.metrics.eidos.co.uk',
	    'kl2-live-game.infocast.eidos.co.uk',
	    'kl2-live-game.content.eidos.co.uk',
	    'mail.eidos.co.uk', 
	    'mail.eidos.com', 
	    'remote.eidos.co.uk',
	    'rps.eidos.co.uk',

	    # ClamAV Updates
	    'db.dk.clamav.net',
	    'db.local.clamav.net',
	    'db.northeu.clamav.net',
	    'db.se.clamav.net',
	    'db.southeu.clamav.net',
	    'db.us.clamav.net',

	    # Debian
	    'ftp.dk.debian.org',
	    'ftp.se.debian.org',
	    'security.debian.org',
	    'volatile.debian.org',
	    'www.debian-multimedia.org',

	    'dk.archive.ubuntu.com',
	    'dlsvr01.asus.com',
	    'dlsvr02.asus.com',
	    'dlsvr03.asus.com',
	    'dlsvr04.asus.com',
	    'dlsvr05.asus.com',
	    'dlsvr06.asus.com',
	    'dlsvr07.asus.com',
	    'dlsvr08.asus.com',
	    'dlsvr09.asus.com',
	    'download-ash.nvidia.com',
	    'download.microsoft.com',
	    'download.nvidia.com',
	    'download.qlogic.com',
	    'download.windowsupdate.com',
	    'download1.nvidia.com',
	    'ftp.acc.umu.se',
	    'ftp.us.dell.com',
	    'fullproduct.download.microsoft.com',
	    'gamespot.com',
	    'gamespot.download.akamai.com',
	    'gametrailers.com',
	    'gamevideos.com',
	    'gensho.acc.umu.se',
	    'global.ds.microsoft.com',
	    'ign.com',
	    'install.anark.com',
	    'lyssna-wm.sr.se',
	    'media.xstream.dk', 
	    'mlmeetings.webex.com',
	    'mms-live.media.tele.dk',
	    'mms-vod.media.tele.dk',
	    'mms00-live.media.tele.dk',
	    'mms01-live.media.tele.dk',
	    'mms01-vod.media.tele.dk',
	    'mms02-live.media.tele.dk',
	    'mms02-vod.media.tele.dk',
	    'mms03-live.media.tele.dk',
	    'mms03-vod.media.tele.dk',
	    'mms04-live.media.tele.dk',
	    'mms04-vod.media.tele.dk',
	    'mms05-live.media.tele.dk',
	    'mms05-vod.media.tele.dk',
	    'mms06-live.media.tele.dk',
	    'mms06-vod.media.tele.dk',
	    'mms07-live.media.tele.dk',
	    'mms07-vod.media.tele.dk',
	    'mms08-live.media.tele.dk',
	    'mms08-vod.media.tele.dk',
	    'mms09-live.media.tele.dk',
	    'mms09-vod.media.tele.dk',
	    'ms.groovygecko.net',
	    'orion.acc.umu.se',
	    'qstream-wm.qbrick.com',
	    'rixfm.str.mtgradio.dgcsystems.net',
	    'rmlive.bbc.co.uk',
	    'saimei.acc.umu.se',

	    # Spotify
	    'b1.spotify.com',
	    'b2.spotify.com',
	    'b3.spotify.com',

	    'sr-wm.qbrick.com',
	    'srd.ds.microsoft.com',
	    'stream.msn.co.il',
	    'support.microsoft.com',
	    'support.qlogic.com',
	    'svn.digium.com',
	    'trac-hacks.org',
	    'update.microsoft.com',
	    'windowsupdate.microsoft.com',
	    'wine.budgetdedicated.com',
	    'wmsc.dr.dk',
	    'wmscr2.dr.dk',
	    'www.anark.com',
	    'www.gamespot.com',
	    'www.gametrailers.com',
	    'www.gamevideos.com',
	    'www.igm.com',
	    'www.kernel.org',
	    'www.source-elements.com',
	    'www.update.microsoft.com',
	    'www2.ati.com',
	    );


my $verbose= my $forcereload= 0;
while(defined(my $o= shift @ARGV)) {
    if($o=~ m/^-[vV]$/) {
	++$verbose;
    } elsif($o=~ m/^-[rR]$/) {
	$forcereload= 1;
    }
}

my $dbh= Mysql->connect('localhost', 'noproxy', 'noproxy', 'noproxy')
    or die 'DB Connection';

my $ts= time - $stale;

$dbh->query("delete from dstip where ts < $ts")
    or die "DB Query, delete: ".$dbh->errmsg;

my %ips= ();
my $sth= $dbh->query("select ip from dstip")
    or die "DB Query, select: ".$dbh->errmsg;
while((my $ip)= $sth->fetchrow) { $ips{$ip}= ''; }

my $res= Net::DNS::Resolver->new(nameservers => [qw(127.0.0.1 172.21.0.10)],
				 recurse     => 1,
				 debug       => 0);
my @sockets= ();
for my $hst (@hosts) {
    push @sockets, $res->bgsend($hst, 'A');
}
$ts= time;
my $reload= 0;
for my $s (@sockets) {
    my $packet = $res->bgread($s);
    undef $s;
    my @answer = $packet->answer;
    for my $rr (@answer) { 
	next unless($rr->class eq 'IN' 
		    and $rr->type eq 'A' && 
		    $rr->rdlength == 4);
	if(exists $ips{$rr->rdatastr}) {
	    print 'Updating: ',$rr->name, ' = ', $rr->rdatastr, "\n" if $verbose;
	    $dbh->query("update dstip set ts=$ts,descr='".$rr->name."' where ip='".$rr->rdatastr."'")
		or die "DB Query, update: ".$dbh->errmsg;
	} else {
	    print 'Inserting: ',$rr->name, ' = ', $rr->rdatastr, "\n" if $verbose;
	    $dbh->query("insert into dstip (ip,ts,descr) values('".$rr->rdatastr."',$ts,'".$rr->name."')")
		or die "DB Query, insert: ".$dbh->errmsg;
	    $ips{$rr->rdatastr}= '';
	    $reload= 1;
	}
    }
}
exit 0 unless $reload || $forcereload;

print "\nUpdating noproxy chain:\n" if $verbose;
my $fwres= `/sbin/iptables --table nat --flush noproxy 2>&1`;
print "/sbin/iptables --table nat --flush noproxy:\n$fwres" if $verbose;
exit 1 if length($fwres);
for my $ip (keys %ips) {
    $fwres= `/sbin/iptables --table nat --append noproxy --destination $ip --protocol tcp --destination-port 80 --jump ACCEPT\n 2>&1`;
    print "$ip: $fwres\n" if $verbose;
}
exit 0;
