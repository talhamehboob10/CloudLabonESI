#
# Copyright (c) 2013-2021 University of Utah and the Flux Group.
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

if [ -z ${BASH_VERSINFO[0]} -o ${BASH_VERSINFO[0]} -lt 4 ] ; then
    echo "Need at least BASH version 4 to run nodecheck tests or to Collect Inventory, Not running checks"
    exit 0
fi

# Global Vars
       # the bash syntax ${var-1} means: use var if set else use nothing  
[[ -z "${NOSM-}" ]] && declare NOSM="echo" #do nothing command
[[ -z "${host-}" ]] && declare host       #emulab hostname
[[ -z "${nodetype-}" ]] && declare nodetype       #emulab nodetype
[[ -z "${failed-}" ]] && declare failed=""  #major falure to be commicated to user
[[ -z "${os-}" ]] && declare os=""      #[Linux|FreeBSD] for now
[[ -z "${osrel-}" ]] && declare osrel="" #release major number
[[ -z "${todo_exit-}" ]] && declare -a todo_exit=('echo "Exit trap"')
[[ -z "${hwinv[hwinvidx]-}" ]] && declare -A hwinv["hwinvidx"]=""  # hwinv from tmcc
[[ -z "${hwinvcopy[hwinvidx]-}" ]] && declare -A hwinvcopy["hwinvidx"]=""  # a copy of hwinv from tmcc
[[ -z "${tmccinfo[hwinvidx]-}" ]] && declare -A tmccinfo["hwinvidx"]="" # info from tmcc hwinfo
[[ -z "${collect_flag-}" ]] && declare -i collect_flag # from tmcc hwinfo
[[ -z "${check_flag-}" ]] && declare -i check_flag # from tmcc hwinfo
[[ -z "${projdir-}" ]] && declare projdir # from tmcc hwinfo
[[ -z "${errexit_val-}" ]] && declare errexit_val # holding var for set values, ie -e
[[ -z "${mfsmode-}" ]] && declare -i mfsmode=0 #are we running in a MFS?
[[ -z "${bitsize-}" ]] && declare bitsize=""
[[ -z "${native_bitsize-}" ]] && declare -i native_bitsize=0 # what is our native binary bit size
[[ -z "${USE_DD-}" ]] && declare USE_DD="tdd" # if set which dd for the tdd program to use
[[ -z "${TDD_DD-}" ]] && declare TDD_DD="dd" # if set which dd for the tdd program to use

# PathNames
[[ -z "${logfile-}" ]] && declare logfile # output log
[[ -z "${logfile4tb-}" ]] && declare -r logfile4tb="/tmp/nodecheck.log.tb" # for data to saved in perm storage
[[ -z "${tmplog-}" ]] && declare -r tmplog="/tmp/.$$tmp.log"
[[ -z "${logout-}" ]] && declare -r logout="/tmp/.$$logout.log" # temperary logging while building inventory"
[[ -z "${tmpout-}" ]] && declare -r tmpout="/tmp/.$$tempout.log" # ditto

# DEBUG
[[ -z "${DEBUG-}" ]] && declare -ir DEBUG=0 # Some debugging if set

initialize () {
    #exit on unbound var
    set -u
    #exit on any error
    set -e

    #call only once
    if [ "${initdone-uninit}" != "uninit" ] ; then
    	(( $DEBUG )) && printf "Attempt to call twice %s:%s called from %s\n" $FUNCNAME $LINENO "$(caller)"
	return 0
    fi

    if [ -z "${BINDIR-""}" ] ; then 
	if [ -f "/etc/emulab/paths.sh" ]; then
	    source /etc/emulab/paths.sh
	    # XXX paths.sh resets PATH so we need to re-add any special bindir
	    ldir=`$BINDIR/tmcc hwinfo | grep LOGDIR= | \
                  sed -e 's/.*LOGDIR="\(.*\)".*/\1/'`
	    bdir=$ldir/`uname -s`/bin-`uname -m`
	    if [ -d $bdir ] ; then
		export PATH="$PATH:$bdir"
	    fi
	else
	    export BINDIR=/usr/local/etc/emulab
	    export LOGDIR=/var/tmp
	fi
    fi
    
    bitsize=$(uname -m)
    case $bitsize in
	i386 | x86 | i686 ) native_bitsize=32 ;;
	amd64 | x86_64 ) native_bitsize=64 ;;
	* ) native_bitsize=0 ;;
    esac

    if [ -f /etc/emulab/ismfs ] ; then
	mfsmode=1
	dd=$(whichdd2use)
	if [ "$dd" != "${dd/tdd}" ] ; then
	    USE_DD=$dd
	    TDD_DD=$(which dd)
	elif [ "$dd" != "${dd/bad}" ] ; then
	    USE_DD=$dd
	    TDD_DD=""
	else
	    USE_DD=$(which dd)
	    TDD_DD=""
	fi
    else
	mfsmode=0
	# no speed test don't have to check tdd, etc.
    fi

    inithostname
    initlogs $@
    inittestinfo

    #trap 'err_report $FUNCNAME:$LINENO' ERR
    trap 'err_report $LINENO' ERR

    initdone="done"
    export initdone
    return 0
}

