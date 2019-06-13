#!/usr/bin/perl -w

#       Brad Lesnick

#       09/18/15

#       addsw.pl - Add Switches Automaticly Into Flat Files

#       WORKS WITH METRO 1, 2, and 2.0 Hubsites

#       CHECKS DNS BEFORE ADDING WARNS ON PREVIOUS ASSINGED DNS ENTRIES

use lib "/remote_vols/nlan.twtelecom.net/htdocs/modules/perl_modules";

use Data::Dumper;

use Incog;

use addsw;

use File::Copy qw(copy);

use strict;

use warnings;

use NetAddr::IP;

require Exporter;

require Expect;

our @ISA = qw(Exporter);

use strict;

use warnings;

use DBI;

use Switch;

use XML::Parser;

use Data::Dumper;

 

our $username = `whoami`;

chomp ($username);

our $scriptsdirpath = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/bin";

our %metro2hub = ();

our $metroinfopath = "/remote_vols/nlan.twtelecom.net/htdocs/modules/perl_modules/metro.info";

our $tid = $ARGV[0];

if(defined $tid ) { chomp ($tid); }

our $newtid = $tid;

our $metroversion;

our %IPs2add;

our $city;

our $addressentered = "";

our $ringnumber = "";

our $streetaddress = "";

our @tidlist;

our (@gneTIDs, @ringTIDs);

our $isnewring = "YES";

our $asrids;

our $runmode = "-D";

our (@fltfile, @asrfltfile);

our $insertlinenum;

our $banner = "*" x 40;

    $banner = "\n" . $banner . "\n";

our ($asrswitchfile, $newasrswitchfile, $asrswitchlockfile, $switchfile, $newswitchfile, $switchlockfile, $addswlogfile, $log_filename);

our ($mstdomainname, $routetarget, $mgmtvlan, $gateway);

our ($ip_addr, $ospf_ip, $loop_ip, $errorcode);

our %spantdn = (

    ALBQNMXP9K00 => 'ALBQNMXPC6001', ATLNGAGA9K00 => 'ATLNGAGAC6001', AURSCOFW9K00 => 'AURSCOFWC6001', AUSWTXSZ9K00 => 'AUSWTXSZC6001', BLTMMDDN9K00 => 'BLTMMDDNC6001', BNGHNYHN6K00 => 'BNGHNYHNC6001',

    BOIUIDKZ9K00 => 'BOISID35C6001', BRHMAL069K00 => 'BRHMAL06C6001', BRFDWIJZ9K00 => 'MILXWIIXC6001', CHCGILCP9K00 => 'CHCGILCPC6001', CHRLNC329K00 => 'CHRLNC32C6001', CHVLVACF9K00 => 'CHVLVACFC6001',

    CLMASCTS6K00 => 'CLMASCTSC6001', CLMCOHIB9K00 => 'CLMCOHIBC6001', CLMDOH449K00 => 'CLMDOH44C6001', CLSPCO116K00 => 'CLSPCO11C6001', CNCNOHRN9K00 => 'CNCNOHRNC6001', COLNNYEJ9K00 => 'COLNNYEJC6001',

    DLLFTXFQ9K00 => 'DLLFTXFQC6001', DYTNOHKT6K00 => 'DYTNOHKTC6001', ELPSTX989K00 => 'ELPSTX98C6001', FTLDFLTA9K00 => 'FTLDFLTAC6001', FTWOTXFO9K00 => 'FTWOTXFOC6001', GNBPNCDN9K00 => 'GNBPNCDNC6001',

    HSTOTX429K00 => 'HSTOTX42C6001', IPLTINSD9K00 => 'IPLTINSDC6001', IRVECAJT9K00 => 'IRVECAJTC6001', JCVLFLWF9K00 => 'JCVLFLWFC6001', KSCYMOMC9K00 => 'KSCYMOMCC6001', LSANCARC9K00 => 'LSANCARCC6001',

    LSVKNV999K00 => 'LSVKNV99C6001', LSVLKY189K00 => 'LSVLKY18C6001', LTRKARFC9K00 => 'LTRKARFCC6001', MILXWIIX9K00 => 'MILXWIIXC6001', MLUAHIAK9K00 => 'MLUAHIAKC6001', MMPHTNSZ9K00 => 'MMPHTNSZC6001',

    MNNTMNIC9K00 => 'MNNTMNICC6001', NSVOTNAO9K00 => 'NSVOTNAOC6001', NWORLAMO6K00 => 'NWORLAMOC6001', NYCLNYJW9K00 => 'NYCLNYJWC6001', OKLDCAEB9K00 => 'OKLDCAEBC6001', ORLFFLHX9K00 => 'ORLFFLHXC6001',

    PHNZAZDM9K00 => 'PHNZAZDMC6001', PTLEORXM9K00 => 'PTLEORXMC6001', RLGHNCJY9K00 => 'RLGHNCJYC6001', GATSNYAO9K00 => 'ROCHNYEIC6001', SNANTX919K00 => 'SNANTX91C6001', SNDHCAAX9K00 => 'SNDHCAAXC6001',

    SNFCCANV9K00 => 'SNFCCANVC6001', SPKNWAVR9K00 => 'SPKNWAVRC6001', STTLWATA9K00 => 'STTLWATAC6001', TAMQFLPM9K00 => 'TAMQFLPMC6001', TCSMAZEE9K00 => 'TCSMAZEEC6001', TULSOK356K00 => 'TULSOK35C6001',

    WASHDC129K00 => 'WASHDC12C6001', GOLTCAGR6K00 => 'GOLTCAGRC6002',

);

 

 

