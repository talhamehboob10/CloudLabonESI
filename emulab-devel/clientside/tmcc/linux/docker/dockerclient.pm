#!/usr/bin/perl
#
# Copyright (c) 2017, 2018 University of Utah and the Flux Group.
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
# A perl binding for a subset of the Docker Engine API.
#
package dockerclient;
use strict;
use Exporter;
use vars qw(@EXPORT %METHODS);
use base qw( Exporter );
@EXPORT = qw();

use warnings;
use English;
use Data::Dumper;
use LWP::UserAgent;
use LWP::Protocol::http::SocketUnixAlt;
use HTTP::Request;
use HTTP::Headers;
use JSON::PP;
use URI::Escape;
use MIME::Base64 qw(encode_base64url encode_base64);
use overload ('""' => 'stringify');

%METHODS = ();

#
# Turn off line buffering on output
#
$| = 1;

my $DOCKSOCK = "/var/run/docker.sock";

BEGIN {
    #
    # Seems like we cannot just instantiate a unix sock protocol and
    # pass it to a UserAgent; we have to set a "protocol implementor".
    # So we use a fake protocol to ensure we don't collide with a legit
    # protocol.
    #
    LWP::Protocol::implementor(dlhttp => 'LWP::Protocol::http::SocketUnixAlt');
};

sub new($;$$) {
    my ($class,$sockpath,$debug) = @_;

    my $self = {};

    $sockpath = $DOCKSOCK
	if (!defined($sockpath));
    $self->{"debug"} = 0;
    if (defined($debug)) {
	$self->{"debug"} = int($debug);
    }
    $self->{"sockpath"} = $sockpath;
    $self->{"ua"} = LWP::UserAgent->new(timeout => -1);

    bless($self,$class);

    return $self;
}

sub stringify($) {
    my ($self) = @_;
    return "dockerclient(".$self->sockpath().")";
}

sub debug($;$) {
    my ($self,$newval) = @_;
    if (defined($newval)) {
	$self->{"debug"} = $newval;
    }
    return $self->{"debug"};
}

sub dprint($$;@) {
    my ($self,$level,@args) = @_;
    if ($self->debug() >= $level) {
	my $str = join('',@args);
	chomp($str);
	print STDERR "DEBUG: $self: $str\n";
    }
}

sub isdebug($$) {
    my ($self,$level) = @_;
    if ($self->debug() >= $level) {
	return 1;
    }
    else {
	return 0;
    }
}

sub sockpath($;$) {
    my ($self,$newpath) = @_;
    if (defined($newpath)) {
	$self->{"sockpath"} = $newpath;
    }
    return $self->{"sockpath"};
}

sub _handle_response($$) {
    my ($self,$resp) = @_;

    if ($self->isdebug(10)) {
	$self->dprint(10,"response: ".Dumper($resp));
    }
    elsif ($self->isdebug(3)) {
	my $msg = "response:";
	$msg .= " code=".$resp->code();
	if (defined($resp->header("content-type"))) {
	    $msg .= ",content-type=".$resp->header("content-type");
	}
	if (defined($resp->header("content-length"))) {
	    $msg .= ",content-length=".$resp->header("content-length");
	}
	$msg .= ",content=".substr($resp->content(),0,512);
	chomp($msg);
	$self->dprint(3,$msg."\n");
    }
    my $success = $resp->is_success;
    my $content = $resp->content;
    my $ctype = $resp->header("Content-Type");
    if (defined($ctype) && $ctype eq "application/json") {
	my $chh = $resp->header("client-transfer-encoding");
	if (defined($chh) && $chh eq 'chunked') {
	    my @contents = split('\n',$content);
	    my @chunks = ();
	    for my $c (@contents) {
		$c = decode_json($c);
		push(@chunks,$c);
	    }
	    $content = \@chunks;
	}
	else {
	    $content = decode_json($content);
	    if (!$success
		&& ref($content) eq 'HASH' && exists($content->{"message"})) {
		$content = $content->{"message"};
	    }
	}
	$self->dprint(6,"response decoded content = ".Dumper($content)."\n");
    }
    if ($success) {
	return (0,$content,$resp);
    }
    else {
	return ($resp->code,$content,$resp);
    }
}

