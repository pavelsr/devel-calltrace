=head1 NAME

Devel::TRay - See what your code's doing

=head1 SYNOPSIS

    #!/usr/bin/perl -d:TRay

or

    perl -d:TRay script.pl
    
=head1 FILTERS

    -d:TRay=subs_matching=X:no_core=1

import options are separated with ':' symbol

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
our $calls = [];
our $ARGS;
our $SUBS_MATCHING = qr/.*/;

sub _get_args {
    my ( $arg_str ) = @_;
    return if !$arg_str;
    my $res;
    my @x = split( ':', $arg_str);
    for my $i (@x) {
        my @y = split( '=', $i );
        $res->{ $y[0] } = $y[1]; 
    }
    return $res;
}

sub import {
    my ( $self, $import_tags ) = @_;
    $ARGS = _get_args($import_tags);
    
    my $re = $ARGS->{subs_matching} if $ARGS;

    if ($re) {
        $Devel::TRay::SUBS_MATCHING = qr/$re/;
    }
}

package DB;
use Data::Dumper;
use List::Util qw(uniq);
use MetaCPAN::Client;
use Module::CoreList;
sub DB{};
our $CALL_DEPTH = 0;
our $traced_modules = [];
my $indent = " ";
my $mcpan = MetaCPAN::Client->new( version => 'v1' );

sub sub {
    local $DB::CALL_DEPTH = $DB::CALL_DEPTH+1;
    Devel::TRay::called($DB::CALL_DEPTH, \@_) 
        if ($DB::sub =~ $Devel::TRay::SUBS_MATCHING);
    &{$DB::sub};
}


sub Devel::TRay::called {
    my ( $depth, $routine_params ) = @_;
    my $frame = { 'sub' => "$DB::sub", 'package' => $DB::package, 'depth' => $depth };
    if (exists $DB::sub{$DB::sub}) {
        $frame->{'line'} = $DB::sub{$DB::sub};
    }
    push @$calls, $frame;
}

# return Data::Dumper from Data::Dumper::Dumper()
sub _extract_module_name {
    my ($sub) = @_;
    my @x = split( '::', $sub );
    return $x[0] if ( scalar @x == 1 );
    pop @x;
    return join( '::', @x );
}

sub _get_enabled_module_filters {
    return [ grep { $_ =~ 'hide_' && $Devel::TRay::ARGS->{$_} } sort keys %{$Devel::TRay::ARGS} ];
}

sub _is_cpan_published {
    my ($pkg) = @_;
    return 0 if !defined $pkg;
    
    my $expected_distro = $pkg;
    $expected_distro =~ s/::/-/;
    
    eval {
        my $distro = $mcpan->distribution($expected_distro)->name;
        return 1;
    } or do {
        eval {
            my $distro = $mcpan->module($pkg)->distribution;    
            return 1 if ( $expected_distro =~ qr/$distro/ );
        } or do {
            return 0;
        }
    }
}

sub _is_core {
    my ($pkg) = @_;
    return 0 if !defined $pkg;
    return Module::CoreList::is_core(@_);
}

sub _is_eval {
    my ($pkg) = @_;
    return 0 if !defined $pkg;
    return 1 if ( $pkg eq '(eval)' );
    return 0;
}

sub _check_filter {
    my ($option, $pkg) = @_;
    # dispatch table
    # all functions must return true when value need to be removed
    my %actions = (
        'hide_cpan' => \&_is_cpan_published,
        'hide_core' => \&_is_core,
        'hide_eval' => \&_is_eval
    );
    return $actions{$option}->($pkg);
}

# return 1 if module calls must be leaved in stacktrace
sub _leave_in_trace {
    my ( $module, $filters ) = @_;
    
    $filters = _get_enabled_module_filters() if !defined $filters;
    for my $f (@$filters) {
        return 0 if ( _check_filter( $f, $module ) );
    }
    return 1;
}

sub _filter_calls {
    my ( $calls ) = @_;
	
	@$calls = grep { $_->{'sub'} !~ /CODE/ } @$calls;
	
	my $subs = [ map { $_->{'sub'} } @$calls ];
	my $traced_modules = [ uniq map { _extract_module_name($_) } @$subs ];

	@$traced_modules = grep { $_ ne 'Devel::TRay' } @$traced_modules;
    @$traced_modules = grep { _leave_in_trace($_) } @$traced_modules;
    my %modules_left = map { $_ => 1 } @$traced_modules;
    @$calls = grep { $modules_left{_extract_module_name($_->{'sub'})} } @$calls;
    
    return $traced_modules;
}

sub _print {
    my ( $frame ) = @_;
    my $str = $indent x $frame->{'depth'} . $frame->{'sub'};
    $str.= " (".$frame->{'line'}.")" if $frame->{'line'};
    print STDERR "$str\n";
}

END {
    # warn Dumper $calls;
	
	$DB::traced_modules = _filter_calls($calls);
	
	# _filter_calls($calls, $traced_modules);
	
    # _filter_calls($calls);
	# warn Dumper $calls;
    # _print($_) for @$calls;
    warn "Traced modules: ".Dumper $DB::traced_modules;
}

1;
