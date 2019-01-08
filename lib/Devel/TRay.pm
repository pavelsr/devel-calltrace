=head1 NAME

Devel::TRay - See what your code's doing

=head1 SYNOPSIS

    #!/usr/bin/perl -d:TRay

or

    perl -d:TRay script.pl
    

=head1 DESCRIPTION

Fork of L<Devel::CallTrace> with following additions

    Filter output as easy as L<Devel::KYTProf>
    
    Ability to not show cpan and CORE module calls

=cut

package Devel::TRay;
use warnings;
use strict;
no strict 'refs';

use vars qw($SUBS_MATCHING);
our $VERSION = '1.0';

$SUBS_MATCHING = qr/.*/;

sub import {
    my ( $self, $re ) = @_;

    if ($re) {
        $Devel::TRay::SUBS_MATCHING = qr/$re/;
    }
}

package DB;
sub DB{};
our $CALL_DEPTH = 0;

sub sub {
    local $DB::CALL_DEPTH = $DB::CALL_DEPTH+1;
    Devel::TRay::called($DB::CALL_DEPTH, \@_) 
        if ($DB::sub =~ $Devel::TRay::SUBS_MATCHING);
    &{$DB::sub};
}


sub Devel::TRay::called {
    my ( $depth, $routine_params ) = @_;
    if ( $DB::sub !~ /CODE/ ) {
        print STDERR " " x $depth . $DB::sub;
        if (exists $DB::sub{$DB::sub}) {
            print STDERR " ($DB::sub{$DB::sub})";  # print file and string number
        }
        print STDERR "\n";
    }
}

1;
