#!/usr/bin/perl
# Principally intended for converting between RCS and PlainFileStore, this
# script should also work with any other pair of filestore inmplementations.
use strict;
use warnings;

use Assert;

use Foswiki                         ();
use Foswiki::Users::BaseUserMapping ();
use Encode;

# Debug only
use Data::Dumper ();

sub bad_args {
    my $ess = shift;
    die "$ess\n" . <<USAGE;
Usage: $0 <opts>
<opts> may include:

Selecting Webs and Topics

-s <webs>    Hierarchical pathname of a web to convert. Conversion of a web
             automatically implies conversion of all its subwebs. You can
	         have as many -w options as you want. If there are no -w options
	         then all webs will be converted.
-w <webs>    Hierarchical pathname of a web to convert. Conversion of a web
             automatically implies conversion of all its subwebs. You can
	         have as many -w options as you want. If there are no -w options
	         then all webs will be converted.
-i <topic>   Name of a topic to convert. If there are no -i options, then
             all topics will be converted.
	         You can have as many -i options as you want.
-x <topic>   Specifies a topic name that will cause the script to transfer
             only the latest rev of that topic, ignoring the history. Only
	         attachments present in the latest rev of the topic will be
	         transferred. Simple topic name, does not support web specifiers.
	         You can have as many -x options as you want. NOTE: to avoid
	         excess working, you are recommended to =-x WebStatistics= (and
	         any other file that has many auto-generated versions that don't
             really need to be kept)

Miscellaneous

-q           Run quietly, without printing progress messages
-v           Validate. Check the consistency of two previously synchronised
             stores, without performing any transfers. Used for testing.
-create      Create the infrastructure that target stores need before 1st
             use or to destroy store and start afresh
             
USAGE
}

# Convert a byte string encoded in the {Site}{CharSet} to a byte string encoded in utf8
# Return 1 if a conversion happened, 0 otherwise
my $enc = Encode::find_encoding($Foswiki::cfg{Site}{CharSet});

# Designed to be passed into Meta::forEachSelectedValue
my $convert = sub {
    my $old = $_[0];

# Convert octets encoded using site charset to unicode codepoints. Note
# that we use Encode::FB_HTMLCREF this should be a nop as unicode can
# accomodate all characters.
    $old = $enc->decode( $old, Encode::FB_HTMLCREF );

# Convert the internal representation to utf-8 bytes.
# The utf8 flag is turned off on the resultant string.
    utf8::encode( $old );
    $_[1]->{changed} ||= ($old ne $_[0] ? 1 : 0);

    return $old;
};

my $session = new Foswiki();

# List of webs to transfer
my @webs;

# List of topic names for which we will ignore histories
my @ignore_history;

# List of the only topics to transfer
my @only_topics;

# Make a lot of noise?
my $verbose = 1;

# Validate only
my $validate = 0;

# Create store infrastructure - destroys existing store
my $create = 0;

while ( my $arg = shift @ARGV ) {
    elsif ( $arg eq '-w' ) {
        push( @webs, shift @ARGV );
    }
    elsif ( $arg eq '-create' ) {
        $create = 1;
    }
    elsif ( $arg eq '-i' ) {
        push( @only_topics, shift @ARGV );
    }
    elsif ( $arg eq '-x' ) {
        push( @ignore_history, shift @ARGV );
    }
    elsif ( $arg eq '-q' ) {
        $verbose = 0;
    }
    elsif ( $arg eq '-v' ) {
        $validate = 1;
    }
    elsif ( $arg =~ /^-/ ) {
        bad_args "Unrecognised option '$arg'";
    }
    else {
        bad_args "Extra argument '$arg'";
    }
}

my $weblist = scalar @webs ? join( '|', map { ( $_, "$_/.*" ) } @webs ) : '.*';
my $toplist    = scalar @only_topics    ? join( '|', @only_topics )    : '.*';
my $no_history = scalar @ignore_history ? join( '|', @ignore_history ) : '';

my $source_store = Foswiki::Store::newConfig(''); # default Config or Store
my $target_store = Foswiki::Store::newConfig('TargetConfig');
$target_store->create() if $create;

