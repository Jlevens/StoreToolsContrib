#!/usr/bin/perl
# Principally intended for converting between RCS and PlainFileStore, this
# script should also work with any other pair of filestore inmplementations.

use strict;
use warnings;

package storeActions::showConfig;
use storeActions::Base;
our @ISA = qw(storeActions::Base);

sub run {
    my ($this) = $_[0]->SUPER::run(@_);
    use Data::Dumper;
    $Data::Dumper::Sortkeys = 1;
    print Data::Dumper->Dump( [\$this->{store}->{cfg}], [$this->{store}->{cfg}->{_name}] );
}

1;