# COMMAND OPTIONS

unless (($#ARGV == 0) or ($#ARGV == 1)) {       print "Invalid Number of Arguments!\nUSE: -h for help\n"; exit; }

foreach (@ARGV) {

        if (/\b\w{8}(?:W2|C5|C7|C8|WC|4A|4C|Z[E-H])\d{3}\b/i) {

                $tid = $_;

                $tid = uc($tid);

                next;

        }

        elsif (/^-/) {

                $runmode = $_;

                $runmode = uc($runmode);

                next;

        }

}

unless ($tid =~ /\b\w{8}(?:W2|C5|C7|C8|WC|4A|4C|Z[E-H])\d{3}\b/i){

        print "$0 requires a valid TID!\n";

        exit;

}

unless (($runmode eq "-D") or ($runmode eq "-T") or ($runmode eq "-H")) {

        print "INVALID ARGUMENT PASSED TO $0!\nUSE -H FOR THE HELP YOU SO BADLY NEED\n\n";

        exit;

}

 

if ($runmode eq "-D") {

    $asrswitchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/asr-switches";

    $newasrswitchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/asr-switches.new";

    $asrswitchlockfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/asr-switches.locked";

    $switchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/switches";

    $newswitchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/switches.new";

    $switchlockfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/switches.locked";

    $addswlogfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/bin/validation/addsw-incognitio-logfile";

    $log_filename = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/flatlog.txt";

}

 

if ($runmode eq "-T") {

    $asrswitchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/testing-asr-switches";

    $newasrswitchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/testing-asr-switches.new";

    $asrswitchlockfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/testing-asr-switches.locked";

    $switchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/testing-switches";

    $newswitchfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/testing-switches.new";

    $switchlockfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/testing-switches.locked";

    $addswlogfile = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/bin/validation/testing-addsw-logfile";

    $log_filename = "/remote_vols/nlan.twtelecom.net/htdocs/configurator/testing-flatlog.txt";

}

 

########### MAIN

{

    my ($subnet, $addr);

    # PREVENT FAILED LOOKUP

    #`telnet nmscogwsdlv12.twtelecom.com 8080`;

    checkforduptids();

    getlocaladdress();

    getringinfo();

    getmetroversion();

#    print "@gneTIDs\n";

    lookupasrhub() if $metroversion == 3;

 

    print "OBTAINING IP ADDRESS FROM INCOGNITO...\n";

    if($runmode eq "-D" or "-T") {

         if ($metroversion == 1) {

            print "\nMETRO 1\n";

            ($ip_addr, $errorcode) = GetMetro1IP($tid);

            if(defined $ip_addr) { print "$ip_addr\n";  }

            else { print "Error obtaining IP Address from Incognito\n"; exit; }

            ($gateway, $subnet, $addr) = validateipaddress($ip_addr,1);

        }

        elsif ($metroversion == 2 or 3) {

            print "\nMETRO 2 ";

            print "HUB\n" if $metroversion == 3;

            print "\n";

            ($ip_addr, $ospf_ip, $loop_ip, $errorcode) = GetMetro2IP($tid);

           

        

            if((defined $ip_addr) and (defined $ospf_ip) and (defined $loop_ip)) {

                print "$ip_addr - $ospf_ip - $loop_ip\n";

            }

            else { print "Error obtaining IP Address from Incognito\n"; exit; }

            

            my ($ip_addr_last, $loop_ip_last, $ospf_ip_last);

 

            if ($ip_addr =~ m/(\d{1,3})$/) {

                $ip_addr_last = $1;

            }

            if ($loop_ip =~ m/(\d{1,3})$/) {

                $loop_ip_last = $1;

            }

            if ($ospf_ip =~ m/(\d{1,3})$/) {

                $ospf_ip_last = $1;

            }

            if (($ospf_ip_last == 32 + $ip_addr_last) and ($loop_ip_last == 64 + $ip_addr_last)) {

                print "IP Spacing is correct between addresses\n";

            }

            else {

                print "IP SPACING IS WRONG BETWEEN ADDRESSES\n";

                exit;

            }

 

 

            ($gateway, $subnet, $addr) = validateipaddress($ip_addr,2);

            ($gateway, $subnet) = validateipaddress($ospf_ip,2);

            ($gateway, $subnet) = validateipaddress($loop_ip,2);

        }

    }

 

    if(@ringTIDs) {

    # BUILD REGEX WITH ALL RING TIDS

#    print"@ringTIDs\n";

    my $multireg = join ( "|", @ringTIDs );

   

        if($metroversion == 1) {

            my $nextaddr;

            my %ringhash;

            my $lncnt = 1;

            # LOOP OVER ALL LINES IN THE FLAT FILE IF ANY MATCH RING TIDS INSERT LINES INTO HASH

            foreach my $line ( @fltfile ) {

                if($line =~ /^$multireg/ ) {

#                    print $line;

                    $ringhash{$lncnt} = $line;

                }

                $lncnt++;

            }

            print "\n";

            #print "Key: $_ and Value: $ringhash{$_}\n" foreach (keys%ringhash);

            foreach my $line (sort keys %ringhash )  {

                    if( $ringhash{$line} =~ /^\w{13}\s+\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})\b\s+(\w{8}C600\d)\b\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+(40\d{2})\b/i) {

                        my $nextsub = $1;

                        my $nextaddr = $2;

                        $mstdomainname = $3;

                        $gateway = $4;

                        $mgmtvlan = $5;

#                       print "\n nextsub:$nextsub subnet:$subnet addr:$addr nextaddr:$nextaddr\n";

                        if( $nextsub eq $subnet ) {

                            if( $addr < $nextaddr) {

                               next;

                            }  

                        else {

                            $insertlinenum =  $line;

                            $isnewring = "NO";

                        }

 

                    }

              }

        }

print "INSERTING ON LINE - $insertlinenum\n";

        insertmetro1($insertlinenum);

        `cp $newswitchfile $switchfile`;

    }   

    elsif($metroversion == 2 or 3) {

        my $nextaddr;

        my %ringhash;

        my $lncnt = 1;

        foreach my $line ( @asrfltfile ) {

            if($line =~ /$multireg/ ) {

                $ringhash{$lncnt} = $line;

               

                print "$line\n";

            }

            $lncnt++;

        }

       

        foreach my $line (sort keys %ringhash )  {

                if( $ringhash{$line} =~ /^\b\w{13}\b\s+\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})\b\s+\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b\s+\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b\s+\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\b\s+\b(\d{4}\:\d{6})\b\s+\b(\w{8}[C169][6KH]\d{3})\b/gim ) {

                    my $nextsub = $1;

                    my $nextaddr = $2;

                    $gateway = $3;

                    $routetarget = $4;

                    $mstdomainname = $5;

                    my $mo_ip = NetAddr::IP->new("$1$2/27");

                    my $IP_to_check = NetAddr::IP->new("$subnet$addr/27");

                    my $gateway_check = NetAddr::IP->new("$gateway/25");

                    if ($IP_to_check->within($gateway_check)) {

                        print "Gateway is within the same subnet\n";

                    }

                    else {

                        print "Gateway and the Loopback IP's not in same subnet- CHECK INCOGNITO\n";

                        exit;

                    }

#                    print "$nextsub\n";

#                    print "$nextaddr\n";

#                    print "The module Ip check is $mo_ip\n";

#                    print "The Ip to be assigned is $IP_to_check\n";

                    if( $nextsub eq $subnet ) {

                        print "$addr and $nextaddr\n";

                        if ( $addr < $nextaddr) {

                            if( $IP_to_check->within($mo_ip) ) {

                               $insertlinenum = $line - 1;

#                              print "the line check is $line\n";

                               $isnewring = "NO";

                               last;

                               }

                            else {

                               print "Null\n";

                               }     

 

                        }

                        else {

                            $insertlinenum = $line;

                            $isnewring = "NO";

                            next;

 

                        }

 

                    }

              }

        }

  

    if($isnewring eq "YES" ) {

         print "NEW RING DETECTED...\n";

         print "NEW RING FOUND\n";

         newringsetup($metroversion);

         $insertlinenum = 1;

         print "The RING NO is $ringnumber\n";

         print "Place the condition HERE\n";

         my ($capture_ring);

         my ($last_ring_ID);

         my ($line_to_insert);

         my ($capture_ring_grep);


        my ($capture_last);

         if ($ringnumber =~ m/(^\w{1,3})/) {

            $capture_ring = $1;

           print "The Extracted ring name is $capture_ring\n";

            my $capture_last = `cat $asrswitchfile | grep -n Ring | grep $capture_ring 2>&1`;

            print "$capture_last\n";

               if ($capture_last =~ m/(\b(\w|[-])*\s*$)/) {

                  $last_ring_ID = $1;

                  print "Last Ring ID is $last_ring_ID\n";

                  my $capture_ring_grep = `cat $asrswitchfile | grep -n $last_ring_ID 2>&1`;

                  print "Capture Ring Grep is $capture_ring_grep";

                 

                  if ($capture_ring_grep =~ m/(^\d+)/) {

                      $line_to_insert = $1;

                      $insertlinenum = $line_to_insert - 1

                     

                      }

                  else {

                        print "UNKNOWN ERROR 2";

                  }

               }

               else {

                   print "NO GREP OUTPUT NO WORRIES";

               }

 

           

         }

        

    }    

  

    insertmetro2($insertlinenum) if $metroversion == 2;

    insertmetro2($insertlinenum) if $metroversion == 3;

    #    insertmetro2($insertlinenum);

        `cp $newasrswitchfile $asrswitchfile`;

 

    #    print "The CITY is $city\n";

     #   insert_four ($tid,$ringnumber,$city,$ip_addr,$ospf_ip,$loop_ip,$gateway,$routetarget,$mstdomainname,$streetaddress)

}

}

 

 

}

