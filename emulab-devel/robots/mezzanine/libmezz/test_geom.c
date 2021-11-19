/*
 * Copyright (c) 2005 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 */

// test_geom.c - Light testing of the geom.[hc] code.

#include <stdio.h>
#include "geom.h"

int main(int argc, char** argv)
{
  geomLineObj lo, *l = &lo;
  geomPt p1 = {-1,0}, p2 = {0,1};
  geomPt p3 = {0,0}, p4 = {1,1}, p5 = {-1,1};

  initGeomLine(p1, p2, l);
  printf("l is "); prGeomLine(l);
  printf("signedDist(l, (0,0)) is %g, should be .707\n", signedDist(l, p3));
  printf("signedDist(l, (1,1)) is %g, should be .707\n", signedDist(l, p4));
  printf("signedDist(l, (-1,1)) is %g, should be -.707\n", signedDist(l, p5));

  return 0;
}