sub _request($$;$) {
    my ($self,$req,$callback) = @_;

    if ($self->isdebug(10)) {
	$self->dprint(10,"request: ".Dumper($req));
    }
    elsif ($self->isdebug(3)) {
	my $msg = "request:";
	$msg .= " ".$req->method()." ".$req->uri();
	if (defined($req->header("content-type"))) {
	    $msg .= ",content-type=".$req->header("content-type");
	}
	if (defined($req->header("content-length"))) {
	    $msg .= ",content-length=".$req->header("content-length");
	}
	if ($req->content() ne '') {
	    $msg .= ",content=".substr($req->content(),0,512);
	}
	chomp($msg);
	$self->dprint(3,$msg."\n");
    }

    return $self->_handle_response($self->{"ua"}->request($req,$callback));
}

sub _post($$;$$$) {
    my ($self,$uri,$headers,$content,$callback) = @_;

    my $req = HTTP::Request->new(
	"POST","dlhttp:".$self->sockpath()."/"."$uri",$headers,$content);
    #   ":content_cb" => $cb);
    return $self->_request($req,$callback);
}

sub _get($$;$$$) {
    my ($self,$uri,$headers,$content,$callback) = @_;

    my $req = HTTP::Request->new(
	"GET","dlhttp:".$self->sockpath()."/"."$uri",$headers,$content);

    return $self->_request($req,$callback);
}

sub _head($$$;$) {
    my ($self,$uri,$headers,$content) = @_;

    my $req = HTTP::Request->new(
	"HEAD","dlhttp:".$self->sockpath()."/"."$uri",$headers,$content);
    return $self->_request($req);
}

sub _delete($$$;$) {
    my ($self,$uri,$headers,$content) = @_;

    my $req = HTTP::Request->new(
	"DELETE","dlhttp:".$self->sockpath()."/"."$uri",$headers,$content);
    return $self->_request($req);
}

$METHODS{'container_create'} = {
    'required' => ['name'],
    'optional' => ['args'],
    'help' => "Create a container",
    'phelp' => { 'name' => "The container name",
		 'args' => "A dict/hash of create parameters" }
};
sub container_create($$;$) {
    my ($self,$name,$args) = @_;

    my $headers = HTTP::Headers->new();
    $headers->header("Content-Type" => "application/json");
    if (defined($args)) {
	if (!exists($args->{'AttachStdin'})) {
	    $args->{'AttachStdin'} = JSON::PP::false;
	}
        $args = encode_json($args);
	return $self->_post("/containers/create?name=$name",$headers,$args);
    }
    else {
	return $self->_post("/containers/create?name=$name",$headers);
    }
}

$METHODS{'container_run'} = {
    'required' => ['id','image','cmd'],
    'optional' => ['args','remove'],
    'help' => "Run a command in a container",
    'phelp' => { 'id' => "The container name or id",
		 'args' => "A dict/hash of create parameters",
		 'image' => "The image the container will run",
		 'cmd' => "The command the container will run",
		 'remove' => "If true, the container will be removed when the command completes" }
};
sub container_run($$$$;$$$) {
    my ($self,$id,$image,$cmd,$remove,$args,$callback) = @_;

    $args ||= {};
    $callback ||= sub { print $_[0]; };
    if (!defined($remove)) {
	$remove = 0;
    }

    my $headers = HTTP::Headers->new();
    $headers->header("Content-Type" => "application/json");
    if (!exists($args->{'AttachStdout'})) {
	$args->{'AttachStdout'} = JSON::PP::true;
    }
    if (!exists($args->{'AttachStderr'})) {
	$args->{'AttachStderr'} = JSON::PP::true;
    }
    $args->{'Image'} = $image;
    $args->{'Cmd'} = $cmd;
    my ($code,$content,$resp);
    ($code,$content) = $self->container_create($id,$args);
    if ($code) {
	warn("failed to create container $id, aborting\n");
	return ($code,$content);
    }
    ($code,$content) = $self->container_start($id);
    if ($code) {
	warn("failed to start container $id, aborting\n");
	return ($code,$content);
    }
    my ($doin,$doout,$doerr) = (0,0,0);
    if (exists($args->{'AttachStdin'}) && $args->{'AttachStdin'}) {
	$doin = 1;
    }
    if (exists($args->{'AttachStdout'}) && $args->{'AttachStdout'}) {
	$doout = 1;
    }
    if (exists($args->{'AttachStderr'}) && $args->{'AttachStderr'}) {
	$doerr = 1;
    }
    ($code,$content) = $self->container_attach(
	$id,1,1,$doin,$doout,$doerr,0,$callback);
    if ($code) {
	warn("failed to attach to container $id, aborting\n");
	return ($code,$content);
    }
    ($code,$content,$resp) = $self->container_wait($id);
    if ($code) {
	warn("failed to wait for container $id, aborting\n");
	return ($code,$content);
    }
    my $retval;
    if (ref($content) eq 'ARRAY') {
	$retval = $content->[0]->{"StatusCode"};
    }
    else {
	$retval = $content->{"StatusCode"};
    }
    if ($remove) {
	my ($code2,$content2) = $self->container_delete($id);
	if ($code2) {
	    warn("failed to delete container $id, aborting\n");
	    return ($code2,$content2);
	}
    }

    return ($code,$content,$resp,$retval);
}