#### END   MAIN

sub lookupasrhub {

 

 

 

}

sub newringsetup {

    my ($ver) = @_;

    $ver = "3";

    chomp ($ver);

    print "The version is $ver\n";

    my ($asrID);

   

    if($ver == 2) {

        print "$ver\n";

        foreach my $gne ( @gneTIDs ) {

       

        if (not defined $spantdn{$asrids}) {

            $mstdomainname = $asrids . "1";

        }

        else {

            $mstdomainname = $spantdn{$asrids};

        }

        if(defined $mstdomainname) {

            my $linecnt = 1;

            foreach my $line (@asrfltfile) {

                if($line =~ /\b$mstdomainname\b/i) {

                 $insertlinenum = $linecnt;

                }

                $linecnt++;

 

            }

 

         }

         else { print "Error finding STPDOMAIN NAME\n"; exit; }

         #last;

    }

    }

    print "$ver\n";

    if ($ver == '3') {

        print "Test Loop\n";

       

        if(not defined $mstdomainname) {

        foreach my $gne (@gneTIDs) {

           

            chomp $gne;

            chop $gne;

            $mstdomainname =  $gne . 1;

            print $mstdomainname;

            last;

        }

    }

   }

        if(defined $mstdomainname) {

            my $linecnt = 1;

            print "$linecnt\n";

            foreach my $line (@asrfltfile) {

                if($line =~ /\b$mstdomainname\b/i) {

                 $insertlinenum = $linecnt;

                }   

                $linecnt++;

 

                }

 

         }

         else { print "Error finding STPDOMAIN NAME\n"; exit; }

         #last;  

    

 

        my @asrringcdi = `$scriptsdirpath/asr_ring_cdi $ringnumber`;

#        print "@asrringcdi\n";

        foreach my $ringinfo ( @asrringcdi ) {

            if ( $ringinfo =~ /\b\d{4}\:\d{6}\b.+\b(\d{4}\:\d{6})\b/ ) {

                $routetarget = $1;

            }

            if(defined $routetarget) { last; }

        }

 

}

