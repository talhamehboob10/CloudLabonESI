#
# Copyright (c) 2012 University of Utah and the Flux Group.
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
# Script for preparing a vanilla Windows 7 installation for Emulab
#

# First, grab script arguments - I really hate that this must come first
# in a powershell script (before any other executable lines).
param([string]$actionfile, [switch]$debug, [string]$logfile, [switch]$quiet)

#
# Constants
#
$MAXSLEEP = 1800
$DEFLOGFILE="C:\Windows\Temp\runsequence.log"
$FAIL = "fail"
$SUCCESS = "success"
$REG_TYPES = @("String", "Dword")
$BASH = "C:\Cygwin\bin\bash.exe"
$BASHARGS = "-l -c"
$CMDTMP = "C:\Windows\Temp\_tmpout-basesetup"
$VAR_RE = '[a-zA-Z]\w{1,30}'
$REGENVPATHKEY = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
$REGENVPATHVAL = "Path"
$REGENVPATHTYPE = "ExpandString"
$MAXPASSLEN = 32
$USERRE = '^\w{4,30}$'

#
# Global Variables
#
$outlog = $DEFLOGFILE
$uservars = @{}

#
# Utility functions
#

# Log to $LOGFILE
Function log($msg) {
	$time = Get-Date -format g
	$outmsg = $time + ": " + $msg
	$outmsg | Out-File -encoding "ASCII" -append $outlog
	if (!$quiet) {
		$outmsg | Out-Host
	}
}

Function debug($msg) {
	if ($debug) {
		log("DEBUG: $msg")
	}
}

Function lograw($msg) {
	$msg | Out-File -encoding "ASCII" -append $outlog
}

Function logfilecontents($fname) {
	Get-Content $fname | Out-File -encoding "ASCII" -append $outlog
}

Function isNumeric ($x) {
	$x2 = 0
	$isNum = [System.Int32]::TryParse($x, [ref]$x2)
	return $isNum
}

Function replace_uservars($cmdstr) {
	$uservars.getenumerator() | % {
		$key = $_.key
		$value = $_.value
		$cmdstr = [regex]::Replace($cmdstr, "%$key%", $value)
	}
	return $cmdstr
}

# black magic
Function decode_secstring($secstr) {
	$marshall = [System.Runtime.InteropServices.Marshal]
	$Ptr = $marshall::SecureStringToCoTaskMemUnicode($secstr)
	$result = $marshall::PtrToStringUni($Ptr)
	$marshall::ZeroFreeCoTaskMemUnicode($Ptr)
	return $result 
}

#
# Action execution functions
#

Function log_func($cmdarr) {
	foreach ($logline in $cmdarr) {
		log($logline)
	}

	return $SUCCESS
}

Function defvar_func($cmdarr) {
	debug("defvar called with: $cmdarr")

	if (!$cmdarr -or $cmdarr.count -ne 2) {
		log("Must supply variable and value to defvar.")
		return $FAIL
	}
	$myvar, $myval = $cmdarr
	# check variable name for sanity
	if ($myvar -notmatch "^$VAR_RE$") {
		log("Invalid variable token: $myvar")
		return $FAIL
	}

	$uservars.Add($myvar, $myval)
	return $SUCCESS
}

Function readvar_func($cmdarr) {
	debug("readvar called with: $cmdarr")

	if (!$cmdarr -or $cmdarr.count -lt 2) {
		log("Must supply variable name and prompt string to readvar.")
		return $FAIL
	}
	$myvar, $myprompt, $secure = $cmdarr
	# check variable name for sanity
	if ($myvar -notmatch "^$VAR_RE$") {
		log("Invalid variable token: $myvar")
		return $FAIL
	}

	if ($secure) {
		$myval = decode_secstring(Read-Host -assecurestring $myprompt)
		$verf  = decode_secstring(Read-Host -assecurestring "$myprompt (verify)")
		if ($myval -ne $verf) {
			log("ERROR: strings do not match.")
			return $FAIL
		}
	} else {
		$myval = Read-Host $myprompt
	}

	if (!$myval) {
		log("ERROR: No input provided for value.")
		return $FAIL
	}

	$uservars.Add($myvar, $myval)
	return $SUCCESS	
}