$METHODS{'container_inspect'} = {
    'required' => ['id'],
    'help' => "Return the full JSON info for the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_inspect($$) {
    my ($self,$id) = @_;

    return $self->_get("/containers/$id/json");
}

$METHODS{'container_state'} = {
    'required' => ['id'],
    'help' => "Return the JSON state of the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_state($$) {
    my ($self,$id) = @_;

    my ($code,$content,$res) = $self->container_inspect($id);
    if ($code) {
	return ($code,$content,$res);
    }
    else {
	return (0,$content->[0]->{"State"},$res);
    }
}

$METHODS{'container_status'} = {
    'required' => ['id'],
    'help' => "Return the one-word status of the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_status($$) {
    my ($self,$id) = @_;

    my ($code,$content,$res) = $self->container_inspect($id);
    if ($code) {
	return ($code,$content,$res);
    }
    else {
	return (0,$content->[0]->{"State"}{"Status"},$res);
    }
}

$METHODS{'container_start'} = {
    'required' => ['id'],
    'help' => "Start the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_start($$) {
    my ($self,$id) = @_;

    return $self->_post("/containers/$id/start");
}

$METHODS{'container_stop'} = {
    'required' => ['id'],
    'help' => "Stop the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_stop($$) {
    my ($self,$id) = @_;

    return $self->_post("/containers/$id/stop");
}

$METHODS{'container_restart'} = {
    'required' => ['id'],
    'help' => "Restart the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_restart($$) {
    my ($self,$id) = @_;

    return $self->_post("/containers/$id/restart");
}

$METHODS{'container_pause'} = {
    'required' => ['id'],
    'help' => "Pause the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_pause($$) {
    my ($self,$id) = @_;

    return $self->_post("/containers/$id/pause");
}

$METHODS{'container_unpause'} = {
    'required' => ['id'],
    'help' => "Unpause the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_unpause($$) {
    my ($self,$id) = @_;

    return $self->_post("/containers/$id/unpause");
}