sub insertmetro1 {

    my $inline = $insertlinenum;

    my $line1 ;

        print Dumper($isnewring), "\n";

    if (($isnewring eq "YES") and (defined $ringnumber)) {

        print "NEW RINGS NOT SUPPORTED UNDER METRO 1\n";

        exit;

    }

 

    if(not defined $inline) { print "ERROR WITH IMPORTED RSI VALUES\n"; exit; }

 

        our $city =  lc (`getADDYcdi $mstdomainname | cut -f2 -d, | rev | cut -c 4- | rev | cut -c 2-`);

        chomp($city);

        insert_one($tid,$ringnumber,$city,$ip_addr,$mstdomainname,$gateway,$mgmtvlan,$streetaddress);

 

    $line1 = "$tid\t$ip_addr\t$mstdomainname\t$gateway\t$mgmtvlan\t$streetaddress\n";

    print "LINE NUMBER - $inline\n$banner\n";

    open(SWFILE, "<", $switchfile ) or die "Error Opening SWITCHES File\n";

    open(NEWSWFILE, ">", $newswitchfile ) or die "Error Opening New WRITE File\n";

    while ( <SWFILE> ) {

       print NEWSWFILE $_;

       last if $. == $inline;

    }

    if (defined $line1) { print "$line1"; print NEWSWFILE "$line1"; }

    #`if (defined $line2) { print "$line2"; print NEWSWFILE "$line2"; }

   

    while ( <SWFILE> ) {

       print NEWSWFILE $_;

    }

    close (SWFILE);

    close (NEWSWFILE);

    copy $newswitchfile, $switchfile;

}

 

