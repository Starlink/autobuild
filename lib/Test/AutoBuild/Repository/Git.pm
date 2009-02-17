# -*- perl -*-
#
# Test::AutoBuild::Repository::Git by Daniel Berrange
#
# Copyright (C) 2004-2007 Daniel Berrange
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# $Id: Git.pm,v 1.1 2007/12/10 02:23:35 danpb Exp $

=pod

=head1 NAME

Test::AutoBuild::Repository::Git - A repository for Git

=head1 SYNOPSIS

  use Test::AutoBuild::Repository::Git


=head1 DESCRIPTION

This module provides a repository implementation for the
Git revision control system. It requires that the
'git' command version 1.5 or higher be installed. It has
full support for detecting updates to an existing checkout.

=head1 METHODS

=over 4

=cut

package Test::AutoBuild::Repository::Git;

use base qw(Test::AutoBuild::Repository);
use warnings;
use strict;
use Log::Log4perl;

use Test::AutoBuild::Change;
use Date::Manip;

=item my $repository = Test::AutoBuild::Repository::Git->new(  );

=cut

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self = $class->SUPER::new(@_);

    bless $self, $class;

    return $self;
}


sub export {
    my $self = shift;
    my $runtime = shift;
    my $src = shift;
    my $dst = shift;
    my $logfile = shift;
    my $log = Log::Log4perl->get_logger();

    my $branch = "master";
    if ($src =~ /^\s*(.*?):(.*?)\s*$/) {
	$src = $1;
	$branch = $2;
    }

    my $changed = 0;
    my $current = undef;
    # Don't support using multiple paths yet
    if (-d $dst) {
	$current = $self->_get_current($dst, $logfile);
	$log->debug("Current changeset in $dst is $current");
	$self->_pull_repository($src, $dst, $logfile);
    } else {
	$self->_clone_repository($src, $dst, $logfile);
	$changed = 1;
    }

    my $target = $self->_get_target($runtime, $dst, $branch, $logfile);
    $log->debug("Target changeset is $target");

    my $changes = {};
    if (defined $current) {
	$changes = $self->_get_changes($dst, $current, $target, $logfile);
	if (keys %{$changes}) {
	    $changed = 1;
	}
    }

    $self->_sync_checkout($dst, $target, $logfile);

    return ($changed, $changes);
}

sub _clone_repository {
    my $self = shift;
    my $path = shift;
    my $dest = shift;
    my $logfile = shift;
    my $log = Log::Log4perl->get_logger();

    my $base_url = $self->option("base-url");
    die "base-url option is required" unless $base_url;
    $base_url =~ s,\/$,,;
    $path =~ s,^/,,;
    my $url = "$base_url/$path";

    $log->info("Cloning repository at $url");
    my ($result, $errors) = $self->_run(["git", "clone", "--no-checkout", $url, $dest], undef, $logfile);
}

sub _sync_checkout {
    my $self = shift;
    my $dest = shift;
    my $changeset = shift;
    my $logfile = shift;
    my $log = Log::Log4perl->get_logger();

    $log->info("Checking out changeset $changeset");
    my ($result, $errors) = $self->_run(["git", "checkout", "-f", $changeset], $dest, $logfile);
}

sub _pull_repository {
    my $self = shift;
    my $path = shift;
    my $dest = shift;
    my $logfile = shift;
    my $log = Log::Log4perl->get_logger();

    my $base_url = $self->option("base-url");
    die "base-url option is required" unless $base_url;
    $base_url =~ s,\/$,,;
    $path =~ s,^/,,;
    my $url = "$base_url/$path";

    $log->info("Pulling from repository at $url");
    my ($result, $errors) = $self->_run(["git", "pull", "$url"], $dest, $logfile);
}

sub _get_current {
    my $self = shift;
    my $path = shift;
    my $logfile = shift;

    my $log = Log::Log4perl->get_logger();
    my ($output, $errors) = $self->_run(["git", "log", "-n", "1", "--pretty=format:%H", "HEAD"], $path, $logfile);

    my @lines = split /\n/, $output;
    foreach (@lines) {
	if (/^\s*([a-f0-9]+)\s*$/i) {
	    return $1;
	}
    }
    die "cannot extract current changelist from git log -n 1 --pretty=format:%H HEAD";
}

