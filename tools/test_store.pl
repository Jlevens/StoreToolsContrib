#!/usr/bin/perl
# Principally intended for converting between RCS and PlainFileStore, this
# script should also work with any other pair of filestore inmplementations.
use strict;
use warnings;

use Assert;

use Foswiki                         ();
use Foswiki::Store;
use Foswiki::Users::BaseUserMapping ();
use Time::HiRes qw(gettimeofday tv_interval);


# Debug only
use Data::Dumper ();

sub bad_args {
    my $ess = shift;
    die "$ess\n" . <<USAGE;
Usage: $0 <opts>
Selecting Webs and Topics

-w <webs>    Hierarchical pathname of a web to test.
USAGE
}

# See how a real topic (WorkFlow.txt hence WF) is returned. Topic created as a text file directly to force unusual situations
sub _restWF {
    my ($session) = @_;
    
    my $query = $session->{request};
    my $w = $query->{param}->{w}[0] || 'Main';
    my $t = $query->{param}->{t}[0] || 'WorkFlow3.txt';

    my $text = '';
   
    my $oText = Foswiki::Func::readFile("$Foswiki::cfg{DataDir}/$w/$t.txt");
    my $rText = Foswiki::Func::readTopicText($w, $t);
    my ($meta, $topicText) = Foswiki::Func::readTopic( $w, $t );

    $text .= "\n\n== $t" . "=" x 120 . "\n";
    $text .= $oText;
    $text .= "--------------------------------------------\n";
    $meta->{_text} = "*Text was 'ere*";
    $text .= $meta->getEmbeddedStoreForm();
    $text .= "--------------------------------------------\n";
    $text .= $topicText;
    $text .= "--------------------------------------------\n";
    $text .= "--------------------------------------------\n";
    $text .= $rText;
    $text .= "\n--------------------------------------------\n";
    my $column;
    my @types = keys %$meta;
    TYPE:
    for my $type (@types) {
        if($type =~ /_.*?/) {
            next;
            $text .= "$type = '";
            $text .= $meta->{$type} . "'\n";
            next;
        }
        my @items = $meta->find($type);
        if(scalar (@items) == 0) {
            $text .= "$type has no entries\n";
            next;
        }
        
        my $q = 0;
        for my $i (@items) {
            my @keys = keys %$i;
            $text .= '%META:' . "$type\[$q]{";
            $q += 1;
            my $ktext = '';
            for my $k (sort @keys) {
                if($k eq 'name') {
                    $text .= "$k='$i->{$k}' ";
                }
                else {
                    $ktext .= "$k='$i->{$k}' ";
                }
            }
            $text .= "$ktext}\n";
        }
    }
    $text .= "\n\n";
   
    return $text;
}