sub insertmetro2 {

    my $inline = $insertlinenum;

    print "Is it a new ring $isnewring\n";

   

    print "This is the ring nmbr $ringnumber\n";

    my ($line1, $line2);

    if (($isnewring eq "YES") and (defined $ringnumber)) {

        $line1 = "#\tRing $ringnumber\n";

        print "$line1\n";

    }

    if(not defined $mstdomainname) {  print "FIRST SWITCH ON ASR MUST BE ADDED BY HAND\n"; exit; }

    if(not defined $routetarget) { print "ERROR FINDING ROUTE TARGET\n"; exit; }

    

        $city =  lc (`getADDYcdi $mstdomainname | cut -f2 -d, | rev | cut -c 4- | rev | cut -c 2-`);

        chomp($city);

        print "This is city $city\n";

        insert_four($tid,$ringnumber,$city,$ip_addr,$ospf_ip,$loop_ip,$gateway,$routetarget,$mstdomainname,$streetaddress);

       

    $line2 = "$tid\t$ip_addr\t$ospf_ip\t$loop_ip\t$gateway\t$routetarget\t$mstdomainname\t$streetaddress\n";

    #if(not defined $inline) { print "ERROR WITH IMPORTED RSI VALUES\n"; exit; }

    print "LINE NUMBER - $inline\n$banner\n";

    open(ASRFILE, "<", $asrswitchfile ) or die "Error Opening ASR-SWITCHES File\n";

    open(NEWASRFILE, ">", $newasrswitchfile ) or die "Error Opening New WRITE File\n";

    my $cnt = 1;

    while ( <ASRFILE> ) {

       print NEWASRFILE "$_";

       last if $. == $inline;

    }

    if (defined $line1) { print "$line1"; print NEWASRFILE "$line1"; }

    if (defined $line2) { print "$line2"; print NEWASRFILE "$line2"; }

   

    while ( <ASRFILE> ) {

       print NEWASRFILE $_;

    }

    close (ASRFILE);

    close (NEWASRFILE);

    my ($log_user);

    my ($log_date);

    my ($log_line1);

    my ($log_line2);

    open (my $LOGFILE, ">>$log_filename") or die "Could not open the Log file\n";

    $log_user = `whoami`;

    $log_date = `date`;

    $log_line1 = $log_user . ' ' . $log_date;

    $log_line2 = "$line2";

    print $LOGFILE "$log_line1";

    print $LOGFILE "$log_line2\n\n\n";

    close $LOGFILE;

    copy $newasrswitchfile, $asrswitchfile;

}