# any command causes exit if -e option set
# including a grep just used so see if some string is in a file
# have a way to save current state and restore
save_e() {
    x=$-
    [[ "${x/e}" == "${x}" ]] &&	errexit_val=off || errexit_val=on
}
restore_e() {
    [[ $errexit_val == "on" ]] && set -e || set +e
}

# give some indication of exit on ERR trap
err_report() {
    echo "TRAP ERR at Caller Line $(caller)"
}


# read info from tmcc or a file. Copy into one of the three global arrays
# hwinv, hwinvcopy or tmccinfo
# $1 is the source $2 is the output array
# error if not both set
readtmcinfo() {
    local -A ref_hwinv
    local keyword
    local -i dcnt=0
    local -i ncnt=0
    local source output
    local rmtmp

    # what file to read from, if not set then make tmcc call
    source=${1+$1} # use $1 if set otherwise use nothing
    output=${2+$2} 
    if [ $# -ne 2 ] ; then
	printf "\n%s\n" "Script error missing arg source:|$source| output:|$output|"
	printf "Where %s:%s called from %s\n" $FUNCNAME $LINENO "$(caller)"
	exit 1
    fi

    if [ "$source" = "tmcc" ] ; then
	# need temp file to hold tmcc hwinv output
	rmtmp="y" # remove tmp file
	source=/tmp/.$$tmcchwinv
	$($BINDIR/tmcc hwinfo > $source)
	
	#special case because tmcc retuns us a extra nic
	if [[ ${nodetype} == "r320" && ${os} == "FreeBSD" ]] ; then
            oldd=$PWD
            cd /tmp
            head -8 $source > /tmp/.$$tmcc_head
            echo "NETINFO UNITS=3" >> /tmp/.$$tmcc_head
            head -10 $source | tail -1 >> /tmp/.$$tmcc_head
            tail -2 $source >> /tmp/.$$tmcc_head
            cat /tmp/.$$tmcc_head > $source
            rm /tmp/.$$tmcc_head
            cd $oldd
	fi
	
    else
	rmtmp=""
    fi

    # initalize output array
    if [ -z "${ref_hwinv["hwinvidx"]+${ref_hwinv["hwinvidx"]}}" ] ; then
	ref_hwinv["hwinvidx"]="" #start the array
    else
	# reset the array
	for i in ${ref_hwinv["hwinvidx"]} ; do
	    unset ref_hwinv[$i]
	done
	# hwinvidx is always expected to be set
	ref_hwinv["hwinvidx"]="" #restart the array
    fi

    # handle mult-line  input for disks and nets
    while read -r in ; do
	keyword=${in%% *}
	case $keyword in
	    DISKUNIT ) 
		keyword+="$dcnt"
		((++dcnt))
		;;
	    NETUNIT ) 
		keyword+="$ncnt"
		((++ncnt))
		;;
	    \#* ) continue ;; 
	esac
	ref_hwinv["hwinvidx"]+="$keyword " # keeping the keyword list preserves order
	ref_hwinv[$keyword]=$in
    done < $source
    [ -n "$rmtmp" ] && rm $source || : # the colon just stops a error being caught by -e

    case $output in 
	tmccinfo )
	    if [ -z "${tmccinfo["hwinvidx"]+${tmccinfo["hwinvidx"]}}" ] ; then
		tmccinfo["hwinvidx"]="" #start the array
	    else	
		for i in ${tmccinfo["hwinvidx"]} ; do
		    unset tmccinfo[$i]
		done
		tmccinfo["hwinvidx"]="" #restart the array
	    fi
	    tmccinfo["hwinvidx"]=${ref_hwinv["hwinvidx"]} 
	    for i in ${ref_hwinv["hwinvidx"]} ; do
		tmccinfo[$i]=${ref_hwinv[$i]}
	    done
	    ;;
	hwinv )
	    if [ -z "${hwinv["hwinvidx"]+${hwinv["hwinvidx"]}}" ] ; then
		hwinv["hwinvidx"]="" #start the array
	    else	
		for i in ${hwinv["hwinvidx"]} ; do
		    unset hwinv[$i]
		done
		hwinv["hwinvidx"]="" #restart the array
	    fi
	    hwinv["hwinvidx"]=${ref_hwinv["hwinvidx"]} 
	    for i in ${ref_hwinv["hwinvidx"]} ; do
		hwinv[$i]=${ref_hwinv[$i]}
	    done
	    ;;
	hwinvcopy )
	    if [ -z "${hwinvcopy["hwinvidx"]+${hwinvcopy["hwinvidx"]}}" ] ; then
		hwinvcopy["hwinvidx"]="" #start the array
	    else	
		for i in ${hwinvcopy["hwinvidx"]} ; do
		    unset hwinvcopy[$i]
		done
		hwinvcopy["hwinvidx"]="" #restart the array
	    fi
	    hwinvcopy["hwinvidx"]=${ref_hwinv["hwinvidx"]} 
	    for i in ${ref_hwinv["hwinvidx"]} ; do
		hwinvcopy[$i]=${ref_hwinv[$i]}
	    done
	    ;;
	* ) 
	    printf "\n%s\n" "Script error illegal output array |$output|"
	    printf "Where %s:%s called from %s\n" $FUNCNAME $LINENO "$(caller)"
	    exit 1
    esac
}