sub _restTEST {
    my ($session) = @_;
    my $query = $session->{request};
    my $w = $query->{param}->{w}[0] || 'System';
   
    my $versatile = Foswiki::Store::Versatile->new();

    my $webObject = Foswiki::Meta->new($session, $w);
    my @topics = $versatile->eachTopic($webObject)->all;
    my $tRead = [ gettimeofday ];
    my @metaList;
    for my $t (@topics) {
        my $meta = Foswiki::Meta->new($session, $w, $t);
        $versatile->readTopic($meta, 0);
        push @metaList, $meta;
    }
    my $topics = scalar @topics;
    my $iRead = tv_interval( $tRead, [ gettimeofday ]);
    
    print "Initial read took $iRead s for $topics topics\n";

    for my $q (1..5) {
        $tRead = [ gettimeofday ];
        for my $meta (@metaList) {
            $versatile->readTopic($meta, 0);
        }
        $topics = scalar @metaList;
        $iRead = tv_interval( $tRead, [ gettimeofday ]);
        print "Next read took $iRead s for $topics topics\n";
    }
    

    for my $q (1..5) {
        $tRead = [ gettimeofday ];
        $versatile->readTopicsEnMasse(\@metaList);
        $topics = scalar @metaList;
        $iRead = tv_interval( $tRead, [ gettimeofday ]);
        print "Next read took $iRead s for $topics topics\n";
    }
    



#    return;

    my $rmeta;
    my $t5 = [ gettimeofday ];
    for my $c (1..100)  {
        for my $fobid (3..32) {
            my $ti = $versatile->{FOBinfo}{$fobid};
            next if !$ti;
            $rmeta = Foswiki::Meta->new($session, $ti->{webName}, $ti->{topicName});
            my ($lastest, $rRev) = $versatile->readTopic($rmeta, 0); 
        }
    }
    my $int5 = tv_interval( $t5, [ gettimeofday ] );
    print "Read 3000 topics in $int5 s\n";
    print "" . (3000 / $int5) . " topics per second\n";
    print "\n";
    #print "Total upload time $iupload s\n";
    #print "Versa save   time $vtime s\n\n";
    print "\n";
    #print "Total topics   uploaded $topic_count\n";
    #print "Total versions uploaded $version_count\n";
    #print "" . ($version_count / $topic_count) . 
    #      " average versions per topic\n";
    
    for my $webNo (7..9) {
        my $meta = Foswiki::Meta->new($session,
            "Web$webNo",
            $Foswiki::cfg{WebPrefsTopicName}
        );
        $versatile->saveTopic($meta, 'levensj', 
            {
                _version => 1, _latest => 1
            }
        );
        for my $subweb ('h'..'j') {
            my $meta = Foswiki::Meta->new($session,
                "Web$webNo/Sub$subweb",
                $Foswiki::cfg{WebPrefsTopicName}
            );
            $versatile->saveTopic($meta, 'levensj', 
                {
                    _version => 1, _latest => 1
                }
            );
            for my $subsub (4..6) {
                my $meta = Foswiki::Meta->new($session,
                    "Web$webNo/Sub$subweb/Part$subsub",
                    $Foswiki::cfg{WebPrefsTopicName}
                );
                $versatile->saveTopic($meta, 'levensj', 
                    {
                        _version => 1, _latest => 1
                    }
                );
            }
        }
    }

    $rmeta = Foswiki::Meta->new($session);

    print "===Top Level only=============================\n";
    for my $c (1..1) {
        my $witer = $versatile->eachWeb(undef);
        while($witer->hasNext()) {
            my $web = $witer->next();
            print "WEB = '$web'\n";
        }    
        print "===Top Level All=============================\n";
        $witer = $versatile->eachWeb(undef, 1);
        while($witer->hasNext()) {
            my $web = $witer->next();
            print "WEB = '$web'\n";
        }    
        print "===Web9 Subs Only============================\n";
        $rmeta = Foswiki::Meta->new($session,"Web9");
        $witer = $versatile->eachWeb($rmeta);
        while($witer->hasNext()) {
            my $web = $witer->next();
            print "WEB = '$web'\n";
        }    
        print "===Web9 All==================================\n";
        $rmeta = Foswiki::Meta->new($session,"Web9");
        $witer = $versatile->eachWeb($rmeta,1);
        while($witer->hasNext()) {
            my $web = $witer->next();
            print "WEB = '$web'\n";
        }    
        print "===Web9 Subj Only============================\n";
        $rmeta = Foswiki::Meta->new($session,"Web9/Subj");
        $witer = $versatile->eachWeb($rmeta);
        while($witer->hasNext()) {
            my $web = $witer->next();
            print "WEB = '$web'\n";
        }    
        print "===Web9 Subj All=============================\n";
        $rmeta = Foswiki::Meta->new($session,"Web9/Subj");
        $witer = $versatile->eachWeb($rmeta,1);
        while($witer->hasNext()) {
            my $web = $witer->next();
            print "WEB = '$web'\n";
        }    
    }
    my $tMeta = Foswiki::Meta->new($session, 'Main', 'AdminGroup');
    my $ti = $versatile->_topicInfo($tMeta->web, $tMeta->topic, 0);
    $ti->{reprev} = '' if !$ti->{reprev};
    my @TI = %{$ti};
    print "@TI\n";
    
    $versatile->readTopic($tMeta, 0);
    print "" . stringMeta($tMeta) . "\n";
    
    my $mainWeb = Foswiki::Meta->new($session, 'System');
    my $tWeb = [gettimeofday];
    my $tIter = $versatile->eachTopic($mainWeb);
    my $iWeb = tv_interval($tWeb, [gettimeofday]);
    my $cWeb = 0;
    while($tIter->hasNext()) {
        my $t = $tIter->next();
        $cWeb++;
        print "System.$t\n";
    }
    print "eachTopic took $iWeb s over $cWeb topics\n";

    $tWeb = [gettimeofday];
    $tIter = $versatile->eachTopic($mainWeb);
    $iWeb = tv_interval($tWeb, [gettimeofday]);
    $cWeb = 0;
    while($tIter->hasNext()) {
        my $t = $tIter->next();
        $cWeb++;
    }
    print "eachTopic took $iWeb s over $cWeb topics\n";
}