########### CHECK BOTH SWITCH FILES FOR DUPLICATES

sub checkforduptids {

    open(FLATFILE, "<", $switchfile) or die "Error opening switches flat file\n";

    open(ASRFLATFILE, "<", $asrswitchfile) or die "Error opening asr-switches flat file\n";

 

    @fltfile = <FLATFILE> or die "ERROR OPENING FLAT FILE";

    @asrfltfile = <ASRFLATFILE> or die "ERROR OPENING FLAT FILE";

    close ( FLATFILE );

    close ( ASRFLATFILE );

    my @dupswitch = grep (/\b$tid\b/, @fltfile);

    my @dupasrswitch = grep ( /\b$tid\b/, @asrfltfile);

    if(@dupswitch) {

        print $banner;

        print "TID ALREADY FOUND IN SWITCHES FLAT FILE...\n";

        print $banner;

        print "@dupswitch\n";

        exit;

    }

    if(@dupasrswitch) {

        print $banner;

        print "TID ALREADY FOUND IN ASR-SWITCHES FLAT FILE...\n";

        print $banner;

        print "@dupasrswitch\n";

        exit;

    }

}

 

########## GET ADDRESS FROM RSI IF MISSING OBTAIN FROM USER

sub getlocaladdress {

    $streetaddress = `$scriptsdirpath/getstreetaddress $tid`;

    if (($streetaddress eq "" ) || ($streetaddress eq ",\n")) {

        my $validentry = "NO";

        my ($stateid, $cityname, $streetnumber);

        print "STREET ADDRESS COULD NOT BE IMPORTED.\n";

        print "ENTER 2 DIGIT STATE ID:   ";

        while ($validentry eq "NO") {

           $stateid = <STDIN>;

           chomp $stateid unless $stateid eq "";

           if ($stateid =~ /(?:A[LKSZRABEP]|BC|C[AOT]|D[EC]|F[LM]|G[AU]|HI|I[ADLN]|K[SY]|LA|M[ABDEHINOPST]|N[BCDEHJLMVY]|O[HKNR]|P[ARW]|QC|RI|S[CDK]|T[NX]|UT|V[AIT]|W[AIVY])/) {

                $validentry = "YES";

           }

           else {

                print "YOU DID NOT ENTER A VALID STATE ID!\nEXAMPLE FOR COLORADO ENTER CO\nTRY AGAIN:  ";

           }

        } # END WHILE

        $validentry = "NO";

        print "ENTER CITY NAME:  ";

        while ($validentry eq "NO") {

            $cityname = <STDIN>;

            chomp $cityname unless $cityname eq "";

            if($cityname =~ /\w{2,30}/) {

                $validentry = "YES";

            }

            else {

                print "TRY AGAIN!   ENTER THE CITY:  ";

            }       

        } # END WHILE

        $validentry = "NO";

        print "ENTER STREET ADDRESS:   ";

        while ($validentry eq "NO") {

            $streetnumber = <STDIN>;

            chomp $streetnumber unless $streetnumber eq "";

            if($streetnumber =~ /\w{2,50}/) {

                $validentry = "YES";

            }

            else {

                print "INVALID ENTRY TRY AGAIN...\n:";

                print "ADDRESS MUST BE IN THE FOLLOWING FORMAT:  1234 STREET ADDRESS\n\n";

            }

        }   

        $addressentered = $streetnumber . " " . $cityname . ", " . $stateid;

        if ($addressentered eq "")  { die "ABORTING SCRIPT FOR MISSING ADDRESS\n"; }

        else { $streetaddress = $addressentered };

    } # END IF

    chomp ($streetaddress);

    $streetaddress =~ s/^\s//g;

}

 

########### DETERMINE IF THIS IS METRO 1 2 OR 3 FOR METRO 2.0 HUB