$METHODS{'container_attach'} = {
    'required' => ['id','stream','logs','stdin','stdout','stderr'],
    'optional' => ['istty'],
    'help' => "Attach to the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_attach($$$$$$$;$$) {
    my ($self,$id,$stream,$logs,$stdin,$stdout,$stderr,$istty,$func) = @_;

    sub printer {
	my ($data,$resp) = @_;
	if (defined($data)) {
	    print $data;
	}
    }
    if (!defined($func)) {
	$func = \&printer;
    }

    my %args = ();
    if (defined($stream)) {
	if ($stream) {
	    $args{'stream'} = JSON::PP::true;
	}
	else {
	    $args{'stream'} = JSON::PP::false;
	}
    }
    if (defined($logs)) {
	if ($logs) {
	    $args{'logs'} = JSON::PP::true;
	}
	else {
	    $args{'logs'} = JSON::PP::false;
	}
    }
    if (defined($stdin)) {
	if ($stdin) {
	    $args{'stdin'} = JSON::PP::true;
	}
	else {
	    $args{'stdin'} = JSON::PP::false;
	}
    }
    if (defined($stdout)) {
	if ($stdout) {
	    $args{'stdout'} = JSON::PP::true;
	}
	else {
	    $args{'stdout'} = JSON::PP::false;
	}
    }
    if (defined($stderr)) {
	if ($stderr) {
	    $args{'stderr'} = JSON::PP::true;
	}
	else {
	    $args{'stderr'} = JSON::PP::false;
	}
    }
    #
    # The docker client uses these, but they are mostly to avoid
    # problems when going through proxies, which we don't have to be
    # concerned about.  Moreover, it causes us problems, since LWP can't
    # handle the 101 connection upgraded header in the response.
    #
    #my $headers = HTTP::Headers->new();
    #$headers->header('Connection','Upgrade');
    #$headers->header('Upgrade','tcp');

    my $uri = "/containers/$id/attach";
    if (keys(%args)) {
	$uri .= "?";
	my $first = 1;
	foreach my $k (keys(%args)) {
	    if (!$first) {
		$uri .= "&";
	    }
	    else {
		$first = 0;
	    }
	    $uri .= "$k=$args{$k}";
	}
    }

    return $self->_post($uri,undef,undef,$func);
}

