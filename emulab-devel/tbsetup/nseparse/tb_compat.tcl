# -*- tcl -*-
#
# Copyright (c) 2000-2004, 2009 University of Utah and the Flux Group.
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

# This is a nop tb_compact.tcl file that should be used when running scripts
# under ns.

proc tb-set-ip {node ip} {}
proc tb-set-ip-interface {src dst ip} {}
proc tb-set-ip-link {src link ip} {}
proc tb-set-ip-lan {src lan ip} {}
proc tb-set-hardware {node type args} {}
proc tb-set-node-os {node os {parentos 0}} {}
proc tb-set-link-loss {src args} {}
proc tb-set-lan-loss {lan rate} {}
proc tb-set-node-rpms {node args} {}
proc tb-set-node-startup {node cmd} {}
proc tb-set-node-cmdline {node cmd} {}
proc tb-set-node-tarfiles {node args} {}
proc tb-set-node-lan-delay {node lan delay} {}
proc tb-set-node-lan-bandwidth {node lan bw} {}
proc tb-set-node-lan-loss {node lan loss} {}
proc tb-set-node-lan-params {node lan delay bw loss} {}
proc tb-set-node-failure-action {node type} {}
proc tb-set-ip-routing {type} {}
proc tb-fix-node {v p} {}
proc tb-make-weighted-vtype {name weight types} {}
proc tb-make-soft-vtype {name types} {}
proc tb-make-hard-vtype {name types} {}
proc tb-set-lan-simplex-params {lan node todelay tobw toloss fromdelay frombw fromloss} {}
proc tb-set-link-simplex-params {link src delay bw loss} {}
proc tb-set-uselatestwadata {onoff} {}
proc tb-set-usewatunnels {onoff} {}
proc tb-set-wasolver-weights {delay bw plr} {}
proc tb-use-endnodeshaping {onoff} {}
proc tb-force-endnodeshaping {onoff} {}
proc tb-set-multiplexed {link onoff} {}
proc tb-set-endnodeshaping {link onoff} {}
proc tb-set-noshaping {link onoff} {}
proc tb-set-useveth {link onoff} {}
proc tb-set-allowcolocate {lanlink onoff} {}
proc tb-set-colocate-factor {factor} {}
proc tb-set-node-startcmd {node cmd} {}
proc tb-set-encapsulate {onoff} {}
proc tb-set-jail-os {os} {}
proc tb-set-delay-os {os} {}
proc tb-use-ipassign {onoff} {}
proc tb-set-ipassign-args {args} {}
proc tb-set-lan-protocol {lanlink protocol} {}
proc tb-set-lan-accesspoint {lanlink node} {}
proc tb-set-lan-setting {lanlink capkey capval} {}
proc tb-set-node-lan-setting {lanlink node capkey capval} {}
proc tb-set-node-routable-ip {node onoff} {}

Class Program

Program instproc init {args} {
}

Program instproc unknown {m args} {
}

# We are just syntax checking the NS file
Simulator instproc run {args} {
}

Simulator instproc nsenode {args} {
    return [new NSENode]
}

Simulator instproc make-simulated {args} {
    uplevel 1 eval $args
}