sub getmetroversion {

   

    foreach $tid (@tidlist) {

            if ($tid =~ /\b\w{8}(?:|C600|4A00)\d\b/igm) {

                    $metroversion = 1;

                    push (@gneTIDs, $tid);

                    next;

        }  

 

            elsif ($tid =~ /\b(\w{8}(?:|6K00|9K00))\d\b/igm) {

                $asrids = $1;

                    $metroversion = 2;

                    push (@gneTIDs, $tid);

                    next;

            }

            elsif ($tid =~ /\b(\w{8}(?:|1H00|6H00|9H00))\d\b/igm) {

                $asrids = $1;

                    $metroversion = 3;

                    push (@gneTIDs, $tid);

                    next;

            }

            elsif($tid =~ /\b\w{8}(W2|C5|C7|WC|C8|4A|4C|2C|TS|ZG|ZE|ZF|ZH)\w{3}\b/) {

                    push (@ringTIDs, $tid);

                    next;

            }

            else {

                    die "Unable to determine Metro 1 VS 2";

            }

    }

#    print "in metro version loop @gneTIDs\n";

}

 

sub gettestips {

    #my ($metroversion) = @_;

    if ($metroversion == 1) {

        print "ENTER TEST TID IP ADDRESS\n";

        my $ip = <STDIN>;

        chomp $ip;

        return $ip;

    }

    elsif(($metroversion == 2 ) or ($metroversion == 3)) {

        print "ENTER TEST TID IP ADDRESS\n";

        my $ip = <STDIN>;

        print "ENTER TEST OSPF IP ADDRESS\n";

        my $oip = <STDIN>;

        print "ENTER TEST LOOPBACK IP ADDRESS\n";

        my $lip = <STDIN>;

        chomp( $ip, $oip, $lip );

        return ($ip, $oip, $lip);

    }

}

 

sub validateipaddress {

    my ($ip, $ver) = @_;

    my $ip_check;

    if ($ip =~ m/(\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b)/) {

     $ip_check = $1;

     print "IP Address : $ip_check is valid\n";

    }

     else {

     print "Invalid IP Address : $ip_check\n";

     exit;

     }

    

    my ($subnet, $addr);

    my @subsgatesandbroadcasts;

    my @ipaddress = split /\./, $ip;

   

    my $regexaddress = join '\.', @ipaddress;

   

    if($ver == 1) {

         @subsgatesandbroadcasts = ( 0, 1, 31, 32, 33, 63, 64, 65, 95, 96, 97, 127, 128, 129, 159, 160, 161, 191, 192, 193, 223, 224, 225, 255 );

    }

    if(($ver == 2) or ($ver == 3)) {

         @subsgatesandbroadcasts = ( 0, 1, 2, 3, 31, 32, 33, 34, 35, 63, 64, 65, 66, 67, 95, 96, 97, 98, 99, 127, 128, 129, 130, 131, 159, 160, 161, 162, 163, 191, 192, 193, 194, 195, 223, 224, 225, 226, 227, 255 );

    }

    if($ip =~ /\b(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d{1,3})\b/) {

        $subnet = $1;

        $addr = $2;

       

    }

    else { print "INVALID FORMAT FOUND FOR IP ADDRESS $ip\n\n"; exit; }

    foreach my $inval (@subsgatesandbroadcasts) {

        if($addr == $inval) {  print "NETWORK / BROADCAST OR GATEWAY ADDRESS ASSINGED FIX INCOGNITO.\n"; exit; }

        else { next; }

 

    }

   

    

    if($ver == 1) {

        my @duplicate = grep (/\b$regexaddress\b/, @fltfile);

        if(@duplicate) {

            print $banner;

            print "DUPLICATE IP ADDRESS FOUND IN SWITCHES FLAT FILE!\nCHECK INCOGNITO FOR CORRECT IP ASSINGMENTS...";

            print $banner;

            print "@duplicate\n";

            exit;

        }

    }

    elsif(($ver == 2) or ($ver == 3)) {

        my @duplicate = grep (/\b$regexaddress\b/, @asrfltfile);

        if(@duplicate) {

            print $banner;

            print "DUPLICATE IP ADDRESS FOUND IN ASR-SWITCHES FLAT FILE!\nCHECK INCOGNITO FOR CORRECT IP ASSINGMENTS...";

            print $banner;

            print "@duplicate\n";

            exit;

        }

    }

    foreach my $invalip ( @subsgatesandbroadcasts ) {

        if ($invalip == $addr) {

            print $banner;

            print "AN INVALID IP ADDRESS HAS BEEN ASSIGNED IN INCOGNITO...\nVERIFY ADDRESS IS NOT A SUBNET, BROADCAST, OR GATEWAY...\nCHECK INCOGNITO FOR CORRECT IP ASSINGMENTS...";

            print $banner;

        }

        else { next; }

 

    }

    if($ver == 1) {

        if(($addr >= 0) and ($addr <= 31)) { my $dftgw = $subnet . 1; return ($dftgw, $subnet, $addr); }

        if(($addr >= 32) and ($addr <= 63)) { my $dftgw = $subnet . "33"; return ($dftgw, $subnet, $addr); }

        if(($addr >= 64) and ($addr <= 95)) { my $dftgw = $subnet . "65"; return ($dftgw, $subnet, $addr); }

        if(($addr >= 96) and ($addr <= 127)) { my $dftgw = $subnet . "97"; return ($dftgw, $subnet, $addr); }

        if(($addr >= 128) and ($addr <= 159)) { my $dftgw = $subnet . "129"; return ($dftgw, $subnet, $addr); }

        if(($addr >= 160) and ($addr <= 191)) { my $dftgw = $subnet . "161"; return ($dftgw, $subnet, $addr); }

        if(($addr >= 192) and ($addr <= 223)) { my $dftgw = $subnet . "193"; return ($dftgw, $subnet, $addr); }

        if(($addr >= 224) and ($addr <= 254)) { my $dftgw = $subnet . "225"; return ($dftgw, $subnet, $addr); }

    }

    if(($ver == 2) or ($ver == 3)) {

        if(($addr >= 0) and ($addr <= 127)) { my $dftgw = $subnet . "1"; return ($dftgw, $subnet, $addr); }

        if(($addr >= 128) and ($addr <= 254)) { my $dftgw = $subnet . "129"; return ($dftgw, $subnet, $addr); }

    }

    

}   

 

