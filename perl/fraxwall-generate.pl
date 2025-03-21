#!/usr/bin/perl -w
# $Id: fraxwall-generate.pl,v 1.49 2010-02-04 11:12:27 root Exp $
use strict;

# Only the lonely ... tadidam
die "\nI'm only interested in helping you if you\ncan make me rich (or if you are root)!\n\n"
    unless $> == 0;

# Default Configuration
my %config= (LOG_LEVEL => 'debug',
	     LOG_PREFIX => 'FW ',
	     FINAL_FILE => '/etc/init.d/fraxwall',
	     TMP_DIR    => '/var/spool/fraxwall',
	     BACKUP_DIR => '/var/backups/fraxwall',
	     IPTABLES   => '/sbin/iptables',
	     RULES_FILE => '');

(my $finalfilename= $config{'FINAL_FILE'})=~ s|.*/([^/]+)$|$1|;
my $rcinfo= ("* Please make sure that the init-references are in place!\n".
	  "* E.g. in Debian, etch:\n".
	  "* >>> update-rc.d $finalfilename start 40 S . <<<");

# Get commandline arguments
my $verbose= 0;
my $rulesfile= '';
my $configfile= my $current_file= 'DEFAULT CONFIGURATION';
my $current_rfcnt= 0;
while(defined(my $o= shift @ARGV)) {
    &usage unless $o =~ m/^-[rRcCvV]$/;
    if($o=~ m/^-[vV]$/) {
	$verbose= 1;
	next;
    }
    &usage unless defined(my $f= shift @ARGV);
    if($o=~ m/^-[rR]$/) {
	unless(-f $f && -r $f) {
	    warn "\nNo such readable rulesfile file: $f\n";
	    &usage;
	}
	$rulesfile= $f;
    } else {
	unless(-f $f && -r $f) {
	    warn "\nNo such readable configuration file: $f\n";
	    &usage;
	}
	$configfile= $f;
    }
}