# copy assoctive array hwinv into hwinvcopy
# this is a little stupid but since I can't pass array I use globals
copytmcinfo () {
    # initalize array
    if [ -z "${hwinvcopy["hwinvidx"]+${hwinvcopy["hwinvidx"]}}" ] ; then
	hwinvcopy["hwinvidx"]="" #start the array
    else	
	for i in ${hwinvcopy["hwinvidx"]} ; do
	    unset hwinvcopy[$i]
	done
	hwinvcopy["hwinvidx"]="" #restart the array
    fi
    # copy index from old array
    hwinvcopy["hwinvidx"]=${hwinv["hwinvidx"]} 
    for i in ${hwinv["hwinvidx"]} ; do
	hwinvcopy[$i]=${hwinv[$i]}
    done
}

# compare arrays hwinv and copyhwinv arg1=outputfile
comparetmcinfo() {
    local fileout=$1
    # need to handle differing order with disks and nic addresses
    local localidx="${hwinv["hwinvidx"]}"
    local tbdbidx="${hwinvcopy["hwinvidx"]}"
    local localnics="" tbdbnics="" netunit=""
    local -i a b
    local x addr

    rm -f ${fileout} ${fileout}_local ${fileout}_tbdb ${fileout}_local_pre ${fileout}_tbdb_pre
    compareunits NET ${fileout}_local ${fileout}_tbdb
    compareunits DISK ${fileout}_local ${fileout}_tbdb

    # just tested, take NETUNIT out
    localidx=${localidx//NETUNIT[[:digit:]][[:digit:]]/}
    localidx=${localidx//NETUNIT[[:digit:]]/}
    tbdbidx=${tbdbidx//NETUNIT[[:digit:]][[:digit:]]/}
    tbdbidx=${tbdbidx//NETUNIT[[:digit:]]/}

    # just tested, take DISKUNIT out
    localidx=${localidx//DISKUNIT[[:digit:]][[:digit:]]/}
    localidx=${localidx//DISKUNIT[[:digit:]]/}
    tbdbidx=${tbdbidx//DISKUNIT[[:digit:]][[:digit:]]/}
    tbdbidx=${tbdbidx//DISKUNIT[[:digit:]]/}

    # take the TESTINFO line out 
    localidx=${localidx//TESTINFO/}
    tbdbidx=${localidx//TESTINFO/}

    # contact the two indexs then find get the uniq union
    arrayidx="$localidx $tbdbidx"
    arrayidx=$(uniqstr $arrayidx)

    # step through the local index, looking only for one copy
    for i in ${localidx} ; do
	# following bash syntax: "${a+$a}" says use $a if exists else use nothing
	if [ -z "${hwinvcopy[$i]+${hwinvcopy[$i]}}" ] ; then
	    # localidx has it - hwinvcopy does not
	    printf "%s\n" "${hwinv[$i]}" >> ${fileout}_local_pre
	    arrayidx=${arrayidx/$i} # nothing to compare with
	fi
    done
    # step through the testbed index, looking only for one copy
    for i in ${tbdbidx} ; do
	# following bash syntax: "${a+$a}" says use $a if exists else use nothing
	if [ -z "${hwinv[$i]+${hwinv[$i]}}" ] ; then
	    printf "%s\n" "${hwinvcopy[$i]}"  >> ${fileout}_tbdb_pre
	    arrayidx=${arrayidx/$i} 
	fi
    done

    #compare whats left
    for i in $arrayidx ; do
	if [ "${hwinv[$i]}" != "${hwinvcopy[$i]}" ] ; then
	    if [ ! -f $fileout ] ; then
		echo "Differences found locally compared with testbed database" >> $fileout
	    fi
	    echo "$i does not match" >> $fileout
	    echo "local ${hwinv[$i]}" >> $fileout
	    echo "tbdb ${hwinvcopy[$i]}" >> $fileout
	fi
    done

#ls -l ${fileout}_local ${fileout}_local_pre ${fileout}_tbdb_pre ${fileout}_tbdb 
    if [ -f ${fileout}_local -o -f ${fileout}_local_pre ] ; then
	printf "Only found in local search and not in testbed database\n" >> $fileout
	[[ -f ${fileout}_local_pre ]] && cat ${fileout}_local_pre >> ${fileout}
	[[ -f ${fileout}_local ]] && cat ${fileout}_local >> ${fileout}	
    fi
    if [ -f ${fileout}_tbdb -o -f ${fileout}_tbdb_pre ] ; then
	printf "In testbed database but not found in local search\n" >> $fileout
	[[ -f ${fileout}_tbdb_pre ]] && cat ${fileout}_tbdb_pre >> ${fileout}
	[[ -f ${fileout}_tbdb ]] && cat ${fileout}_tbdb >> ${fileout}
    fi

    rm -f ${fileout}_local ${fileout}_tbdb ${fileout}_local_pre ${fileout}_tbdb_pre

    return 0
}

# Compare multi-line units arg1=unittype arg2=localonlyfile arg3=tbdbonlyfile
compareunits() {
    local unittype=$1
    local localonly=$2
    local tbdbonly=$3
    local localidx="${hwinv["hwinvidx"]}"
    local tbdbidx="${hwinvcopy["hwinvidx"]}"
    local localunits="" tbdbunits="" devunit=""
    local -i a b disregard_order
    local x addr ckaddr

    # How are things different between unit types, only NET and DISK right now
    case $unittype in
	NET )
	    unitinfoidx_str="NETINFO"
	    unitinfo_strip="NETINFO UNITS="
	    unit_str="NETUNIT"
	    unit_pre_strip="*ID=\""
	    unit_post_strip="\"*"
	    unit_human_output="NIC"
	    unit_human_case="lower"
	    disregard_order=1
	    ;;
	DISK )
	    unitinfoidx_str="DISKINFO"
	    unitinfo_strip="DISKINFO UNITS="
	    unit_str="DISKUNIT"
	    unit_pre_strip="*SN=\""
	    unit_post_strip="\"*"
	    unit_human_output="DISK"
	    unit_human_case="upper"
	    disregard_order=1
	    ;;
	* )
	    echo "Error in compareunits don't now type $unittype. Giving up."
	    exit 1
	    ;;
    esac

    # Find the number of units in each list use biggest number for compare test
    if [ -n "${hwinv["${unitinfoidx_str}"]+${hwinv["${unitinfoidx_str}"]}}" ] ; then
	    x=${hwinv["${unitinfoidx_str}"]}
	    localcnt=${x/${unitinfo_strip}}
    else
	localcnt=0
    fi
    if [ -n "${hwinvcopy["${unitinfoidx_str}"]+${hwinvcopy["${unitinfoidx_str}"]}}" ] ; then
	x=${hwinvcopy["${unitinfoidx_str}"]}
	tbdbcnt=${x/${unitinfo_strip}}
    else
	tbdbcnt=0
    fi
    [[ $localcnt > $tbdbcnt ]] && maxunits=$localcnt || maxunits=$tbdbcnt 

    # here we are pulling out just the address/serialnumber from each array and saving it in a list
    for ((i=0; i<$maxunits; i++)) ; do
	# gather just the units addresses 
	devunit="${unit_str}${i}"
        # following bash syntax: "${a+$a}" says use $a if exists else use nothing
	if [ -n "${hwinv[$devunit]+${hwinv[$devunit]}}" ] ; then
	    ckaddr=${hwinv[$devunit]}
	    # add just the address/serialnumber
	    addr=${ckaddr#${unit_pre_strip}}
	    if [ "$ckaddr" != "$addr" ] ; then
		# make sure that we have removed the pre_strip
		# -- for example if a disk serial number is not removed cause we don't have it then we don't have anything to compare
		addr=${addr%%${unit_post_strip}}
		localunits+="$addr "
	    fi
	    localidx=${localidx/$devunit}
	fi
	if [ -n "${hwinvcopy[$devunit]+${hwinvcopy[$devunit]}}" ] ; then
	    ckaddr=${hwinvcopy[$devunit]}
	    addr=${ckaddr#${unit_pre_strip}}
	    if [ "$ckaddr" != "$addr" ] ; then
		addr=${addr%%${unit_post_strip}}
		tbdbunits+="$addr "
	    fi
	    tbdbidx=${tbdbidx/$devunit}
	fi
    done

    # Adjust the case in both strings to the case we want
    if [ "$unit_human_case" == "upper" ] ; then
	localunits=${localunits^^}
	tbdbunits=${tbdbunits^^}
    else
	localunits=${localunits,,}
	tbdbunits=${tbdbunits,,}
    fi

    if (( $disregard_order )) ; then
        # remove from both lists all words matched in the other list
        # any thing left-over is non-matching
	x=$localunits
	for i in $x ; do
	    if [ "${tbdbunits/$i}" != "${tbdbunits}" ]; then
	    # same, take it out of both lists
		tbdbunits=${tbdbunits/$i}
		localunits=${localunits/$i}
	    fi
	done
        # same but swap arrays
	x=$tbdbunits
	for i in $x ; do
	    if [ "${localunits/$i}" != "${localunits}" ]; then
		localunits=${localunits/$i}
		tbdbunits=${tbdbunits/$i}
	    fi
	done
#    elif [ $localcnt -eq $tbdbcnt ] ; then
#	# care about order, just remove in order matching entries
#	for i in $localcnt ; do  # does not matter which cnt used the are the same
#	    
#	done
    # else 
	# not the same number of devices. Don't match, do nothing.
    fi

    #remove extra spaces
    save_e
    set +e
    read -rd '' tbdbunits <<< "$tbdbunits"
    read -rd '' localunits <<< "$localunits"
    restore_e

    # if the two strings are the same then zero strings

    if (( $disregard_order )) ; then
	# early code removed all matching strings from the two lists
        # any leftover strings would be mismatches in ether localunits or tbdbunits
	if [ -n "${localunits}" ]; then
	    printf "%s%s %s\n" "${unit_human_output}" "s:" "$localunits"  >> $localonly
	fi
	if [ -n "${tbdbunits}" ]; then
	    printf "%s%s %s\n" "${unit_human_output}" "s:" "$tbdbunits" >> $tbdbonly
	fi
    else
	# care about order, first see if the two lists are the same.
	if [ "$tbdbunits" != "$localunits" ] ; then
	    # and we care about order report it
	    # NOTE: if !local or !tb then not out of order, extra local or in tb
	    [[ -z "${offline-}" ]] && declare -i offline=0 # if set from gen_sql
	    if [ "${localunits}" -a "${tbdbunits}" ] ; then
		(( ! $offline )) && printf "ERROR %s: OUT OF ORDER found %s from tbdb %s\n" "${unit_human_output}" "$localunits" "$tbdbunits" 
		(( ! $offline )) && ( printf "ERROR %s: OUT OF ORDER found local[%s] info from tbdb[%s]\n" "${unit_human_output}" "$localunits" "$tbdbunits" >> $fileout ) || ( printf "WARNING %s: ORDER ['%s'] compared to ['%s']\n" "${unit_human_output}" "$localunits" "$tbdbunits" >> $fileout )
	    else
		if [ -n "${localunits}" ]; then
		    printf "%s%s %s\n" "${unit_human_output}" "s:" "$localunits"  >> $localonly
		fi
		if [ -n "${tbdbunits}" ]; then
		    printf "%s%s %s\n" "${unit_human_output}" "s:" "$tbdbunits" >> $tbdbonly
		fi
		(( ! $offline )) && printf "ERROR %s MISSING found %s from tbdb %s\n" "${unit_human_output}" "s:" "$localunits" "$tbdbunits" 
		(( ! $offline )) && ( printf "ERROR %s MISSING found %s from tbdb %s\n" "${unit_human_output}" "$localunits" "$tbdbunits" >> $fileout ) || ( printf "WARNING MISSING %s%s ORDER '%s' compared to '%s'\n" "${unit_human_output}" "s:" "$localunits" "$tbdbunits" >> $fileout )
	    fi
	fi
    fi

    return 0
}


# take a string make the words in it uniq
uniqstr() {
    local instr="$@"
    local outstr=""
    for i in $instr ; do
	if [ "${outstr/$i}" ==  "$outstr" ] ; then
	    # $i not in outstr, add it
	    outstr+="$i "
	fi
    done
    echo $outstr
}

# print only the testbed data table
printtmcinfo() {
    local -i hdunits=0 nicunits=0
    for i in ${hwinv["hwinvidx"]} ; do
	case $i in 
	    CPUINFO ) printf "%s\n" "${hwinv[$i]}" ;;
	    MEMINFO ) printf "%s\n" "${hwinv[$i]}" ;;
	    DISKINFO ) 
		printf "%s\n" "${hwinv[$i]}" 
		x=${hwinv[$i]}
		hdunits=${x/#DISKINFO UNITS=/}

		# for HD need also check that we have a valid value
		# we collect more info then the testbed data base wants
		for ((n=0; n<$hdunits; n++)) ; do
		    # grab diskunitline
                    s=${hwinv[DISKUNIT$n]}
		    # turn space seperated string into array
		    unset -v d ; declare -a d=(${s// / })
		    numelm=${#d[*]}
		    echo -n "${d[0]} " #that is the word DISKUNIT
		    
		    for ((elm=1; elm<$numelm; elm++)) ; do
		        # must have form obj=value (where val can be blank) to work
			objval=${d[$elm]}
			[[ -z $objval ]] && continue  # that's bad no tupil
			obj=${objval%%=*}
			val=${objval##*=}
			[[ -z $val ]] && continue # bad also no value (or empty string)
			u=$val # orignal value
			[[ $u == ${u/UNKNOWN} ]] || continue # the value has the UNKNOWN value
			[[ $u == ${u/NoInfo} ]] || continue # the value has the NA
			[[ $u == ${u/LINUXNOT} ]] || continue # the value has the LinuxNot
			[[ $u == ${u/bad_} ]] || continue # has on of the bad_* strings
		        # out put the stuff the database wants
		        # skip the stuff the database does not want
			case $obj in
			    SN | TYPE | SECSIZE | SECTORS | WSPEED | RSPEED )
				echo -n "$objval " ;;
			esac
		    done
		    echo "" # end the line
		done
		;;
            NETINFO ) printf "%s\n" "${hwinv[$i]}" 
		x=${hwinv[$i]}
		nicunits=${x/#NETINFO UNITS=/}
		for ((i=0; i<$nicunits; i++)); do printf "%s\n" "${hwinv[NETUNIT$i]}"; done ;;
	esac
    done
}

# print all hwinv
printhwinv() {
    for i in ${hwinv["hwinvidx"]} ; do
	printf "%s\n" "${hwinv[$i]}"
    done
}

# which is not in busybox and not a bash builtin
which() {
    if [ -x /usr/bin/which ] ; then
	# have real which, use it
	/usr/bin/which $@
	return 0
    else
	mypath=$PATH
	mypath=${mypath//:/ }
	for i in $mypath ; do
	    if [ -e $i/$1 ] ; then
		echo $i/$1
		return 0
	    fi
	done
    fi
}

inithostname() {
    os=$(uname -s)
    if [ -z $os ] ; then
	echo "ERROR uname messed up"
	exit 1
    fi
    osrel=`uname -r | sed 's/^\([0-9][0-9]*\)\..*/\1/'`
    if [ -e "$BINDIR/tmcc" ] ; then
	host=$($BINDIR/tmcc nodeid)
        nodetype=$($BINDIR/tmcc nodetype)
    else
	echo "WARN no $BINDIR/tmcc command for nodeid"
	# maybe its just time to give up
	if [ -e "${BOOTDIR}/realname" ] ; then
	    host=$(cat $BOOTDIR/realname)
	elif [ -e "$BOOTDIR/nodeid" ] ; then
	    host=$(cat $BOOTDIR/nodeid)
	else
	    host=$(hostname)
	fi
    fi
    return 0
}

findSmartctl() {
    local findit=$(which smartctl)
    if [ "$os" == "FreeBSD" ] ; then
	findit=$(which smartctl$osrel)
	if [ -z "${findit}" ] ; then
	    if [ -x "/usr/local/sbin/smartctl" ]; then
		findit="/usr/local/sbin/smartctl"
	    else
		findit=$NOSM
	    fi
	fi
    fi	
    echo $findit
    return 0
}
findSmartctl_getopt() {
    local smrtctl=$(findSmartctl)
    if [ "${smrtctl/smartctl}" != "$smrtctl" ] ; then
        # check functionally
	x=$($smrtctl --get | grep REQUIRED)
	[[ -z "$x" ]] && smrtctl=$NOSM
    fi
    
    echo $smrtctl
    return 0
}

findMfiutil() {
    local findit=""
    if [ "$os" == "FreeBSD" ] ; then
	findit=$(which mfiutil)
	if [ -z "${findit}" ]; then
	    findit=$(which mfiutil$osrel)
	fi
    fi
    echo $findit
    return 0
}

# Array of command to be run at exit time
on_exit() {
#  (( $DEBUG )) && echo "EXIT on_exit $(caller)"
    for i in "${todo_exit[@]}" ; do
        $($i)
    done
    return 0
}

add_on_exit() {
    local -i nex=${#todo_exit[*]}
    todo_exit[$nex]="$@"
    if [[ $nex -eq 0 ]]; then
        trap on_exit EXIT
    fi
    return 0
}

# setup logging $1 is local log file if not set default to /tmp file
# $2 is the collect file, if not set then no collection is done
initlogs () {
    #call only once
    if [ "${initlogdone-notdone}" != "notdone" ] ; then
    	(( $DEBUG )) && printf "Attempt to call twice %s:%s called from %s\n" $FUNCNAME $LINENO "$(caller)"
	return 0
    fi

    # the following bash syntax lets us test ifa  positional arg is set
    # before we try and use it
    # needed if running with -u set. 
    # It means use $1 if set else use a default path
    logfile=${1-"/tmp/nodecheck.log"}

    # need to have inittestinfo run, help programmer out
    [[ "${collect_flag-undef}" = "undef" ]] && inittestinfo

    # this file is only used in gather mode
    # set the name so it can be tested for
    (( $collect_flag )) && { cat /dev/null > $logfile4tb ; add_on_exit "rm -f $logfile4tb" ; }

    cat /dev/null > ${tmplog} # create and truncate
    add_on_exit "rm -f $tmplog"

    cp /dev/null ${logout} # make it exist
    add_on_exit "rm -f $logout"
    
    cp /dev/null ${tmpout}
    add_on_exit "rm -f $tmpout"

    initlogdone="done"
    export initlogdone
    return 0
}

inittestinfo () {
    local testinfo
    #call only once
    if [ "${inittestdone-notdone}" != "notdone" ] ; then
    	(( $DEBUG )) && printf "Attempt to call twice %s:%s called from %s\n" $FUNCNAME $LINENO "$(caller)"
	return 0
    fi

    # if tmccinfo array not set then read it in
    [[ -z "${tmccinfo["hwinvidx"]+${tmccinfo["hwinvidx"]}}" ]] && readtmcinfo tmcc tmccinfo
    testinfo=${tmccinfo["TESTINFO"]}
    collect_flag=$(echo $testinfo | awk -F = '{print $3}' | awk '{print $1}')
    check_flag=$(echo $testinfo | awk -F = '{print $4}')
    (( $collect_flag )) && projdir=$(echo $testinfo | awk -F \" '{print $2}') || projdir=""
    [[ "${projdir:0:1}" != '/' ]] && ( printf "%s():collect is set but invaild path given |%s|" $FUNCNAME $projdir ;  exit 1 )

    inittestdone="done"
    export inittestdone
    return 0
}
    

getdrivenames() {
    # use smartctl if exits
    # use scan of disk devices
    # use / 
    # truncate all together and then make uniq

    local os=$(uname -s)
    local sm=$(findSmartctl)
    local drivelist=""
    local drives="" 
    local x elm

#    if [ "$sm" != "${sm/smartctl}" ] ; then
#	x=$($sm --scan-open | awk '{print $1}')
#	if [ "$x" != "${x/dev}" ] ; then
#	    for elm in $x ; do
#		x=${x/"/dev/pass2"/} # FreeBSD not a HD, Tape?
#		drivelist+="$x "
#	    done
#	fi
#    fi


    case $os in
	Linux )
	    list="a b c d e f g h i j k l m n o p q r s t u v w x y z aa ab ac ad ae af ai ag ah ai aj ak al am an ao ap aq ar as at au av aw"
	    for i in $list
	    do
		if [ -b /dev/sd${i} ] ; then
		    drivelist+="/dev/sd${i} "
		fi
	    done
	    ;;
	FreeBSD )
	    list="0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49"
	    for i in $list
	    do
		[[ ! -L /dev/ad${i} ]] &&  [[ -c /dev/ad${i} ]] && drivelist+="/dev/ad${i} "
		[[ -c /dev/ada${i} ]] && drivelist+="/dev/ada${i} "
		[[ -c /dev/da${i} ]] && drivelist+="/dev/da${i} " 
		[[ -c /dev/ar${i} ]] && drivelist+="/dev/ar${i} " 
		[[ -c /dev/aacd${i} ]] && drivelist+="/dev/aacd${i} " 
		[[ -c /dev/amrd${i} ]] && drivelist+="/dev/amrd${i} " 
		[[ -c /dev/mfid${i} ]] && drivelist+="/dev/mfid${i} " 
		[[ -c /dev/mfisyspd${i} ]] && drivelist+="/dev/mfisyspd${i} " 
		# XXX smartctl uses nvme names for nvd disk devices
		[[ -c /dev/nvd${i} ]] && drivelist+="/dev/nvme${i} " 
	    done
	    ;;
	* )
	    echo "${FUNCNAME[0]}:${LINENO} Internal error"
	    exit
	    ;;
    esac

    echo $drivelist
    return 0
}

# return the requested hwinfo 
# $1 is the type
getfromtb() {
    local info=$1
    local -i units=0
    
    case $info in
	TESTINFO | CPUINFO )
            # make sure that tmccinfo does have the info requested.
	    [[ -z "${tmccinfo[$info]+${tmccinfo[$info]}}" ]] && return 0
	    # take off the info
	    s=${tmccinfo[$info]}
	    s=${s/$info }
	    printf "%s" "$s"
	    ;;
	NETINFO | DISKINFO )
	    [[ -z "${tmccinfo[$info]+${tmccinfo[$info]}}" ]] && return 0
	    s=${tmccinfo[$info]}
	    s=${s//=/}
	    s=${s/UNITS}
	    s=${s/$info }
	    printf "%s" "$s"
	    ;;
	MEMINFO )
	    [[ -z "${tmccinfo[$info]+${tmccinfo[$info]}}" ]] && return 0
	    s=${tmccinfo[$info]}
	    s=${s/$info SIZE=}
	     printf "%s" "$s"
	     ;;
	DISKUNIT )
	    [[ -z "${tmccinfo[${info}0]+${tmccinfo[${info}0]}}" ]] && return 0
	    # only returning serial numbers
	    x=${tmccinfo["DISKINFO"]}
	    units=${x/#DISKINFO UNITS=/}
	    for ((n=0; n<$units; n++)) ; do
		s=${tmccinfo[DISKUNIT$n]}
		    # turn space seperated string into array
		unset -v d ; declare -a d=(${s// / })
		numelm=${#d[*]}
		for ((elm=1; elm<$numelm; elm++)) ; do
		    objval=${d[$elm]}
		    [[ -z $objval ]] && continue  # that's bad no tupil
		    obj=${objval%%=*}
		    val=${objval##*=}
		    [[ -z $val ]] && continue # bad also no value (or empty s
		    if [ "$obj" = "SN" ] ;  then
			val=${val//=/}
			val=${val//\"/}
			printf "%s " "$val"
		    fi
		done
	    done
	    ;;
	NETUNIT )
	    [[ -z "${tmccinfo[${info}0]+${tmccinfo[${info}0]}}" ]] && return 0
	    # only return ID
	    x=${tmccinfo["NETINFO"]}
	    units=${x/#NETINFO UNITS=/}
	    for ((i=0; i<$units; i++)) ; do
		s=${tmccinfo[NETUNIT$i]}
		unset -v d ; declare -a d=(${s// / })
		numelm=${#d[*]}
		for ((elm=1; elm<$numelm; elm++)) ; do
		    objval=${d[$elm]}
		    [[ -z $objval ]] && continue  # that's bad no tupil
		    obj=${objval%%=*}
		    val=${objval##*=}
		    [[ -z $val ]] && continue # bad also no value (or empty s
		    if [ "$obj" = "ID" ] ;  then
			val=${val//=/}
			val=${val//\"/}
			printf "%s " "$val"
		    fi
		done
	    done
	    ;;
	* ) printf "ibinfo what is this in my case statment |%s|\n" "$info" ; exit 1
	    ;;
    esac
    return 0
}

whichdd2use() {
    local usetdd
    local canwe
    local -i bad64=0
    

    workhorsedd=$(which dd)
    canwe=$(ls -l $workhorsedd | grep busybox)
    [[ $canwe ]] && { echo "bad_busybox_dd"; return 0; }

    # if we have a timed dd, use a timeout rather than a count
    usetdd=$(which tdd)
    [[ -x $usetdd ]] && { USE_DD=$usetdd; TDD_DD=$workhorsedd; usedd=$usetdd; }
    # check compatabily, ok to have 32bit on 64bit machine
    if [ $native_bitsize -ne 64 ] ; then
	# check directory name of where the exectuable is installed
	# if not 32 or not 64 then assume native binary and is ok
	if [ "$workhorsedd" != "${workhorsedd/64}" ] ; then # it has 64 in path
	    bad64=1
	fi
	# and check tdd if we are using it
	if [ "${USE_DD}" != "${USE_DD/tdd}" ] ; then
	    if [ "$USE_DD" != "${USE_DD/64}" ] ; then
		bad64=1
	    fi
	fi
	if [ $bad64 -eq 1 ] ; then
	    echo "bad_64bit_dd_on_32bit_machine"
	    return 0
	fi
    fi
    echo "$usedd"

    return 0
}

# call whichdd2use() before this to use correctly
ddargs() {
    local args=""
    if [ "$os" == "Linux" ] ; then 
	#args="bs=64k iflag=direct count=8000"
	#note iflag direct can't be used with /dev/zero as infile 
	args="bs=64k"
    elif [ "$os" == "FreeBSD" ] ; then 
	args="bs=64k"
    fi

    if [ "$USE_DD" != "${USE_DD/tdd}" ] ; then
	# if we have a timed dd, use a timeout rather than a count
	args="$args timeout=5 count=20000" # XXX paranoid: leave a count just in case
    else
	args="$args count=8000"
    fi
	
    echo "$args"
    return 0
}

# The timesys function terminates its script unless it terminates earlier on its own
# args: max_time output_file command command_args
# does not work....
timesys() {
    maxtime="$1"; shift;
    out="$1" ; shift;
    command="$1"; shift;
    args="$*"
    me_pid=$$;
    sleep $maxtime &
    timer_pid=$!
{
    $command $args &
    command_pid=$!
    wait ${timer_pid}
    siglist="2 15 9"
    for i in $siglist ; do
	running=$(ps -a | grep $command_pid | grep dd)
	[[ "$running" ]] || break
	kill -${i} ${command_pid}
    done
} > $out 2>&1
}

return 0
