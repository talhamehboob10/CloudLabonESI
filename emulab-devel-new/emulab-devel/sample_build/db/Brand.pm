#!/usr/bin/perl -wT
#
# Copyright (c) 2005-2020 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#
package Brand;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw ( );

use English;
use libtestbed;

# Configure variables
my $TB         = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build";
my $TBOPS      = "testbed-ops\@ops.cloudlab.umass.edu";
my $TBLOGS      = "testbed-logs\@ops.cloudlab.umass.edu";
my $TBAPPROVAL  = "testbed-approval\@ops.cloudlab.umass.edu";
my $TBAUDIT	= "testbed-audit\@ops.cloudlab.umass.edu";
my $TBBASE      = "https://www.cloudlab.umass.edu";
my $TBWWW       = "<https://www.cloudlab.umass.edu/>";
my $MAINSITE    = 0;

#
# Return an object representing a "brand" ... yes, its silly.
#
sub Create($$)
{
    my ($class, $brand) = @_;

    # No brand means the classic interface.
    if (!defined($brand)) {
	$brand = "classic";
    }
    elsif ($brand =~ /aptlab/) {
	$brand = "aptlab";
    }
    elsif ($brand =~ /cloudlab/) {
	$brand = "cloudlab";
    }
    elsif ($brand =~ /phantomnet/) {
	$brand = "phantomnet";
    }

    elsif ($brand =~ /powder/) {
	$brand = "powder";
    }
    else {
	# This means the new Portal interface.
	$brand = "emulab";
    }
    my $self           = {};
    $self->{'BRAND'}   = $brand;

    bless($self, $class);
    return $self;
}
sub brand($)		{ return $_[0]->{'BRAND'}; }
sub isAPT($)	        { return $_[0]->brand() eq "aptlab" ? 1 : 0; }
sub isCloud($)	        { return $_[0]->brand() eq "cloudlab" ? 1 : 0; }
sub isPNet($)           { return $_[0]->brand() eq "phantomnet" ? 1 : 0; }
sub isPowder($)         { return $_[0]->brand() eq "powder" ? 1 : 0; }
sub isEmulab($)         { return $_[0]->brand() eq "emulab" ? 1 : 0; }
sub isClassic($)        { return $_[0]->brand() eq "classic" ? 1 : 0; }

#
# Lookup the brand by domain. See utils/tbsendmail.in
#
sub LookupByDomain($$)
{
    my ($class, $domain) = @_;

    if (!$MAINSITE) {
	return Create($class, "emulab");
    }
    return Create($class, $domain);
}

#
# This is used for sendmail.
#
sub EnvelopeSender($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "aptlab.net" :
	    # There is no boss.cloudlab.us.
	    $self->isCloud() ? "www.cloudlab.us" :
	    $self->isPNet() ? "boss.phantomnet.org" :
	    $self->isPowder() ? "boss.powderwireless.net" :
	    "boss.cloudlab.umass.edu");
}

sub Server($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "www.aptlab.net" :
	    $self->isCloud() ? "www.cloudlab.us" :
	    $self->isPNet() ? "www.phantomnet.org" :
	    $self->isPowder() ? "www.powderwireless.net" :
	    $self->isEmulab() ?	"www.cloudlab.umass.edu" : "www.cloudlab.umass.edu");
}

sub wwwBase($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "https://www.aptlab.net" :
	    $self->isCloud() ? "https://www.cloudlab.us" :
	    $self->isPNet() ? "https://www.phantomnet.org" :
	    $self->isPowder() ? "https://www.powderwireless.net" :
	    $self->isEmulab() ?	"https://www.cloudlab.umass.edu" . "/portal" :
	    "https://www.cloudlab.umass.edu");
}

sub ApprovalEmailAddress($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "aptlab-approval\@aptlab.net" :
	    $self->isCloud() ? "cloudlab-approval\@cloudlab.us" :
	    $self->isPNet() ? "phantomnet-approval\@phantomnet.org" :
	    $self->isPowder() ? "powder-approval\@powderwireless.net" :
	    "testbed-approval\@ops.cloudlab.umass.edu");
}

sub OpsEmailAddress($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "portal-ops\@aptlab.net" :
	    $self->isCloud() ? "portal-ops\@cloudlab.us" :
	    $self->isPNet() ? "portal-ops\@phantomnet.org" :
	    $self->isPowder() ? "portal-ops\@powderwireless.net" :
	    $TBOPS);
}

sub LogsEmailAddress($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "apt-logs\@aptlab.net" :
	    $self->isCloud() ? "cloudlab-logs\@cloudlab.us" :
	    $self->isPNet() ? "phantomnet-logs\@phantomnet.org" :
	    $self->isPowder() ? "powder-portal-logs\@powderwireless.net" :
	    $TBLOGS);
}

sub ExtensionsEmailAddress($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "portal-extensions\@aptlab.net" :
	    $self->isCloud() ? "portal-extensions\@cloudlab.us" :
	    $self->isPNet() ? "portal-extensions\@phantomnet.org" :
	    $self->isPowder() ? "portal-extensions\@powderwireless.net" :
	    $TBOPS);
}

sub ReservationsEmailAddress($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "portal-reservations\@aptlab.net" :
	    $self->isCloud() ? "portal-reservations\@cloudlab.us" :
	    $self->isPNet() ? "portal-reservations\@phantomnet.org" :
	    $self->isPowder() ? "portal-reservations\@powderwireless.net" :
	    $TBOPS);
}

sub EmailTag($)
{
    my ($self) = @_;

    return ($self->isAPT() ? "aptlab.net" :
	    $self->isCloud() ? "cloudlab.us" :
	    $self->isPNet() ? "phantomnet.org" :
	    $self->isPowder() ? "powderwireless.net" :
	    "UMASS");
}

sub SignupURL($$)
{
    my ($self, $project)  = @_;
    my $wwwbase = $self->wwwBase();
    my $pid     = $project->pid();

    return ($self->isAPT() || $self->isCloud() ||
	    $self->isPNet() || $self->isPowder() || $self->isEmulab() ? 
	    "${wwwbase}/signup.php?pid=$pid" :
	    "${wwwbase}/joinproject.php3?target_pid=$pid");
}

sub UsersGroupName($)
{
    my ($self)  = @_;

    return ($self->isAPT() ? "apt-users\@googlegroups.com" :
	    $self->isCloud() ? "cloudlab-users\@googlegroups.com" :
	    $self->isPNet() ? "phantomnet-users\@googlegroups.com" :
	    $self->isPowder() ? "powder-users\@googlegroups.com" :
	    "emulab-users\@googlegroups.com");
}

sub UsersGroupURL($)
{
    my ($self)  = @_;
    my $url = 'https://groups.google.com/forum/#!forum';

    return ($self->isAPT() ? "$url/apt-users" : 
	    $self->isCloud() ? "$url/cloudlab-users" :
	    $self->isPNet() ? "$url/phantomnet-users" :
	    $self->isPowder() ? "$url/powder-users" :
	    "$url/emulab-users");
}

# So we can localize MAILTAG variable.
sub SendEmail($$$$;$$@)
{
    my ($self, $to, $subject, $body, $from, $headers, @files) = @_;

    # All this function does is this. 
    local $libtestbed::MAILTAG = $self->EmailTag();
    
    SENDMAIL($to, $subject, $body, $from, $headers, @files);
    return 0;
}

# _Always_ make sure that this 1 is at the end of the file...
1;
