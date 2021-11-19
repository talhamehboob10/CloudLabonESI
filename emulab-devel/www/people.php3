<?php
#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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
require("defs.php3");

#
# Standard Testbed Header
#
PAGEHEADER("People Power");

function FLUXPERSON($login, $name) {
    echo "<li> <a href=\"http://www.cs.utah.edu/~$login\">$name</a>\n";
}

function PARTFLUXPERSON($login, $name, $where) {
    echo "<li> <a href=\"http://www.cs.utah.edu/~$login\">$name</a> ($where)\n";
}

function EXFLUXPERSON($url, $name, $where) {
    echo "<li> <a href=\"$url\">$name</a> ($where)\n";
}

function MAILPERSON($login, $name) {
    echo "<li> <a href=\"mailto:$login\">$name</a>\n";
}

echo "<h3>Faculty:</h3>\n";
echo "<ul>\n";
FLUXPERSON("lepreau", "Jay Lepreau");
echo "</ul>\n";

echo "<h3>Students and Staff:</h3>\n";
echo "<ul>\n";
PARTFLUXPERSON("calfeld", "Chris Alfeld", "Univ. Wisconsin");
FLUXPERSON("saggarwa", "Siddharth Aggarwal");
FLUXPERSON("vaibhave", "Vaibhave Agarwal");
PARTFLUXPERSON("danderse", "David G. Andersen", "MIT");
FLUXPERSON("davidand", "David S. Anderson");
FLUXPERSON("rchriste", "Russ Christensen");
FLUXPERSON("aclement", "Austin Clements");
FLUXPERSON("duerig", "Jonathon Duerig");
FLUXPERSON("eeide", "Eric Eide");
FLUXPERSON("fish", "Russ Fish");
FLUXPERSON("shash", "Shashi Guruprasad");
FLUXPERSON("mike", "Mike Hibler");
FLUXPERSON("johnsond", "David Johnson");
MAILPERSON("rolke@gmx.net", "Roland Kempter");
FLUXPERSON("newbold", "Mac Newbold");
FLUXPERSON("ricci", "Robert Ricci");
FLUXPERSON("stack", "Tim Stack");
FLUXPERSON("stoller", "Leigh Stoller");
FLUXPERSON("kwebb", "Kirk Webb");
echo "</ul>\n";

echo "<h3>Alumni:</h3>\n";
echo "<ul>\n";
PARTFLUXPERSON("barb", "Chad Barb", "Infinity Ward (Activision)");
PARTFLUXPERSON("sclawson", "Steve Clawson", "Alcatel");
PARTFLUXPERSON("abhijeet", "Abhijeet Joglekar", "Intel");
PARTFLUXPERSON("ikumar", "Indrajeet Kumar", "Qualcomm");
PARTFLUXPERSON("longmore", "Henry Longmore", "");
PARTFLUXPERSON("vanmaren", "Kevin Van Maren", "Unisys");
EXFLUXPERSON("http://ianmurdock.com/", "Ian Murdock", "Progeny");
EXFLUXPERSON("http://www.csl.cornell.edu/~bwhite/", "Brian White", "Cornell");
# Some consulting for UCB; don't know how much.
FLUXPERSON("kwright", "Kristin Wright");
echo "</ul>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