sub getringinfo {

    $ringnumber = `$scriptsdirpath/getFNIcdi $tid`;

    print "Adding $tid TO RING $ringnumber\n";

    chomp ($ringnumber);

    @tidlist = `$scriptsdirpath/getTIDlist $ringnumber`;

    chomp (@tidlist);

 

    if ($ringnumber eq "") {

            die "Error getting ring info from RSI";

    }

}

 

sub insert_four {

  #  my ($tid,$ringnumber,$city,$ip_addr,$ospf_ip,$loop_ip,$gateway,$routetarget,$mstdomainname,$streetaddress) = (@ARGV);

#    print "It is working\n";

 

#    print "$tid\t$ringnumber\t$ip_addr\t$ospf_ip\t$loop_ip\t$gateway\t$routetarget\t$mstdomainname\t$streetaddress\n";

#    print "$tid\n";

#    print "$ringnumber\n";

#    print "$city\n";

#    print "$streetaddress\n";

 

   

    my $host = "suzuka.dnvr.twtelecom.net";

    my $duser = "reports";

    my $dpw   = "Eed6xah1ieS1";

 

    my $database = "oflcatdata";

    my $dsn      = "DBI:mysql:database=$database;host=$host";

    my $dbh = DBI->connect($dsn, $duser, $dpw)

                 or die "Can't connect to the DB: $DBI::errstr\n";

     my $insert_update = 'insert ignore into metro_two (TID, ring, city, mgmt_ip, ospf_ip, loopback_ip, default_gw, route_target, mst_domain, phy_addr) values (?,?,?,?,?,?,?,?,?,?)';

     my $rows = $dbh->do(qq~

                       update metro_two set ring = ?, city= ?, mgmt_ip= ?, ospf_ip= ?, loopback_ip= ?, default_gw= ?, route_target=

?, mst_domain= ?, phy_addr= ? where TID = ?

                      ~, undef, $ringnumber,$city,$ip_addr,$ospf_ip,$loop_ip,$gateway,$routetarget,$mstdomainname,$streetaddress, $tid)

;

     if ($rows == 0) {  $dbh->do($insert_update, undef, $tid,$ringnumber,$city,$ip_addr,$ospf_ip,$loop_ip,$gateway,$routetarget,$mstdomainname,$streetaddress); }

    }

 