# Create or set an existing registry value.  Create entire key path as required.
# XXX: Update to return powershell errors
Function addreg_func($cmdarr) {
	debug("addreg called with: $cmdarr")

	# set / check args
	if (!$cmdarr -or $cmdarr.count -ne 4) {
		log("addreg called with improper argument list")
		return $FAIL
	}
	$path, $vname, $type, $value = $cmdarr
	$regpath = "Registry::$path"
	if ($REG_TYPES -notcontains $type) {
		log("ERROR: Unknown registry value type specified: $type")
		return $FAIL
	}
	if (!(Test-Path -IsValid -Path $regpath)) {
		log("Invalid registry key specified: '$path'")
		return $FAIL
	}
	
	# Set the value, creating the full key path if necessary
	if (!(Test-Path -Path $regpath)) {
		if (!(New-Item -Path $regpath -Force)) {
			log("Couldn't create registry key path: '$path'")
			return $FAIL
		}
	}
	if (!(New-ItemProperty -Path $regpath -Name $vname `
	      -PropertyType $type -Value $value -Force)) {
		    log("ERROR: Could not set registry value: '$vname' to '$value'")
		    return $FAIL
	    }

	return $SUCCESS
}

# XXX: Expands variables in path value.  Need to figure out how to get it to 
#      not do this.
Function modpathenv_func($cmdarr) {
	debug("appendpath called with: $cmdarr")

	if ($cmdarr.count -ne 2) {
		log("Must supply a string to append and operation.")
		return $FAIL
	}

	$path,$op = $cmdarr

	if (!(Test-Path -IsValid -Path $path)) {
		log("Invalid path given: $path")
		return $FAIL
	}

	$envobj = Get-ItemProperty -Path $REGENVPATHKEY -Name $REGENVPATHVAL
	$envstr = $envobj.$REGENVPATHVAL
	if ($op -eq "append") {
		$envstr += ";${path}"
	} elseif ($op -eq "prepend") {
		$envstr = "${path};${envstr}"
	} else {
		log("ERROR: Bad operation provided: $op")
		return $FAIL
	}

	New-ItemProperty -Path $REGENVPATHKEY -Name $REGENVPATHVAL `
	    -PropertyType $REGENVPATHTYPE -Value $envstr -Force
	
	return $SUCCESS
}

Function reboot_func($cmdarr) {
	debug("reboot called with: $cmdarr")

	if ($cmdarr) {
		$force = $cmdarr
	}

	# Reboot ...
	if ($force) {
		"force reboot..." | Out-Host
		#Retart-Computer -Force
	} else {
		"reboot..." | Out-Host
		#Restart-Computer
	}

	return $SUCCESS
}

Function sleep_func($cmdarr) {
	debug("sleep called with: $cmdarr")

	if ($cmdarr.count -lt 1) {
		log("ERROR: Must supply a time to sleep!")
		return $FAIL
	}

	$wtime = $cmdarr[0]
	if (!(isNumeric($wtime)) -or `
	    (0 -gt $wtime) -or `
	    ($MAXSLEEP -lt $wtime))
	{
		log("ERROR: Invalid sleep time: $wtime")
		return $FAIL
	}

	# Sleep...
	Start-Sleep -s $wtime
	
	return $SUCCESS
}

Function runcmd_func($cmdarr) {
	debug("runcmd called with: $cmdarr")

	if ($cmdarr.count -lt 1) {
		log("No command given to run.")
		return $FAIL
	}

	$cmd, $cmdargs, $expret = $cmdarr
	
	# XXX: Implement timeout?
	$procargs = @{
		FilePath = $cmd
		ArgumentList = $cmdargs
		RedirectStandardOutput = $CMDTMP
		NoNewWindow = $true
		PassThru = $true
		Wait = $true
	}
	$proc = $null
	try {
		$proc = Start-Process @procargs
	} catch {
		log("ERROR: failed to execute command: $cmd: $_")
		Remove-Item -Path $CMDTMP
		return $FAIL
	}
	
	if ($debug) {
		debug("Command output:")
		logfilecontents($CMDTMP)
	}
	
	Remove-Item -Path $CMDTMP

	# $null is a special varibale in PS - always null!
	if ($expret -ne $null -and $proc.ExitCode -ne $expret) {
		log("Command returned unexpected code: " + $proc.ExitCode)
		return $FAIL
	}

	return $SUCCESS
}

# XXX: still doesn't seem to process Cygwin exit codes properly.
Function runcyg_func($cmdarr) {
	debug("runcyg called with: $cmdarr")

	if ($cmdarr.count -lt 1) {
		log("No command given to run.")
		return $FAIL
	}

	if (!(Test-Path $BASH)) {
		log("Bash not present - Is Cygwin installed?")
		return $FAIL
	}

	# Push the bash args, command + args into place as 
	# the new argument string and insert bash as the command to run.  
	# Pass this to runcmd_func.
	$cmdarr[1] = $BASHARGS + ' "' + $cmdarr[0] + '"'
	$cmdarr[0] = $BASH
	return runcmd_func($cmdarr)
}

Function getfile_func($cmdarr) {
	debug("getfile called with: $cmdarr")
	$retcode = $FAIL

	if ($cmdarr.count -lt 2) {
		log("URL and local file must be provided.")
		return $FAIL
	}

	$url, $filename = $cmdarr
	if (Test-Path -Path $filename) {
		log("WARNING: Overwriting existing file: $filename")
	}
	
	try {
		$webclient = New-Object System.Net.WebClient
		$webclient.DownloadFile($url,$filename)
		$retcode = $SUCCESS
	} catch {
		log("Error Trying to download file: $filename: $_")
		$retcode = $FAIL
		continue
	}

	return $retcode
}

Function mkdir_func($cmdarr) {
	debug("mkdir called with: $cmdarr")
	if ($cmdarr.count -ne 1) {
		log("Must specify directory to create and nothing else!")
		return $FAIL
	}

	$dir = $cmdarr[0]
	if (Test-Path -Path $dir) {
		if (Test-Path -PathType Leaf -Path $dir) {
			log("ERROR: Path already exists, but is not a directory!")
			return $FAIL
		} else {
			log("WARNING: Path already exists: $dir")
		}
	} elseif (!(Test-Path -IsValid -Path $dir)) {
		log("ERROR: Invalid path specified: $dir")
		return $FAIL
	} else {
		try {
			New-Item -ItemType Directory -Path $dir
		} catch {
			log("Error creating new directory: $dir: $_")
			return $FAIL
		}
	}

	return $SUCCESS
}

Function waitproc_func($cmdarr) {
	debug("waitproc called with: $cmdarr")

	if ($cmdarr.count -lt 2) {
		log("Must specify process name and timeout.")
		return $FAIL
	}

	$procname, $timeout, $excode = $cmdarr

	$proc = $null
	try {
		$proc = get-process -name $procname
	} catch {
		log("WARNING: Process not found: $procname")
	} 

	if ($proc) {
		if (!($proc.WaitForExit(1000 * $timeout))) {
			log("ERROR: timeout waiting for process: $procname")
			return $FAIL
		}

		if ($excode -and $proc.ExitCode -ne $excode) {
			log("ERROR: process exited with unexpected code: $proc.ExCode")
			return $FAIL
		}
	}
	
	return $SUCCESS

}

# XXX: Doesn't support Unix-style line endings or output encodings other than
#      ASCII.
Function edfile_func($cmdarr) {
	debug("edfile called with $cmdarr")

	if ($cmdarr.count -ne 3) {
		log("Must specify file to edit, a match pattern, and a replacement pattern.")
		return $FAIL
	}
	$efile, $mpat, $rpat = $cmdarr

	if (!(Test-Path -Path $efile)) {
		log("ERROR: $efile does not exist or can't be accessed.")
		return $FAIL
	}

	$dname = Split-Path -Parent $efile
	$fname = Split-Path -Leaf $efile
	$tmpfile = "${dname}\__${fname}.tmp"

	Get-Content -Path $efile | % {
		$_ -replace $mpat, $rpat
	} | Set-Content -Force -Encoding "ASCII" -Path $tmpfile

	Move-Item -Force -Path $tmpfile -Destination $efile
	return $SUCCESS
}

# XXX: Doesn't support Unix-style line endings or output encodings other than
#      ASCII.
Function appendfile_func($cmdarr) {
	debug("appendfile called with $cmdarr")

	if ($cmdarr.count -ne 2) {
		log("Must specify file to edit, and a line to append to it.")
		return $FAIL
	}
	$efile, $nline = $cmdarr

	if (!(Test-Path -Path $efile)) {
		log("ERROR: $efile does not exist or can't be accessed.")
		return $FAIL
	}

	if ($nline) {
		Add-Content -Force -Encoding "ASCII" -Path $efile -Value $nline
	}
	return $SUCCESS
}

Function adduser_func($cmdarr) {
	debug("adduser called with $cmdarr")

	if ($cmdarr.count -lt 2) {
		log("Must pass in username and password.")
		return $FAIL
	}
	$user, $pass, $admin = $cmdarr

	if ($user -notmatch $USERRE) {
		log("ERROR: Bad username: $user")
		return $FAIL
	}
	if ($pass.length -gt $MAXPASSLEN) {
		log("ERROR: Password is too long")
		return $FAIL
	}

	# This ADSI stuff is just weird.
	try {
		$objUser = [ADSI]"WinNT://$env:computername/$user,user"
		$objUser.refreshcache() # throws exception if no user.
		log("WARNING: User already exists on local machine: $user")
		return $SUCCESS
	} catch {}

	$objOU = [ADSI]"WinNT://$env:computername"
	$objUser = $objOU.Create("User", $user)
	$objUser.setpassword($pass)
	$objUser.SetInfo()

	if ($admin) {
		$objGrp = [ADSI]"WinNT://$env:computername/Administrators,group"
		$objGrp.add($objUser.Path)
	}

	return $SUCCESS
}

Function removeuser_func($cmdarr) {
	debug("removeuser called with $cmdarr")

	if ($cmdarr.count -ne 1) {
		log("Must pass in username to remove.")
		return $FAIL
	}
	$user = $cmdarr[0]

	if ($user -notmatch $USERRE) {
		log("ERROR: Bad username: $user")
		return $FAIL
	}

	try {
		$objUser = [ADSI]"WinNT://$env:computername/$user,user"
		$objUser.refreshcache() # throws exception if no user.
	}
	catch {
		log("WARNING: User does not exist on local machine: $user")
		return $SUCCESS
	}

	$objOU = [ADSI]"WinNT://$env:computername"
	$objUser = [ADSI]"WinNT://$env:computername/$user,user"
	$objUser = $objOU.Delete("User", $objUser.name.value)

	return $SUCCESS
}

# Main starts here
if ($logfile) {
	if (Test-Path -IsValid -Path $logfile) {
		$outlog = $logfile
	} else {
		Write-Host "ERROR: Can't use logfile specified: $logfile"
		exit 1
	}
}

if ($actionfile -and !(Test-Path -pathtype leaf $actionfile)) {
	log("Specified action sequence file does not exist: $actionfile")
	exit 1;
} else {
	log("Executing action sequence: $actionfile")
}

# Parse and run through the actions in the input sequence
foreach ($cmdline in (Get-Content -Path $actionfile)) {
	if (!$cmdline -or ($cmdline.startswith("#"))) {
		continue
	}
	$cmd, $argtoks = $cmdline.split()
	$cmdarr = @()
	if ($argtoks) {
		$cmdargs = [string]::join(" ", $argtoks)
		$cmdargs = replace_uservars($cmdargs)
		$cmdarr = [regex]::split($cmdargs, '\s*;;\s*')
	}
	$result = $FAIL
	# XXX: Maybe refactor all of this with OOP at some point.
	switch($cmd) {
		"log" {
			$result = log_func($cmdarr)
		}
		"addreg" {
			$result = addreg_func($cmdarr)
		}
		"runcmd" {
			$result = runcmd_func($cmdarr)
		}
		"runcyg" {
			$result = runcyg_func($cmdarr)
		}
		"reboot" {
			$result = reboot_func($cmdarr)
		}
		"sleep" {
			$result = sleep_func($cmdarr)
		}
		"getfile" {
			$result = getfile_func($cmdarr)
		}
		"mkdir" {
			$result = mkdir_func($cmdarr)
		}
		"waitproc" {
			$result = waitproc_func($cmdarr)
		}
		"defvar" {
			$result = defvar_func($cmdarr)
		}
		"readvar" {
			$result = readvar_func($cmdarr)
		}
		"edfile" {
			$result = edfile_func($cmdarr)
		}
		"appendfile" {
			$result = appendfile_func($cmdarr)
		}
		"modpathenv" {
			$result = modpathenv_func($cmdarr)
		}
		"adduser" {
			$result = adduser_func($cmdarr)
		}
		"removeuser" {
			$result = removeuser_func($cmdarr)
		}
		default {
			log("WARNING: Skipping unknown action: $cmd")
			$result = $SUCCESS
		}
	}
	if ($result -eq $FAIL) {
		log("ERROR: Action failed: $cmdline")
		log("Exiting!")
		exit 1
	}
}

log("Action sequence finished successfully." )
exit 0
