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

package com.flack.geni.plugins.emulab
{
	import com.flack.geni.plugins.Plugin;
	import com.flack.geni.plugins.PluginArea;
	import com.flack.geni.resources.SliverTypes;
	
	public class Emulab implements Plugin
	{
		public function get Title():String { return "Emulab" };
		public function get Area():PluginArea { return new EmulabArea(); };
		
		public function Emulab()
		{
			super();
		}
		
		public function init():void
		{
			SliverTypes.addSliverTypeInterface(DelaySliverType.TYPE_DELAY, new DelaySliverType());
			SliverTypes.addSliverTypeInterface(FirewallSliverType.TYPE_FIREWALL, new FirewallSliverType());
			SliverTypes.addSliverTypeInterface(RawPcSliverType.TYPE_RAWPC_V1, new RawPcSliverType());
			SliverTypes.addSliverTypeInterface(RawPcSliverType.TYPE_RAWPC_V2, new RawPcSliverType());
			SliverTypes.addSliverTypeInterface(EmulabOpenVzSliverType.TYPE_EMULABOPENVZ, new EmulabOpenVzSliverType());
                        SliverTypes.addSliverTypeInterface(EmulabXenSliverType.TYPE_EMULABXEN, new EmulabXenSliverType());
			SliverTypes.addSliverTypeInterface(EmulabBbgSliverType.TYPE_EMULAB_BBG, new EmulabBbgSliverType());
			SliverTypes.addSliverTypeInterface(EmulabSppSliverType.TYPE_EMULAB_SPP, new EmulabSppSliverType());
			SliverTypes.addSliverTypeInterface(Netfpga2SliverType.TYPE_NETFPGA2, new Netfpga2SliverType());
		}
	}
}