# Read configfile
unless(-f $configfile) {
    for my $cnff ('/etc/fraxwall/fraxwall.conf',
		  '/etc/fraxwall.conf',
		  './fraxwall.conf') {
	if(-f $cnff && -r $cnff) {
	    $configfile= $cnff;
	    last;
	}
    }
}
if(-f $configfile) {
    warn "\nUsing Configuration File $configfile!\n\n";
    unless(open(CF, "<$configfile")) {
	warn "\nFailed to open config file, '$configfile': $!\n";
	&usage;
    }
    $current_file= $configfile;
    my $rfcnt= 0;
    while(defined(my $ln= <CF>)) {
	++$rfcnt;
	chomp $ln;
	$ln=~ s/^\s*([^\#]*).*/$1/;
	$ln=~ s/\s+$//;
	next unless length($ln);

	# Spilt opt = value
	my $opt= my $value= '';
	if($ln =~m /^([^=]+)=(.+)/) {
	    ($opt,$value)= ($1,$2);
	    $opt=~ s/\s+$//;
	    $value=~ s/^\s+//;
	} else {
	    &error($configfile, $rfcnt, "Syntax error, missing '=', option or value!");
	}
	&error($configfile, $rfcnt, "Unknown option '$opt'!\n!\n! Valid options are:\n".
	       "! LOG_LEVEL, LOG_PREFIX, FINAL_FILE, TMP_DIR, BACKUP_DIR, IPTABLES, RULES_FILE")
	    unless $opt=~ m/^(LOG_LEVEL|LOG_PREFIX|FINAL_FILE|TMP_DIR|BACKUP_DIR|IPTABLES|RULES_FILE)$/;
	if($value=~ m/^\'(.*)\'$/ || $value=~ m/^\"(.*)\"$/) {
	    $value= $1;
	}
	$config{$opt}= $value;
    }
    close CF;
} else {
    &prompt_cont("\nWARNING!!!\nUsing Default Configuration!\n");
}
##fraxtmp:
#$config{'TMP_DIR'}= '/tmp/fraxwall';
#$config{'BACKUP_DIR'}= '/tmp/fraxwall/backup';
    

# Check configuration

# LOG_LEVEL
&error($configfile ,'LOG_LEVEL', 
       "\n! LOG_LEVEL must be one of:\n! debug, info, notice, warning, err, crit, alert, emerg")
    unless $config{'LOG_LEVEL'}=~ m/^(debug|info|notice|warning|err|crit|alert|emerg)$/;

# LOG_PREFIX
&error($configfile ,'LOG_PREFIX', 
       "\n! LOG_PREFIX must be a string 0-29 characters")
    if length($config{'LOG_PREFIX'}) > 29;


# FINAL_FILE
unless(-f $config{'FINAL_FILE'} && -x $config{'FINAL_FILE'}) {
    &error($configfile ,'FINAL_FILE', 
	   "\n! '$config{'FINAL_FILE'}' exists but is not an executable file,\n".
	   "! please move it out of the way or make it an executable file,\n".
	   "! so it can be backed up, before rerunning this script. Also,\n$rcinfo") 
	if -e $config{'FINAL_FILE'};
    &warning(1,$configfile ,'FINAL_FILE', "'$config{'FINAL_FILE'}' does not exists\n$rcinfo");
}

# TMP_DIR
unless(-d $config{'TMP_DIR'}) {
    &warning(1,$configfile ,'TMP_DIR', 
	     "\n! '$config{'TMP_DIR'}' does not exists or is not a directory, trying to create it");
    mkdir $config{'TMP_DIR'} or die "mkdir $config{'TMP_DIR'}: $!\n";
    warn "Successfully created '$config{'TMP_DIR'}'.\n";
    chown(0, 0, $config{'TMP_DIR'}) or warn "!\n! chown $config{'TMP_DIR'}: $!\n!\n";
    chmod(0755, $config{'TMP_DIR'}) or warn "!\n! chmod $config{'TMP_DIR'}: $!\n!\n";
}

# BACKUP_DIR
unless(-d $config{'BACKUP_DIR'}) {
    &warning(1,$configfile ,'BACKUP_DIR', 
	     "\n! '$config{'BACKUP_DIR'}' does not exists or is not a directory, trying to create it");
    mkdir $config{'BACKUP_DIR'} or die "mkdir $config{'BACKUP_DIR'}: $!\n";
    warn "Successfully created '$config{'BACKUP_DIR'}'.\n";
    chown(0, 0, $config{'BACKUP_DIR'}) or warn "!\n! chown $config{'BACKUP_DIR'}: $!\n!\n";
    chmod(0755, $config{'BACKUP_DIR'}) or warn "!\n! chmod $config{'BACKUP_DIR'}: $!\n!\n";
}

# IPTABLES
# + list valid icmp types
my %icmptypes= ();
open(IPT, "$config{'IPTABLES'} --protocol icmp -h|")
    or &error($configfile ,'IPTABLES',"\n! ",
              -x $config{'IPTABLES'} 
	      ? "Failed to execute:\n! '$config{'IPTABLES'} --protocol icmp -h;"
              : "$config{'IPTABLES'} is not an executable file!");
my $vfsh= 0;
while(defined(my $ln=<IPT>)) {
    unless($vfsh) {
	$vfsh= 1 if $ln=~ m/^Valid ICMP Types:\s*$/;
	next;
    }
    next unless $ln=~ m/^\s*([^\s]+)\s*(.*)/;
    $icmptypes{$1}= 1;
    $ln= $2;
    while($ln=~ m/^\(([^)]+)\)\s*(.*)/) {
	$icmptypes{$1}= 1;
	$ln= $2;
    }

}
close IPT;

# RULES_FILE
if(-f $rulesfile) {
    $config{'RULES_FILE'}= $rulesfile;
} elsif(length $config{'RULES_FILE'}) {
    &error($configfile ,'RULES_FILE', 
	   "\n! No such readable rulesfile file: '$config{'RULES_FILE'}'\n")
        unless -f $config{'RULES_FILE'} && -r $config{'RULES_FILE'};
    $rulesfile= $config{'RULES_FILE'};
} else {
    open(HN, "</etc/hostname") or die "open /etc/hostname: $!\n";
    my $hn= <HN>;
    close HN;
    chomp $hn;
    for my $rf ("/etc/fraxwall/rules-$hn/fraxwall.rules",
		"/etc/fraxwall/rules/fraxwall-$hn.rules",
		"/etc/fraxwall/fraxwall-$hn.rules",
		"/etc/fraxwall-$hn.rules",
		"./rules-$hn/fraxwall.rules",
		"./rules/fraxwall-$hn.rules",
		"./fraxwall-$hn.rules",
		"/etc/fraxwall/rules/fraxwall.rules",
		"/etc/fraxwall/fraxwall.rules",
		"/etc/fraxwall.rules",
		"./rules/fraxwall.rules",
		"./fraxwall.rules") {
	if(-f $rf && -r $rf) {
	    $config{'RULES_FILE'}= $rulesfile= $rf;
	    last;
	}
    }
}
unless(-f $rulesfile) {
    warn "\nCould not find readable rules file!\n";
    &usage;
}
warn "\nUsing RULES_FILE $config{'RULES_FILE'}!\n\n";

# list real interfaces
my %realifc= ();
open(IFCONFIG, "/sbin/ifconfig -a |")
    or die "Can not list interfaces with '/sbin/ifconfig -a': $!\n";
while(defined(my $ln=<IFCONFIG>)) {
#    print "\n$ln";
    next unless $ln =~ m/^([^\s]+):\s/;
#    print "- $1\n";
    $realifc{$1}= 1;
}
close IFCONFIG;
#exit 0;

# list valid protocols
my %protocols= ();
open(PROTO, "</etc/protocols")
    or die "open /etc/protocols: $!\n";
while(defined(my $ln=<PROTO>)) {
    $ln =~ s/^\s+//;
    next unless $ln =~ m/^([^\s\#]+)\s+[0-9]+\s*(.*)/;
    $protocols{$1}= 1;
    $ln= $2;
    while($ln=~ m/^([^\s\#]+)\s*(.*)/) {
	$protocols{$1}= 1;
	$ln= $2;
    }
}
close PROTO;
for my $proto ('tcp','udp','icmp','all') {
    $protocols{$proto}= 1;
}

# list valid services
my %services= ();
open(SERVS, "</etc/services")
    or die "open /etc/services: $!\n";
while(defined(my $ln=<SERVS>)) {
    $ln =~ s/^\s+//;
    next unless $ln =~ m/^([^\s\#]+)\s+[0-9]+\/[^\s]+\s*(.*)/;
    $services{$1}= 1;
    $ln= $2;
    while($ln=~ m/^([^\s\#]+)\s*(.*)/) {
	$services{$1}= 1;
	$ln= $2;
    }
}
close SERVS;

# parse rules file
my %ifcname= ( 'ALL' => 'ALL', '_FW_' => 'FW', 'PROXY' => 'PROXY' );
my %defines= ( 'localhost' => '127.0.0.1' );
my @rules= ();
my @section= '';
my $secstr= '';
$current_file= $rulesfile;
$current_rfcnt= 0;
my $noport= 0;
my $icmp= 0;
&read_rules($rulesfile);

# Now let's create the skeleton of the final file
open(SPOOL, ">$config{'TMP_DIR'}/$finalfilename.$$")
    or die "create $config{'TMP_DIR'}/$finalfilename.$$: $!\n";
print SPOOL<<EOS1;
#!/bin/bash
### BEGIN INIT INFO
# Provides:          fraxwall
# Required-Start:    udev
# Required-Stop:
# Default-Start:     S
# Default-Stop:
# Short-Description: Starts firewall
# X-Start-Before:    networking
### END INIT INFO

### /etc/systemd/system/fraxwall.service
# [Unit]
# Description=fraxwall 
# After=udev.service
# Before=network.target
# 
# [Service]
# ExecStart=/etc/init.d/fraxwall start
# 
# [Install]
# WantedBy=sysinit.target
###
# systemctl daemon-reload
# systemctl enable fraxwall.service
# systemctl start fraxwall.service
###

if [[ "\$2" = "debug" ]]; then
  ipt () { echo $config{'IPTABLES'} "\$*" ; }
  shell () { echo "\$*" ; }
else 
  ipt () { $config{'IPTABLES'} "\$@" ||{ echo -e "iptables ERROR -- fraxwall ABORTED -- FIX MANUALLY NOW!\n\$@"; exit 1 ;} ;}
  shell () { "\$@" ||{ echo "Custom line ERROR -- fraxwall ABORTED -- FIX MANUALLY NOW!"; exit 1 ;} ;}
fi
EOS1
    ;
print SPOOL<<'EOS';
case "$1" in
clear)
ipt --table filter --policy INPUT ACCEPT
ipt --table filter --policy FORWARD ACCEPT
ipt --table filter --policy OUTPUT ACCEPT
ipt --table nat --policy PREROUTING ACCEPT
ipt --table nat --policy POSTROUTING ACCEPT
ipt --table nat --policy OUTPUT ACCEPT
ipt --table filter --flush
ipt --table nat --flush
ipt --table filter --delete-chain
ipt --table nat --delete-chain
;;
stop)
echo "# Entering RESTRICTED mode"
ipt --table filter --policy INPUT DROP
ipt --table filter --policy FORWARD DROP
ipt --table filter --policy OUTPUT ACCEPT
ipt --table nat --policy PREROUTING ACCEPT
ipt --table nat --policy POSTROUTING ACCEPT
ipt --table nat --policy OUTPUT ACCEPT
ipt --table filter --flush
ipt --table nat --flush
ipt --table filter --delete-chain
ipt --table nat --delete-chain
ipt --table filter --new-chain fraxwall-stopped
ipt --table filter --insert INPUT --jump fraxwall-stopped
ipt --table filter --append fraxwall-stopped --protocol icmp --jump ACCEPT
ipt --table filter --append fraxwall-stopped --protocol tcp --destination-port 22 --jump ACCEPT
ipt --table filter --append fraxwall-stopped --jump DROP
;;
restart)
$0 start "$2"
;;
start)
$0 stop "$2"
echo "# Setting up ACCEPT_ANSWER chain"
ipt --table filter --new-chain ACCEPT_ANSWER
ipt --table filter --append ACCEPT_ANSWER --match state --state ESTABLISHED --jump ACCEPT
ipt --table filter --append ACCEPT_ANSWER --match state --state RELATED --jump ACCEPT
echo "# Setting up LOG-chains"
ipt --table filter --new-chain LOG_DROP
ipt --table filter --append LOG_DROP --jump DROP
ipt --table filter --new-chain LOG_REJECT
ipt --table filter --append LOG_REJECT --jump REJECT
EOS
    ;
print SPOOL ('ipt --table filter --insert LOG_DROP --jump LOG --log-tcp-options --log-ip-options --log-prefix "',
	     "$config{'LOG_PREFIX'}DROP:\" --log-level $config{'LOG_LEVEL'} \n",
	     'ipt --table filter --insert LOG_REJECT --jump LOG --log-tcp-options --log-ip-options --log-prefix "',
	     "$config{'LOG_PREFIX'}REJECT:\" --log-level $config{'LOG_LEVEL'}\n");

# define chains and process rules
my %chains= ();
for my $r (@rules) {
    if(exists $r->{'ipt'}) {
	print SPOOL "ipt $r->{'ipt'}\n";
	next;
    }
    if(exists $r->{'shell'}) {
	print SPOOL "shell $r->{'shell'}\n";
	next;
    }
    # Setup and jump-to iifc-oifc chain
    my $chain= '';
    if(exists($r->{'i'}) && exists($r->{'o'})) {
	$chain= "$ifcname{$r->{'i'}}-$ifcname{$r->{'o'}}";
	unless(exists $chains{$r->{'t'}}{$chain}) {
	    print SPOOL ("echo \"# Setting up $chain $r->{'t'}-chain\"\n",
			 "ipt --table $r->{'t'} --new-chain $chain\n"); 
	    $chains{$r->{'t'}}{$chain}= {};
	}
	unless(exists $chains{$r->{'t'}}{$chain}{"$r->{'i'}-$r->{'o'}"}) {
#	    print SPOOL ("ipt --table $r->{'t'} --append ", 
#			 #always append, even for iifc ALL # $r->{'i'} eq 'ALL' ? 'insert ' : 'append ', 
	    print SPOOL ("ipt --table $r->{'t'} --", 
			 $r->{'i'} eq 'ALL' ? 'insert ' : 'append ', 
                         $r->{'t'} eq 'filter'
		         ? ($r->{'o'} eq '_FW_' ? 'INPUT' : $r->{'i'} eq '_FW_' ? 'OUTPUT' : 'FORWARD')
                         : ($r->{'o'} eq 'PROXY' ? 'PREROUTING' : 'POSTROUTING'),
                         $r->{'i'} =~ m/^(_FW_|ALL)$/ ? '' 
                         : $r->{'i'} =~ m/^phy=(.*)/ ? " --match physdev --physdev-in $1" : " --in-interface $r->{'i'}",
                         $r->{'o'} =~ m/^(_FW_|ALL|PROXY)$/ ? '' 
                         : $r->{'o'} =~ m/^phy=(.*)/ ? " --match physdev --physdev-out $1" : " --out-interface $r->{'o'}",
                         " --jump '$chain'\n");
#	    print SPOOL ("ipt --table filter --append INPUT --jump 'ALL-ALL'\n",
#			 "ipt --table filter --append OUTPUT --jump 'ALL-ALL'\n")
#		if $chain eq 'ALL-ALL' && $r->{'t'} eq 'filter';
            $chains{$r->{'t'}}{$chain}{"$r->{'i'}-$r->{'o'}"}= 1;
	}
    }
    # Setup and jump-to user defined chain
    if(exists($r->{'chain'})) {
	unless(exists $chains{$r->{'t'}}{$r->{'chain'}}) {
	    print SPOOL ("echo \"# Setting up $r->{'chain'} $r->{'t'}-chain\"\n",
			 "ipt --table $r->{'t'} --new-chain $r->{'chain'}\n");
	    $chains{$r->{'t'}}{$r->{'chain'}}= {};
        }
        if(length($chain) && !exists($chains{$r->{'t'}}{$r->{'chain'}}{$chain})) {
	    print SPOOL ("ipt --table $r->{'t'} --append '$chain' --jump '$r->{'chain'}'\n");
            $chains{$r->{'t'}}{$r->{'chain'}}{$chain}= 1;
        }
        $chain= $r->{'chain'};
    }
    next if $r->{'a'} eq 'chain';

    print SPOOL ("ipt --table $r->{'t'} --$r->{'a'} '$chain' ",

		 $r->{'s'} eq 'ALL' ? '' :
		 $r->{'s'} =~ m/:/ ? "--match mac --mac-source $r->{'s'} " :
		 "--source $r->{'s'} ",
		 
		 $r->{'d'} eq 'ALL' ? '' :
		 "--destination $r->{'d'} ",
		 
		 $r->{'prot'} eq 'ALL' ? '' :
		 "--protocol $r->{'prot'} ",
		 
		 $r->{'dprt'} eq 'ALL' ? '' :
		 $r->{'prot'} eq 'icmp' ? "--icmp-type $r->{'dprt'} " :
		 "--destination-port $r->{'dprt'} ",
	  
		 "--jump ",
		 $r->{'j'} eq 'ACCEPT' ? 'ACCEPT' :
		 $r->{'t'} eq 'filter' ? $r->{'j'} :
		 $r->{'j'} eq 'REDIRECT' ? "REDIRECT --to-port $r->{'pprt'}" : 
		 $r->{'j'} eq 'DNAT' ? "DNAT --to-destination $r->{'psrv'}:$r->{'pprt'}" :
		 $r->{'j'} eq 'SNAT' ? "SNAT --to-source $r->{'nsrc'}" :
		 $r->{'j'},

		 "\n");

}

# finish up finalfile
print SPOOL<<'EOFF';
ipt --table filter --insert INPUT --jump ACCEPT_ANSWER
ipt --table filter --insert FORWARD --jump ACCEPT_ANSWER
ipt --table filter --insert OUTPUT --jump ACCEPT_ANSWER
ipt --table filter --append INPUT --jump LOG_DROP
ipt --table filter --append FORWARD --jump LOG_DROP
ipt --table filter --append OUTPUT --jump LOG_DROP
echo "# Leaving restricted mode"
ipt --table filter --delete INPUT --jump fraxwall-stopped
echo "# FIREWALL UP and RUNNING"
;;
*)
echo "Usage: $0 {start|restart|stop|clear} [debug]"
exit 1
;;
esac
exit 0
EOFF
    ;
close SPOOL;
chown(0, 0, "$config{'TMP_DIR'}/$finalfilename.$$") or warn "!\n! chown $config{'TMP_DIR'}/$finalfilename.$$: $!\n!\n";
chmod(0555, "$config{'TMP_DIR'}/$finalfilename.$$") or warn "!\n! chmod $config{'TMP_DIR'}/$finalfilename.$$: $!\n!\n";

# diff files
if(open(OLD, "<$config{'FINAL_FILE'}")) {
    open(SPOOL, "<$config{'TMP_DIR'}/$finalfilename.$$") 
	or die "diffopen '$config{'TMP_DIR'}/$finalfilename.$$':\n$!\n";
    my $diff= 0;
    while(1) {
	my $spool= <SPOOL>;
	my $old= <OLD>;
	next if defined($spool) && defined($old) && $spool eq $old;
	last unless defined($spool) || defined($old);
	$diff= 1;
	last;
    }
    close SPOOL;
    close OLD;
    unless($diff) {
	warn("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n",
	     "Generated file does not differ from '$config{'FINAL_FILE'}'.\n",
	     "No need to run or install ...\nCleaning up tmp and exiting ...\n");
	unlink "$config{'TMP_DIR'}/$finalfilename.$$" 
	    or warn "Failed to remove '$config{'TMP_DIR'}/$finalfilename.$$': $!\n";
	warn "\nDone.\n\n";
	exit 0;
    }
}

&prompt_cont("\n-------------------------------------------------------------------------------\n",
	     "New file '$config{'TMP_DIR'}/$finalfilename.$$' generated.\n\n",
	     "Next step will run it in debug mode (echoing instead of applying all rules)\n");

system("$config{'TMP_DIR'}/$finalfilename.$$", 'restart', 'debug');

&prompt_cont("\n-------------------------------------------------------------------------------\n",
	     "If the above went well (you may want to review the output or the file, \n",
	     "$config{'TMP_DIR'}/$finalfilename.$$, itself before continuing).\n\n",
	     "The next step is to execute it in it's current location\n",
	     "WITHOUT installing it firstly, leaving your old firewall in place.\n");

system("$config{'TMP_DIR'}/$finalfilename.$$", 'restart');

(my $ext,my $min,my $hour,my $mday,my $mon,my $year)= localtime(time);
$ext= sprintf("%04d%02d%02d_%02d%02d%02d", $year+1900, $mon+1, $mday, $hour, $min, $ext);
&prompt_cont("\n-------------------------------------------------------------------------------\n",
	     "If you are satisfied, continue to install\n",
	     "'$config{'TMP_DIR'}/$finalfilename.$$' as '$config{'FINAL_FILE'}'.\n\n",
	     "if '$config{'FINAL_FILE'}' already exists it will be backed up as\n",
	     "$config{'BACKUP_DIR'}/$finalfilename.$ext\n");

if(-f $config{'FINAL_FILE'} && -x $config{'FINAL_FILE'}) {
    system('/bin/mv', '-v', "$config{'FINAL_FILE'}", "$config{'BACKUP_DIR'}/$finalfilename.$ext")
	and &prompt_cont("!\n! WARNING!\n",
			 "! FAILED to backup '$config{'FINAL_FILE'}' to '$config{'BACKUP_DIR'}/$finalfilename.$ext'\n",
			 "! Please do so manually before continuing\n");
}
system('/bin/mv', '-v', "$config{'TMP_DIR'}/$finalfilename.$$", "$config{'FINAL_FILE'}")
    and die("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n",
	    "! Failed to install $config{'FINAL_FILE'}, please do it manually from\n",
	    "! '$config{'TMP_DIR'}/$finalfilename.$$'\n\n$rcinfo\n");


warn("\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n",
     "Installation successfull!\n\n",
     "$rcinfo\n\n",
     "Also, if applicable, rember to check in your changes (if any)\n",
     "of the rules & configuration!\n\n");
exit 0;


###
sub read_rules
{
    unless(open(RF, "<$_[0]")) {
	if($_[0] eq $current_file) {
	    warn "\nFailed to open rules file, '$_[0]': $!\n";
	    &usage;
	}
	&error($current_file, $current_rfcnt, "failed to open included file, '$_[0]': $!");
    }
    my @RF= <RF>; # Must read entire file to be able to use recursion on includes (recursion destroys file handle)
    close RF;
    my $file= $_[0];
    my $rfcnt= 0;
    my $append_next= '';
    while(defined(my $ln= shift(@RF))) {
	++$rfcnt;
	chomp $ln;
	$ln=~ s/^\s*([^\#]*).*/$1/;
	$ln=~ s/\s+$//;
	
	# wrapped line?
	if($ln=~ s/\\$//) {
	    $append_next.= $ln;
	    next;
	}
	if(length($append_next)) {
	    $ln= "$append_next $ln";
	    $append_next= '';
	}
	next unless length($ln);

	# New section?
	if($ln =~ m/^\[\s*([^\]]+)\]$/) {
	    @section= &split_subst(',', $1);
	    SEC:for my $sec (@section) {
		next if $sec =~ m/^(ALL|DEFINE|PROXY)$/;
		next if exists $ifcname{$sec};
		if($sec =~ m/(phy=)?(.*)\+$/) {
		    my $prefix= $2;
		    for my $ifc (keys %realifc) {
			if($ifc=~ m/^${prefix}/) {
			    $ifcname{$sec}= $sec unless exists $ifcname{$sec};
			    next SEC;
			}
		    }
		}
		my $pifc= $sec;
		$pifc=~ s/^phy=//;
		&warning($pifc !~ m/^(ppp|tun|vif)/, $file, $rfcnt, "(out)interface '$pifc' ($sec) does not exists on machine")
		    unless exists $realifc{$pifc};
		$ifcname{$sec}= $sec;
	    }
	    $secstr= join '|', @section;
	    &error($file,$rfcnt, 
		   "You can not combine DEFINE, ALL & PROXY\n",
		   "sections with interfaces or each other!")
		if $#section && $secstr =~ m/(DEFINE|ALL|PROXY)/;
	    next;
	}

	# Spilt param = value
	my $param= my $value= '';
	if($ln =~m /^([^=]+)=(.+)/) {
	    ($param,$value)= ($1,$2);
	    $param=~ s/\s+$//;
	    $value=~ s/^\s+//;
	} else {
	    &error($file, $rfcnt, "Missing '=', parameter or value!");
	}
   
	# include
	if($param eq 'include') {
	    warn "\n$file,$rfcnt:\nIncluding '$value'.\n" if $verbose;
	    $current_file= $file;
	    $current_rfcnt= $rfcnt;
	    &read_rules($value);
	    next;
	}

	# iptables
	if($param eq 'iptables') {
	    &warning(1, $file,$rfcnt,
		     "\n* Found suspicios character, ';', '&' or '|', in iptables value.\n* ",
		     "Are you sure you want ot add the following iptables command?\n* ",
		     "\n   'iptables $value'\n")
		if $value=~ m/;&\|/m;
	    warn "\n$file,$rfcnt:\niptables $value\n" if $verbose;
	    push @rules, { 'ipt' => $value };
	    next;
	}

	# shell
	if($param eq 'shell') {
	    warn "\n$file,$rfcnt:\nadding custom line to script:\n'$value'\n" if $verbose;
	    push @rules, { 'shell' => $value };
	    next;
	}

	# are we in a section?
	&error($file, $rfcnt, "'parameter = value' pair outside section\n")
	    unless scalar(@section);

	# DEFINING?
	if($secstr eq 'DEFINE') {
	    &error($file, $rfcnt, "'$param' already defined!")
		if exists $defines{$param};
	    $defines{$param}= $value;
	    next;
	}


	my @ifc= my @src= my @dst= my @proto= my @port= '';
	my $action= 'append';
	$noport= $icmp= 0;

	my @vals= &split_subst(';', $value);

	if($secstr eq 'PROXY') {

	    # PROXY parameter
	    if($param eq 'PROXY') {
		if(scalar(@vals) == 8) {
		    $action= pop @vals;
		    &error($file, $rfcnt, "Bad action, must be 'insert' or 'append'")
			unless $action =~ m/^(insert|append)$/;
		}
		&error($file,$rfcnt, "Wrong number of arguments (missing or extra ';' ?)")
		    unless scalar(@vals) == 7;
		@ifc= &get_ifc(shift(@vals), $file, $rfcnt);
		@src= &get_src(shift(@vals), $file, $rfcnt);
		@dst= &get_dst(shift(@vals), $file, $rfcnt);
		@proto= &get_proto(shift(@vals), $file, $rfcnt);
		@port= &get_port(shift(@vals), $file, $rfcnt);
		my @psrv= &get_dst(shift(@vals), $file, $rfcnt);
		my @pprt= &get_port(shift(@vals), $file, $rfcnt);
		for my $i (@ifc) {
		    for my $s (@src) {
			for my $d (@dst) {
			    for my $prot (@proto) {
				for my $p (@port) {
				    for my $ps (@psrv) {
					$ps= 'ALL' if $ps eq '127.0.0.1';
					for my $pp (@pprt) {
					    push @rules, { 
						't' => 'filter',
						'a' => $action,
						'j' => 'ACCEPT',
						'o' => $ps eq 'ALL' ? '_FW_' : 'PROXY',
						'i' => $i,
						's' => $s,
						'd' => $ps,
						'prot' => $prot,
						'dprt' => $pp };

					    push @rules, { 
						't' => 'nat',
						'a' => $action,
						'j' => $ps eq 'ALL' ? 'REDIRECT' : 'DNAT',
						'o' => 'PROXY',
						'i' => $i,
						's' => $s,
						'd' => $d,
						'prot' => $prot,
						'dprt' => $p,
						'psrv' => $ps,
						'pprt' => $pp };
					}
				    }
				}
			    }
			}
		    }
		}
		next;
	    }

	    # DIRECT parameter
	    if($param eq 'DIRECT') {
		$action= 'insert';
		if(scalar(@vals) == 6) {
		    $action= pop @vals;
		    &error($file, $rfcnt, "Bad action, must be 'insert' or 'append'")
			unless $action =~ m/^(insert|append)$/;
		}
		&error($file,$rfcnt, "Wrong number of arguments (missing or extra ';' ?)")
		    unless scalar(@vals) == 5;
		@ifc= &get_ifc(shift(@vals), $file, $rfcnt);
		@src= &get_src(shift(@vals), $file, $rfcnt);
		@dst= &get_dst(shift(@vals), $file, $rfcnt);
		@proto= &get_proto(shift(@vals), $file, $rfcnt);
		@port= &get_port(shift(@vals), $file, $rfcnt);
		for my $i (@ifc) {
		    for my $s (@src) {
			for my $d (@dst) {
			    for my $prot (@proto) {
				for my $p (@port) {
				    push @rules, { 
					't' => 'nat',
					'a' => $action,
					'j' => 'ACCEPT',
					'o' => 'PROXY',
					'i' => $i,
					's' => $s,
					'd' => $d,
					'prot' => $prot,
					'dprt' => $p };
				}
			    }
			}
		    }
		}
		next;
	    }
	    
	    &error($file, $rfcnt, "Invalid parameter '$param', Only PROXY and DIRECT allowed in PROXY section!");
	}


	# name parameter
	if($param eq 'NAME') {
	    if($secstr eq 'ALL' || $#section) {
		&warning(1,$file, $rfcnt,
			 'name parameter declared in ALL or multiple interfaces section ... parameter ignored!');
		next;
	    }	    
	    &error($file, $rfcnt, "illegal character in, or too long, name '$value'\n",
		   "(only a-z & 0-9 are allowed, and max 14 characters)")
		unless $value =~ m/^[a-z0-9]+$/ && length($value) < 15;
	    &error($file, $rfcnt, "name for interface $secstr already declared")
		if exists $ifcname{$secstr} && $ifcname{$secstr} ne $secstr;
	    $ifcname{$secstr}= $value;
	    next;
	}

	#  ACCEPT,[N]REJECT,[N]DROP parameters
	if($param =~ m/^(ACCEPT|N?REJECT|N?DROP)$/) {
	    my $jump= $param;
	    $jump=~ s/^([DR])/LOG_$1/ || $jump=~ s/^N//;
	    
	    my $chain= '';
	    if(scalar(@vals) == 7) {
		$chain= pop @vals;
		&error($file, $rfcnt, "chain-name must be 1-29 characters long")
		    unless length($chain) > 0 && length($chain) < 30;
	    }
	    if(scalar(@vals) == 6) {
		$action= pop @vals;
		&error($file, $rfcnt, "Bad action, must be 'insert' or 'append'")
		    unless $action =~ m/^(insert|append)$/;
	    }
	    &error($file,$rfcnt, "Wrong number of arguments (missing or extra ';' ?)")
		unless scalar(@vals) == 5;
	    @ifc= &get_ifc(shift(@vals), $file, $rfcnt);
	    @src= &get_src(shift(@vals), $file, $rfcnt);
	    @dst= &get_dst(shift(@vals), $file, $rfcnt);
	    @proto= &get_proto(shift(@vals), $file, $rfcnt);
	    @port= &get_port(shift(@vals), $file, $rfcnt);
	    if(length($chain)) {
		# If own defined chain, jump to it from all interface-combination,
		for my $o (@section) {
		    for my $i (@ifc) {
			push @rules, { 
			    't' => 'filter',
			    'a' => 'chain',
			    'o' => $o,
			    'i' => $i,
			    'chain' => $chain,
			};
		    }
		}
		# But insert rules only once
		for my $s (@src) {
		    for my $d (@dst) {
			for my $prot (@proto) {
			    for my $p (@port) {
				push @rules, { 
				    't' => 'filter',
				    'a' => $action,
				    'j' => $jump,
				    's' => $s,
				    'd' => $d,
				    'prot' => $prot,
				    'dprt' => $p,
				    'chain' => $chain,
				};
			    }
			}
		    }
		}
		next;
	    }

	    for my $o (@section) {
		for my $i (@ifc) {
		    for my $s (@src) {
			for my $d (@dst) {
			    for my $prot (@proto) {
				for my $p (@port) {
				    push @rules, { 
					't' => 'filter',
					'a' => $action,
					'j' => $jump,
					'o' => $o,
					'i' => $i,
					's' => $s,
					'd' => $d,
					'prot' => $prot,
					'dprt' => $p,
				    };
				}
			    }
			}
		    }
		}
	    }
	    next;
	}

	# NAT parameter
	if($param eq 'NAT') {
	    if(scalar(@vals) == 6) {
		$action= pop @vals;
		&error($file, $rfcnt, "Bad action, must be 'insert' or 'append'")
		    unless $action =~ m/^(insert|append)$/;
	    }
	    &error($file,$rfcnt, "Wrong number of arguments (missing or extra ';' ?)")
		unless scalar(@vals) == 5;
	    my @nsrc= &get_dst(shift(@vals), $file, $rfcnt);
	    @src= &get_src(shift(@vals), $file, $rfcnt);
	    @dst= &get_dst(shift(@vals), $file, $rfcnt);
	    @proto= &get_proto(shift(@vals), $file, $rfcnt);
	    @port= &get_port(shift(@vals), $file, $rfcnt);
	    for my $o (@section) {
		for my $ns (@nsrc) {
		    for my $s (@src) {
			for my $d (@dst) {
			    for my $prot (@proto) {
				for my $p (@port) {
				    push @rules, { 
					't' => 'nat',
					'a' => $action,
					'j' => $ns eq 'ALL' ? 'MASQUERADE' : 'SNAT',
					'o' => $o,
					'i' => 'ALL',
					's' => $s,
					'd' => $d,
					'prot' => $prot,
					'dprt' => $p,
				        'nsrc' => $ns };
				}
			    }
			}
		    }
		}
	    }
	    next;
	}

	# Unknown parameter
	&error($file, $rfcnt, "Unknown parameter '$param'!");

    }
}

###
sub get_port
{
    (my $str, my $file, my $rfcnt)= @_;
    my @ports= ();
    for my $port (&split_subst(',', $str)) {
	if($port=~ m/^([^:]*):([^:]*)$/) { # range
	    (my $p1, my $p2)= ($1,$2);
	    $p1= 0 if $p1 =~ m/^\s*$/;
	    $p2= 65535 if $p2 =~ m/^\s*$/;
	    ($p1)= &get_port($p1);
	    ($p2)= &get_port($p2);
	    push @ports, "$p1:$p2";
	} elsif($port eq 'ALL') {
	    push @ports, 'ALL';
	} elsif($noport && $icmp) {
	    &error($file,$rfcnt, "You can only use port 'ALL' if you are mixing icmp with other protocols.");
	} elsif($noport) {
	    &error($file,$rfcnt, "You can only use port 'ALL' except if you are specifying following protocols:\n".
		   "! 'dccp', 'tcp', 'udp', 'sctp' or 'icmp'");	    
	} elsif($port =~ m/^[0-9]+$/ || 
		(!$icmp && exists($services{$port})) || 
		($icmp && exists($icmptypes{$port}))) {
	    push @ports, $port;
	} else {
	    &error($file,$rfcnt, "Invalid dest-port '$port',\n! ".
		   "must be numeric or exist in /etc/services for tcp/udp, or be listed by iptables for icmp!");
	}
    }
    unless(&check_all(@ports)) {
	&warning(1,$file, $rfcnt, 
		 "Useless combination of 'ALL' and other dest-port(s)\n* ".
		 "... ignoring other dest_port(s)");
	@ports=('ALL');
    }
    return @ports;
}

###
sub get_proto
{
    (my $str, my $file, my $rfcnt)= @_;
    my @protos= ();
    for my $proto (&split_subst(',', $str)) {
	if($proto =~ m/^all$/i) {
	    push @protos, 'ALL';
	} elsif($proto =~ m/^[0-9]+$/ || exists($protocols{$proto})) {
	    $noport= 1 unless $proto =~ m/^(dccp|tcp|udp|sctp|icmp)$/;
	    $icmp= 1 if $proto eq 'icmp';
	    push @protos, $proto;
	} else {
	    &error($file,$rfcnt, "Invalid protocol '$proto',\n! ".
		   "must be numeric, exist in /etc/protocols or be one of 'tcp', 'udp', 'icmp', or 'all'!");
	}
    }
    unless(&check_all(@protos)) {
	&warning(1,$file, $rfcnt, 
		 "Useless combination of 'ALL' and other protocol(s)\n* ".
		 "... ignoring other protocol(s)");
	@protos=('ALL');
    }
    $noport= 1 if $#protos && $icmp;
    return @protos;
}

###
sub get_dst
{
    (my $str, my $file, my $rfcnt)= @_;
    my @dsts= ();
    for my $dst (&split_subst(',', $str)) {
	if($dst eq 'ALL') {
	    push @dsts, 'ALL';
	} elsif(my $ip= &valid_ip($dst)) {
	    push @dsts, $ip;
	} else {
	    &error($file,$rfcnt, "Destination address '$dst' must be valid IP[/mask] address!");
	}
    }
    unless(&check_all(@dsts)) {
	&warning(1,$file, $rfcnt, 
		 "Useless combination of 'ALL' and other dest-addr(s)\n* ".
		 "... ignoring other dest-addr(s)");
	@dsts=('ALL');
    }
    return @dsts;
}
###
sub get_src
{
    (my $str, my $file, my $rfcnt)= @_;
    my @srcs= ();
    for my $src (&split_subst(',', $str)) {
	if($src eq 'ALL') {
	    push @srcs, 'ALL';
	} elsif($src =~ m/^00(:[0-9a-f]{2}){5}$/i) { # mac address
	    push @srcs, lc($src);
#	} elsif($src =~ m/^00(:[0-9a-f]{2}){5}:00(:[0-9a-f]{2}){5}:08:00$/i) { # ap+mac
#	    push @srcs, lc($src);
	} elsif(my $ip= &valid_ip($src)) {
	    push @srcs, $ip;
	} else {
	    &error($file,$rfcnt, "Source address '$src' must be valid IP[/mask] or mac address!");
	}
    }
    unless(&check_all(@srcs)) {
	&warning(1,$file, $rfcnt, 
		 "Useless combination of 'ALL' and other source-addr(s)\n* ".
		 "... ignoring other source-addr(s)");
	@srcs=('ALL');
    }
    return @srcs;
}
###
sub get_ifc
{
    (my $str, my $file, my $rfcnt)= @_;
    my @ifcs= ();
    IFC:for my $ifc (&split_subst(',', $str)) {
	push @ifcs, $ifc;
	next if $ifc eq 'ALL' || exists $ifcname{$ifc};
	if($ifc =~ m/(phy=)?(.*)\+$/) {
	    my $prefix= $2;
	    for my $rifc (keys %realifc) {
		if($rifc=~ m/^${prefix}/) {
		    $ifcname{$ifc}= $ifc unless exists $ifcname{$ifc};
		    next IFC;
		}
	    }
	}
	my $pifc= $ifc;
	$pifc=~ s/^phy=//;
	&warning($pifc !~ m/^(ppp|tun|vif)/, $file, $rfcnt, "(in)interface '$pifc' ($ifc) does not exists on machine")
	    unless exists $realifc{$pifc};
	$ifcname{$ifc}= $ifc;
    }
    unless(&check_all(@ifcs)) {
	&warning(1,$file, $rfcnt, 
		 "Useless combination of 'ALL' and other interface(s)\n* ".
		 "... ignoring other interface(s)");
	@ifcs=('ALL');
    }
    return @ifcs;
}
###
sub check_all
{
    return 1 if scalar(@_) == 1;
    for my $a (@_) {
	return 0 if $a eq 'ALL';
    }
    return 1;
}
###
sub error
{
    (my $f, my $c)= (shift, shift);
    die("!\n! ERROR!\n! $f,$c: ",@_,"\n!\n",
	$current_file eq $f ? '' :
	"! ... included from $current_file, $current_rfcnt\n!\n");
}
###
sub warning
{
    (my $p, my $f, my $c)= (shift, shift, shift);
    warn("*\n* WARNING!\n* $f,$c: ",@_,"\n",
	 $current_file eq $f ? '' :
	 "* ... included from $current_file, $current_rfcnt\n");
    &prompt_cont('') if $p;
}
###
sub prompt_cont
{
    warn @_, "\nPress [RETURN] to continue, Ctrl-c to abort\n";
    <STDIN>;
}
###
sub valid_ip
{
    (my $a, my $n)= split /\//, $_[0];
    my @addr= split /\./, $a;
    return 0 unless scalar(@addr) == 4;
    for(my $i=0; $i < 4; ++$i) {
	$addr[$i]= &check_octet($addr[$i]);
	return 0 if $addr[$i] == -1;
    }
    $a= join ".", @addr;
    if(defined $n) {
	return("$a/".int($n)) if($n =~ m/^[0-9]+$/ && 
				 $n >= 0 && 
				 $n <= 32);
	$n= &valid_ip($n) or return 0;
	print "$a/$n\n";
	return("$a/$n");
    }
    return $a;
}
###
sub check_octet
{
  $_[0] =~ m/^[0-9]+$/ && $_[0] >= 0 && $_[0] <= 255 && return int($_[0]);
  return -1;
}
###
sub usage
{
    die "\nUSAGE: $0 [-v] [-c <configuration-file>] [-r <rulesfile>]\n\n";
}
###
sub split_subst
{
    (my $s, my $str)= @_;
    while(1) {
	my @vals= ();
	my $subst= 0;
	for my $val (split(/\s*${s}\s*/, $str)) {
	    if(exists $defines{$val}) {
		push @vals, $defines{$val};
		++$subst;
	    } else {
		push @vals, $val;
	    }
	}
	return @vals unless $subst;
	$str= join $s, @vals;
    }
}