sub stringMeta {
    my ($rmeta) = @_;
    my $text = '';
   
    $text .= "--------------------------------------------\n";
    $text .= $rmeta->{_text} if $rmeta->{_text};
    $text .= "\n--------------------------------------------\n";
    my $column;
    my @types = keys %$rmeta;
    TYPE:
    for my $type (@types) {
        next if ref($rmeta->{$type}) ne 'ARRAY';

        my @items = $rmeta->find($type);
        if(scalar (@items) == 0) {
            $text .= "$type has no entries\n";
            next;
        }

        my $q = 0;
        for my $i (@items) {
            my @keys = keys %$i;
            $text .= '%META:' . "$type\[$q]{";
            $q += 1;
            my $ktext = '';
            for my $k (sort @keys) {
                if($k eq 'name') {
                    $text .= "$k='$i->{$k}' ";
                }
                else {
                    $ktext .= "$k='$i->{$k}' ";
                }
            }
            $text .= "$ktext}\n";
        }
    }
    $text .= "\n--EOF------------------------------------------\n";
    return "$text\n";
}   

my $session = new Foswiki();

# List of webs to transfer
my @webs;

while ( my $arg = shift @ARGV ) {
    if ( $arg eq '-w' ) {
        push( @webs, shift @ARGV );
    }
    elsif ( $arg =~ /^-/ ) {
        bad_args "Unrecognised option '$arg'";
    }
}

my $weblist = scalar @webs ? join( '|', map { ( $_, "$_/.*" ) } @webs ) : '.*';

sub testStoreRead {
    my ($session, $storeName, $store, $w) = @_;

    print "Testing $storeName\n=========================\n";
    my $webObject = Foswiki::Meta->new($session, $w);
    
    my $tEach = [ gettimeofday ];
    my @topics = $store->eachTopic($webObject)->all;
    my $topics = scalar @topics;
    my $iEach = tv_interval( $tEach, [ gettimeofday ]);
    print "Initial eachTopic took $iEach s for $topics topics\n";
    #for my $t (@topics) {
    #    print "$t\n";
    #}
    #print "\n@topics\n\n";
    
    $tEach = [ gettimeofday ];
    @topics = $store->eachTopic($webObject)->all;
    $iEach = tv_interval( $tEach, [ gettimeofday ]);
    print "Second eachTopic took $iEach s for $topics topics\n";

    my $tRead = [ gettimeofday ];
    my @metaList;
    for my $t (@topics) {
        my $meta = Foswiki::Meta->new($session, $w, $t);
        $store->readTopic($meta, 0);
        push @metaList, $meta;
        #print "$t\n";
        #print "-----------------------\n$meta->{_text}\n-------------\n";
    }
    my $iRead = tv_interval( $tRead, [ gettimeofday ]);
    
    print "Initial read took $iRead s for $topics topics\n";

    $tRead = [ gettimeofday ];
    for my $t (@topics) {
        my $meta = Foswiki::Meta->new($session, $w, $t);
        $store->readTopic($meta, 0);
    }
    $iRead = tv_interval( $tRead, [ gettimeofday ]);
    
    print "Second read took $iRead s for $topics topics\n";
    
    for my $q (1..5) {
        $tRead = [ gettimeofday ];
        for my $meta (@metaList) {
            $store->readTopic($meta, 0);
        }
        $topics = scalar @metaList;
        $iRead = tv_interval( $tRead, [ gettimeofday ]);
        print "Next read took $iRead s for $topics topics\n";
    }
}

sub testStoreReadEnMasse {
    my ($session, $storeName, $store, $w) = @_;
    return if !$store->can('readTopicsEnMasse');

    print "Testing $storeName + enMasse \n=========================\n";

    my $webObject = Foswiki::Meta->new($session, $w);
    my @topics = $store->eachTopic($webObject)->all;
    my $topics = scalar @topics;
    
    my $tRead = [ gettimeofday ];
    my @metaList;
    for my $t (@topics) {
        my $meta = Foswiki::Meta->new($session, $w, $t);
        push @metaList, $meta;
    }
    my $iRead = tv_interval( $tRead, [ gettimeofday ]);
    
    print "Build metaList took $iRead s for $topics topics\n";
    
    for my $q (1..5) {
        $tRead = [ gettimeofday ];
        $store->readTopicsEnMasse(\@metaList);
        $iRead = tv_interval( $tRead, [ gettimeofday ]);
        print "Read enMasse took $iRead s for $topics topics\n";
    }
}

testStoreRead($session, 'RcsLite', $session->{store}, $webs[0]);