$METHODS{'container_wait'} = {
    'required' => ['id'],
    'help' => "Wait for the container to stop",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_wait($$) {
    my ($self,$id) = @_;

    return $self->_post("/containers/$id/wait");
}

$METHODS{'container_delete'} = {
    'required' => ['id'],
    'help' => "Delete the container",
    'phelp' => { 'id' => "The container name or id" }
};
sub container_delete($$) {
    my ($self,$id) = @_;

    return $self->_delete("/containers/$id");
}

$METHODS{'container_commit'} = {
    'required' => ['id','repo','tag'],
    'help' => "Commit the given container as a new local image",
    'phelp' => { 'id' => "The container name or id",
		 'repo' => "The full image repo/name",
		 'tag' => "The identifier the image should be tagged with" }
};
sub container_commit($$$$) {
    my ($self,$id,$repo,$tag) = @_;

    my $erepo = uri_escape($repo);
    my $etag = uri_escape($tag);
    
    return $self->_post("/commit?container=$id&repo=$erepo&tag=$etag");
}

$METHODS{'container_exec'} = {
    'required' => ['id','cmd'],
    'optional' => ['argsref'],
    'help' => "Exec the given command inside the given container",
    'phelp' => { 'id' => "The container name or id",
		 'cmd' => "The command (as an array!)",
		 'argsref' => "A dict of additional API args to the exec command" }
};
sub container_exec($$$;$) {
    my ($self,$id,$cmd,$argsref) = @_;

    my $eid = $id . "-" . time() . "-" . int(rand(POSIX::INT_MAX));
    my %args = ();
    if (defined($argsref)) {
	%args = %$argsref;
    }
    if (defined($cmd)) {
	if (ref($cmd) ne 'ARRAY') {
	    $args{'Cmd'} = [ "/bin/sh","-c",$cmd ];
	}
	else {
	    $args{'Cmd'} = $cmd;
	}
    }
    if (!exists($args{'AttachStdout'})) {
	$args{'AttachStdout'} = JSON::PP::true;
    }
    if (!exists($args{'AttachStderr'})) {
	$args{'AttachStderr'} = JSON::PP::true;
    }
    if (!exists($args{'AttachStdin'})) {
	$args{'AttachStdin'} = JSON::PP::false;
    }
    my $headers = HTTP::Headers->new();
    $headers->header('Content-Type','application/json');
    my ($code,$content) = $self->_post(
	"/containers/$id/exec",$headers,encode_json(\%args));
    if ($code) {
	warn("failed to create container $id exec id $eid: $content ($code)\n");
	return ($code,$content);
    }
    my $deid = $content->{"Id"};
    %args = ( 'Tty' => JSON::PP::true,'Detach' => JSON::PP::false );

    return $self->_post("/exec/$deid/start",$headers,encode_json(\%args));
}

$METHODS{'image_list'} = {
    'optional' => ['filters','all','digests'],
    'help' => "Return a list of the (possibly filtered) local images",
    'phelp' => { 'filters' => "A dict of filter keys/values",
		 'all' => "If set true, show all image layers, not just final layers (those with no children)",
		 'digests' => "Show digest information" }
};
sub image_list($;$$$) {
    my ($self,$filters,$all,$digests) = @_;

    my $qstr = "";
    if (defined($filters) && $filters ne '') {
	$qstr = "?filters=" . encode_json($filters);
    }
    if (defined($all) && $all) {
	if ($qstr ne '') {
	    $qstr .= "&all=true";
	}
	else {
	    $qstr = "?all=true";
	}
    }
    if (defined($digests) && $digests) {
	if ($qstr ne '') {
	    $qstr .= "&digests=true";
	}
	else {
	    $qstr = "?digests=true";
	}
    }
    return $self->_get("/images/json$qstr");
}

$METHODS{'image_inspect'} = {
    'required' => ['image'],
    'help' => "Return a JSON dump of the given image",
    'phelp' => { 'id' => "The image name or id" }
};
sub image_inspect($$) {
    my ($self,$image) = @_;

    return $self->_get("/images/$image/json");
}

$METHODS{'image_history'} = {
    'required' => ['image'],
    'help' => "Return a JSON dump of the given image",
    'phelp' => { 'id' => "The image name or id" }
};
sub image_history($$) {
    my ($self,$image) = @_;

    return $self->_get("/images/$image/history");
}

$METHODS{'image_pull'} = {
    'required' => ['image'],
    'optional' => ['user','pass'],
    'help' => "Pull the requested image",
    'phelp' => { 'id' => "The full image name or id",
		 'user' => "The username to authenticate to the registry",
		 'pass' => "The password to authenticate to the registry" }
};
sub image_pull($$;$$) {
    my ($self,$image,$user,$pass) = @_;

    my $headers = HTTP::Headers->new();
    if (defined($user) && $user ne "") {
	# Default to the default registry if the image doesn't have a
	# host:port part.
	my $registry = "registry-1.docker.io";
	if ($image =~ /^([a-zA-Z0-9-\.]+)(:\d+)?\/.*$/) {
	    $registry = "$1$2";
	}
	my $auth = encode_base64url(
	    '{"serveraddress":"$registry","username":"'.$user.'","password":"'.$pass.'"}'."");
	chomp($auth);
	$auth =~ tr/\r\n//;
	my $pc = (3 - (length($auth) % 3));
	if ($pc) {
	    $auth .= '=' x $pc;
	}
	$headers->header('X-Registry-Auth' => $auth);
    }
    my $uimage = uri_escape($image);

    return $self->_post("/images/create?fromImage=$uimage",$headers);
}

$METHODS{'image_push'} = {
    'required' => ['image'],
    'optional' => ['tag','user','pass'],
    'help' => "Push the given image",
    'phelp' => { 'id' => "The full image name or id",
		 'tag' => "The image tag to push",
		 'user' => "The username to authenticate to the registry",
		 'pass' => "The password to authenticate to the registry" }
};
sub image_push($$;$$$$) {
    my ($self,$image,$tag,$user,$pass,$callback) = @_;

    my $headers = HTTP::Headers->new();
    if (defined($user) && $user ne "") {
	# Default to the default registry if the image doesn't have a
	# host:port part.
	my $registry = "registry-1.docker.io";
	if ($image =~ /^([a-zA-Z0-9-\.]+)(:\d+)?\/.*$/) {
	    $registry = "$1$2";
	}
	my $auth = encode_base64url(
	    '{"serveraddress":"$registry","username":"'.$user.'","password":"'.$pass.'"}'."");
	chomp($auth);
	$auth =~ tr/\r\n//;
	my $pc = (3 - (length($auth) % 3));
	if ($pc) {
	    $auth .= '=' x $pc;
	}
	$headers->header('X-Registry-Auth' => $auth);
    }
    my $uimage = uri_escape($image);
    my $uri = "/images/$uimage/push";
    if (defined($tag) and $tag ne '') {
	$uri .= "?tag=$tag";
    }

    return $self->_post($uri,$headers,undef,$callback);
}

$METHODS{'image_build_from_tar_bytes'} = {
    'required' => ['bytes'],
    'optional' => ['nametag','dockerfilepath','argsref'],
    'help' => "Build an image from the given tar archive bytes",
    'phelp' => { 'bytes' => "The contents of a tar archive including a Dockerfile",
		 'nametag' => "A name:tag value to name and tag the new image",
		 'dockerfilepath' => "The relative path to the Dockerfile within the tar archive",
		 'argsref' => "A dict of additional API args to the build command" }
};
sub image_build_from_tar_bytes($$;$$$$) {
    my ($self,$bytes,$nametag,$dockerfilepath,$argsref,$callback) = @_;

    my %args = ();
    %args = %$argsref
	if (defined($argsref));
    $args{'dockerfile'} = $dockerfilepath
	if (defined($dockerfilepath));
    $args{'t'} = $nametag
	if (defined($nametag));

    my $headers = HTTP::Headers->new();
    $headers->header('Content-Type','application/tar');
    my $uriargs = "";
    foreach my $k (keys(%args)) {
	if ($uriargs eq '') {
	    $uriargs = '?';
	}
	else {
	    $uriargs .= '&';
	}
	$uriargs .= "$k=" . $args{$k};
    }

    return $self->_post("/build$uriargs",$headers,$bytes,$callback);
}

$METHODS{'image_build_from_tar_file'} = {
    'required' => ['file'],
    'optional' => ['nametag','dockerfilepath','argsref'],
    'help' => "Build an image from the given tar archive bytes",
    'phelp' => { 'file' => "A tar archive file",
		 'nametag' => "A name:tag value to name and tag the new image",
		 'dockerfilepath' => "The relative path to the Dockerfile within the tar archive",
		 'argsref' => "A dict of additional API args to the build command" }
};
sub image_build_from_tar_file($$;$$$$) {
    my ($self,$file,$nametag,$dockerfilepath,$argsref,$callback) = @_;

    my $buf;
    open(FD,$file)
	or die("open($file): $@");
    while (<FD>) {
	$buf .= $_;
    }
    close(FD);

    return $self->image_build_from_tar_bytes(
	$buf,$nametag,$dockerfilepath,$argsref);
}

$METHODS{'network_inspect'} = {
    'required' => ['id'],
    'help' => "Return a JSON dump of the given network",
    'phelp' => { 'id' => "The network name or id" }
};
sub network_inspect($$) {
    my ($self,$id) = @_;

    return $self->_get("/networks/$id");
}

$METHODS{'network_create_bridge'} = {
    'required' => ['name','cidr','gateway'],
    'optional' => ['brname'],
    'help' => "Create a new 802.11 bridged network",
    'phelp' => { 'name' => "The new network name",
		 'cidr' => "The new network's subnet in CIDR notation",
		 'gateway' => "The new network's gateway IP address",
		 'brname' => "The existing bridge name that should be used to build the new network atop" }
};
sub network_create_bridge($$$$;$$) {
    my ($self,$name,$cidr,$gateway,$brname,$arghashref) = @_;

    my $headers = HTTP::Headers->new();
    $headers->header("Content-Type" => "application/json");
    my $data = {
	"Name" => $name,"Driver" => "bridge",
	"IPAM" => { 
	    "Config" => [ { "Subnet" => $cidr,"Gateway" => $gateway } ]
	}
    };
    if (defined($brname)) {
	$data->{"Options"} = { "com.docker.network.bridge.name" => $brname };
    }
    if (defined($arghashref) && ref($arghashref) eq 'HASH') {
	require Hash::Merge;
	if ($self->debug()) {
	    print STDERR "DEBUG: pre-merge args = ".Dumper($data)."\n";
	    print STDERR "DEBUG: pre-merge arghashref = ".Dumper($arghashref)."\n";
	}
	$data = Hash::Merge::merge($data,$arghashref);
	if ($self->debug()) {
	    print STDERR "DEBUG: merged args = ".Dumper($data)."\n";
	}
    }
    return $self->_post("/networks/create",$headers,encode_json($data));
}

$METHODS{'network_create_macvlan'} = {
    'required' => ['name','cidr','gateway'],
    'optional' => ['basedev'],
    'help' => "Create a new MACVLAN network",
    'phelp' => { 'name' => "The new network name",
		 'cidr' => "The new network's subnet in CIDR notation",
		 'gateway' => "The new network's gateway IP address",
		 'basedev' => "The existing macvlan device name that should be used to build the new network atop" }
};
sub network_create_macvlan($$$$;$$) {
    my ($self,$name,$cidr,$gateway,$basedev,$arghashref) = @_;

    my $headers = HTTP::Headers->new();
    $headers->header("Content-Type" => "application/json");
    my $data = {
	"Name" => $name,"Driver" => "macvlan",
	"IPAM" => {
	    "Config" => [ { "Subnet" => $cidr,"Gateway" => $gateway } ]
	}
    };
    if (defined($basedev)) {
	$data->{"Options"} = { "parent" => $basedev };
    }
    if (defined($arghashref) && ref($arghashref) eq 'HASH') {
	require Hash::Merge;
	if ($self->debug()) {
	    print STDERR "DEBUG: pre-merge args = ".Dumper($data)."\n";
	    print STDERR "DEBUG: pre-merge arghashref = ".Dumper($arghashref)."\n";
	}
	$data = Hash::Merge::merge($data,$arghashref);
	if ($self->debug()) {
	    print STDERR "DEBUG: merged args = ".Dumper($data)."\n";
	}
    }
    return $self->_post("/networks/create",$headers,encode_json($data));
}

$METHODS{'network_connect_container'} = {
    'required' => ['id','container','ip','maskbits','macaddr'],
    'help' => "Connect the given container to a network",
    'phelp' => { 'id' => "The network name or id",
		 'container' => "The container name or id",
		 'ip' => "The new container IP on this network",
		 'maskbits' => "The number of bits in the netmask",
		 'macaddr' => "The MAC address to use for the new container interface" }
};
sub network_connect_container($$$$$$) {
    my ($self,$id,$container,$ip,$maskbits,$macaddr) = @_;

    my $headers = HTTP::Headers->new();
    $headers->header("Content-Type" => "application/json");
    my $args = { "Container" => $container,
		 "EndpointConfig" => {
		     "IPAMConfig" => { "IPv4Address" => $ip },
		     "IPPrefixLen" => $maskbits,
		     "Gateway" => "",
		     "MacAddress" => $macaddr }
    };
    return $self->_post("/networks/$id/connect",$headers,encode_json($args));
}

$METHODS{'network_delete'} = {
    'required' => ['id'],
    'help' => "Delete the given network",
    'phelp' => { 'id' => "The network name or id" }
};
sub network_delete($$) {
    my ($self,$id) = @_;

    return $self->_delete("/networks/$id");
}

$METHODS{'registry_auth'} = {
    'required' => ['registry','user','pass'],
    'help' => "Validate credentials for a registry",
    'phelp' => { 'registry' => "The network name or id" }
};
sub registry_auth($$$$) {
    my ($self,$registry,$user,$pass) = @_;

    my $body = encode_json(
	{"serveraddress" => $registry,"username" => $user,"password" => $pass});
    return $self->_post("/auth",undef,$body);
}

$METHODS{'monitor_events'} = {
    'optional' => ['filters','since','until'],
    'help' => "Monitor docker events",
    'phelp' => { 'filters' => "A dict of filters",
		 'since' => "Show events since this UNIX timestamp then stream",
		 'until' => "Show events create until this timestamp, then stop" }
};
sub monitor_events($;$$$) {
    my ($self,$filters,$since,$until,$callback) = @_;

    $callback ||= sub { print $_[0]; };

    my $params = "";
    if (defined($filters)) {
	$params .= "filters=".encode_json($filters);
    }
    if (defined($since)) {
	if ($params ne '') {
	    $params .= "&";
	}
	$params .= "since=$since";
    }
    if (defined($until)) {
	if ($params ne '') {
	    $params .= "&";
	}
	$params .= "until=$until";
    }
    if ($params ne '') {
	$params = "?$params";
    }

    return $self->_get("/events$params",undef,undef,$callback);
}

1;