sub _get_target {
    my $self = shift;
    my $runtime = shift;
    my $path = shift;
    my $branch = shift;

    my $logfile = shift;

    my $log = Log::Log4perl->get_logger();
    my $before = "--before=\@" . $runtime->timestamp;
    my ($output, $errors) = $self->_run(["git", "log", "-n", "1", $before, "--pretty=format:%H", "origin/$branch"], $path, $logfile);

    my @lines = split /\n/, $output;
    foreach (@lines) {
	if (/^\s*([a-f0-9]+)\s*$/i) {
	    return $1;
	}
    }
    die "cannot extract target changelist from git log -n 1 $before --pretty=format:%H origin/$branch";
}

sub _get_changes {
    my $self = shift;
    my $path = shift;
    my $current = shift;
    my $target = shift;
    my $logfile = shift;

    my $log = Log::Log4perl->get_logger();

    my $range = "$current..$target";
    my $format = "--pretty=format:changeset:%H %h%ndate:%at%nuser:%an <%ae>%ndescription:%s%n%b%nfiles:";
    my ($data, $errors) = $self->_run(["git", "log", "--stat", $format, $range], $path, $logfile);
    my @lines = split /\n/, $data;

    my %logs;
    my $number;
    my $hash;
    foreach my $line (@lines) {
	next if $line =~ /^\s*$/;
	#$log->debug("[$line]");
	if ($line =~ m,^changeset:\s*([a-f0-9]+)\s([a-f0-9]+)\s*$,i) {
	    $hash = $1;
	    $number = $2;
	    $log->debug("Version changeset hash " . $hash);
	    $logs{$hash} = { number => $number };
	} elsif (defined $hash) {
	    if ($line =~ m,^user:\s*(.*?)\s*$,) {
		$logs{$hash}->{user} = $1;
		#$log->debug("User " . $logs{$hash}->{user});
	    } elsif ($line =~ m,^date:\s*(.*?)\s*$,) {
		$logs{$hash}->{date} = $1;
		$log->debug("Date " . $logs{$hash}->{date});
	    } elsif ($line =~ m,^files:\s*$,) {
		$logs{$hash}->{files} = [];
		#$log->debug("Files " . $logs{$hash}->{files});
	    } elsif ($line =~ m,^description:\s*(.*?)\s*$,) {
		$logs{$hash}->{description} = $1;
		#$log->debug("Description started ");
	    } elsif (defined $logs{$hash}->{files}) {
		if ($line =~ m,\s*(.*?)\s*\|\s*\d+\s*\+*\-*\s*$,) {
		    push @{$logs{$hash}->{files}}, $1;
		} else {
		    # ignore
		}
	    } elsif (defined $logs{$hash}->{description}) {
		$line =~ s/(^\s*)|(\s*$)//g;
		if ($logs{$hash}->{description} eq "") {
		    $logs{$hash}->{description} .= $line;
		} else {
		    $logs{$hash}->{description} .= "\n" . $line;
		}
		#$log->debug("Append Desc " . $line);
	    } else {
		$log->warn("Got unexpected changelist tag " . $line);
	    }
	} else {
	    $log->warn("Got content outside changelist " . $line);
	}
    }

    my %changes;
    foreach (keys %logs) {
	$changes{$logs{$_}->{number}} = Test::AutoBuild::Change->new(number => $logs{$_}->{number},
						    date => $logs{$_}->{date},
						    user => $logs{$_}->{user},
						    description => $logs{$_}->{description},
						    files => $logs{$_}->{files});
    }
    return \%changes;
}

1 # So that the require or use succeeds.

__END__

=back

=head1 AUTHORS

Daniel Berrange

=head1 COPYRIGHT

Copyright (C) 2004-2007 Daniel Berrange

=head1 SEE ALSO

C<perl(1)>, L<Test::AutoBuild::Repository>

=cut
