/*
 * Copyright (c) 2008-2013 University of Utah and the Flux Group.
 * 
 * {{{GENIPUBLIC-LICENSE
 * 
 * GENI Public License
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and/or hardware specification (the "Work") to
 * deal in the Work without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Work, and to permit persons to whom the Work
 * is furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Work.
 * 
 * THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
 * IN THE WORK.
 * 
 * }}}
 */

package com.flack.geni.plugins.planetlab
{
	import com.flack.geni.plugins.Plugin;
	import com.flack.geni.plugins.PluginArea;
	import com.flack.geni.resources.SliverTypes;
	
	public class Planetlab implements Plugin
	{
		public function get Title():String { return "Planetlab" };
		public function get Area():PluginArea { return null; };
		
		public function Planetlab()
		{
			super();
		}
		
		public function init():void
		{
			SliverTypes.addSliverTypeInterface(PlanetlabSliverType.TYPE_PLANETLAB_V1, new PlanetlabSliverType());
			SliverTypes.addSliverTypeInterface(PlanetlabSliverType.TYPE_PLANETLAB_V2, new PlanetlabSliverType());
			SliverTypes.addSliverTypeInterface(M1TinySliverType.TYPE_M1TINY, new M1TinySliverType());
			SliverTypes.addSliverTypeInterface(M1SmallSliverType.TYPE_M1SMALL, new M1SmallSliverType());
			SliverTypes.addSliverTypeInterface(M1MediumSliverType.TYPE_M1MEDIUM, new M1MediumSliverType());
			SliverTypes.addSliverTypeInterface(M1LargeSliverType.TYPE_M1LARGE, new M1LargeSliverType());
			SliverTypes.addSliverTypeInterface(M1XLargeSliverType.TYPE_M1XLARGE, new M1XLargeSliverType());
			SliverTypes.addSliverTypeInterface(M1WorkerSliverType.TYPE_M1WORKER, new M1WorkerSliverType());
		}
	}
}