my $wit = $source_store->eachWeb('');
while ( $wit->hasNext() ) {
    my $web_name = $wit->next();
    next unless $web_name =~ /^($weblist)$/o;
    my $web_meta = new Foswiki::Meta( $session, $web_name );
    print "Scanning web $web_name\n" if $verbose;
    my $top_it = $source_store->eachTopic($web_meta);
    while ( $top_it->hasNext() ) {
        my $top_name = $top_it->next();
        next unless $top_name =~ /^($toplist)$/o;
        my $top_meta = new Foswiki::Meta( $session, $web_name, $top_name );

        my %att_tx = ();    # record of attachments transferred for this topic
        my @top_rev_list = $source_store->getRevisionHistory($top_meta)->all;
        print "NO REVS $web_name.$top_name\n" if scalar @top_rev_list == 0;
        if ( $top_name =~ /^$no_history$/ ) {

            # Don't save history, only do most recent rev
            @top_rev_list = ( shift @top_rev_list );
        }
        foreach my $topic_version ( reverse @top_rev_list ) {

            # transfer the topic
            $source_store->readTopic( $top_meta, $topic_version );

            #my $info = $top_meta->getRevisionInfo();
            my $info = $source_store->getVersionInfo($top_meta, $topic_version);
            print "user='$info->{user}'\n" if defined $info->{user};
            print "author='$info->{author}'\n" if defined $info->{author};

            if ($validate) {
                my $path = $top_meta->getPath() . ":$topic_version";

                # Ensure getVersionInfo and META:TOPICINFO are consistent
                my $source_topicinfo = ( $top_meta->find('TOPICINFO') )[0];
                my $source_info =
                  $source_store->getVersionInfo( $top_meta, $topic_version );
                $top_meta->unload();

                # Reread the meta from the target store
                $target_store->readTopic( $top_meta, $topic_version );
                my $target_topicinfo = ( $top_meta->find('TOPICINFO') )[0];
                my $target_info =
                  $target_store->getVersionInfo( $top_meta, $topic_version );

                print "... validate $top_name:$topic_version\n" if $verbose;
                validate_info( "$path(T)", $source_topicinfo,
                    $target_topicinfo );
                validate_info( $path, $source_info, $target_info );

                $top_meta->unload();
                $source_store->readTopic( $top_meta, $topic_version );
            }
            else {
\               my %conv = (changed => 0);
                $top_meta->text( $convert->( $top_meta->text, \%conv) );
                $top_meta->forEachSelectedValue(
                    undef, undef, $convert, \%conv
                );
                print "... copy $top_name:$topic_version  " .
                    "($top_meta->{_latestIsLoaded}) " .
                    ($conv{changed} ? '+utf8 changes' : '') . "\n"
                  if $verbose;
                
                $target_store->saveTopic(
                    $top_meta,
                    $info->{author},
                    {
                        forcenewrevision => 1,
                        forcedate        => $info->{date},
                        _version         => $topic_version,
                        _latest          => $top_meta->{_latestIsLoaded}
                    }
                );
            }

            # Transfer attachments. We use eachAttachment rather than
            # META:FILEATTACHMENT because it won't stumble over deleted
            # attachments. An attachment, and its history, can be
            # completely removed from some stores, leaving
            # META:FILEATTACHMENT still in older revs of the topic.
            my $att_it = $source_store->eachAttachment($top_meta);
            die $source_store unless defined $att_it;
            while ( $att_it->hasNext() ) {
                my $att_name = $att_it->next();
                my $att_info = $top_meta->get( 'FILEATTACHMENT', $att_name );

                # Is there info about this attachment in this rev of the
                # topic? If not, we can't do anything useful.
                next unless $att_info;
                my $att_version = $att_info->{version};
                my $att_user    = $att_info->{author};

                unless ( $att_user && $att_version ) {

                    # Something is missing from META:FILEATTACHMENT.
                    # Get missing info from the store. If $att_version
                    # is not set, we default to using the latest rev
                    # of the attachment. This could lead to an attachment
                    # having a revision date more recent than the topic
                    # revision it is attached to. Unfortunately the store
                    # does not support getRevisionAtTime for attachments.
                    print "#2 $top_meta->{_topic} no loadedRev\n" if !defined $top_meta->{_loadedRev};
                    my $info =
                      $source_store->getVersionInfo( $top_meta, $att_version,
                        $att_name );

                    $att_version ||= $info->{version};
                    $att_user ||= $info->{user}
                      || $Foswiki::Users::BaseUserMapping::UNKNOWN_USER_CUID;
                }

                # avoid copying the same rev twice
                next if $att_tx{"$att_name:$att_version"};
                $att_tx{"$att_name:$att_version"} = 1;

                my $stream =
                  $source_store->openAttachment( $top_meta, $att_name, '<',
                    version => $att_version );

                if ($validate) {
                    my $path = $top_meta->getPath() . ":$topic_version";
                    $path .= "/$att_name:$att_version";

                    # Ensure getVersionInfo are consistent
                    my $source_info =
                      $source_store->getVersionInfo( $top_meta, $att_version,
                        $att_name );

                   # The META:FILEATTACHMENT carries date and author fields.
                   # However these can drift from the history due
                   # to changes to attachments not reflected in the topic
                   # meta-data. So the only source we trust is
                   # getVersionInfo().
                   #validate_info("Source META $path", $att_info, $source_info);

                    # Reread the meta from the target store
                    my $target_info =
                      $target_store->getVersionInfo( $top_meta, $att_version,
                        $att_name );
                    validate_info( $path, $source_info, $target_info );

                }
                else {
                    # Save attachment
                    print "... copy attachment $att_name rev $att_version"
                      . " as $att_user\n"
                      if $verbose;

                    # SMELL: there's no way to force the date of the
                    # copied attachment
                    # 12 Apr 2013: Not true extra parm now see latest spec
                    $target_store->saveAttachment( $top_meta, $att_name,
                        $stream, $att_user );
                }
            }
        }
    }
}

1;
