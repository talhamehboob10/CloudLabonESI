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

package com.flack.geni.resources.sites.managers
{
	import com.flack.geni.plugins.emulab.DelaySliverType;
	import com.flack.geni.plugins.emulab.EmulabBbgSliverType;
	import com.flack.geni.plugins.emulab.EmulabOpenVzSliverType;
        import com.flack.geni.plugins.emulab.EmulabXenSliverType;
	import com.flack.geni.plugins.emulab.EmulabSppSliverType;
	import com.flack.geni.plugins.emulab.FirewallSliverType;
	import com.flack.geni.plugins.emulab.Netfpga2SliverType;
	import com.flack.geni.plugins.emulab.RawPcSliverType;
	import com.flack.geni.plugins.planetlab.M1LargeSliverType;
	import com.flack.geni.plugins.planetlab.M1MediumSliverType;
	import com.flack.geni.plugins.planetlab.M1SmallSliverType;
	import com.flack.geni.plugins.planetlab.M1TinySliverType;
	import com.flack.geni.plugins.planetlab.M1WorkerSliverType;
	import com.flack.geni.plugins.planetlab.M1XLargeSliverType;
	import com.flack.geni.plugins.planetlab.PlanetlabSliverType;
	import com.flack.geni.plugins.shadownet.JuniperRouterSliverType;
	import com.flack.geni.resources.SliverType;
	import com.flack.geni.resources.SliverTypes;
	import com.flack.geni.resources.virt.LinkType;
	import com.flack.shared.resources.docs.RspecVersion;

	public class SupportedSliverType
	{
		public var type:SliverType;
		public var supportsExclusive:Boolean = true;
		public var supportsShared:Boolean = true;
		public var defaultExclusiveSetting:Boolean = true;
		public var supportsBound:Boolean = true;
		public var supportsUnbound:Boolean = true;
		public var supportsInterfaces:Boolean = true;
		public var interfacesUnadvertised:Boolean = false;
		public var supportsDiskImage:Boolean = true;
		public var supportsInstallService:Boolean = true;
		public var supportsExecuteService:Boolean = true;
		public var limitToLinkType:String = "";
		
		// TODO(mstrum): This needs to go away. Push all of these sliver type
		// configurations into their respective plugins.
		public function SupportedSliverType(newName:String)
		{
			type = new SliverType(newName);
			switch(type.name)
			{
				case M1TinySliverType.TYPE_M1TINY:
				case M1SmallSliverType.TYPE_M1SMALL:
				case M1MediumSliverType.TYPE_M1MEDIUM:
				case M1LargeSliverType.TYPE_M1LARGE:
				case M1XLargeSliverType.TYPE_M1XLARGE:
				case M1WorkerSliverType.TYPE_M1WORKER:
					supportsExclusive = false;
					defaultExclusiveSetting = false;
					interfacesUnadvertised = true;
					supportsInstallService = false;
					supportsExecuteService = false;
					break;
				case PlanetlabSliverType.TYPE_PLANETLAB_V1:
				case PlanetlabSliverType.TYPE_PLANETLAB_V2:
				case JuniperRouterSliverType.TYPE_JUNIPER_LROUTER:
					supportsExclusive = false;
					defaultExclusiveSetting = false;
					supportsUnbound = false;
					interfacesUnadvertised = true;
					supportsDiskImage = false;
					supportsInstallService = false;
					supportsExecuteService = false;
					break;
				case EmulabBbgSliverType.TYPE_EMULAB_BBG:
					supportsUnbound = false;
					interfacesUnadvertised = true;
					limitToLinkType = LinkType.VLAN;
					supportsDiskImage = false;
					supportsInstallService = false;
					supportsExecuteService = false;
					break;
				case EmulabSppSliverType.TYPE_EMULAB_SPP:
					supportsUnbound = false;
					supportsDiskImage = false;
					supportsInstallService = false;
					supportsExecuteService = false;
					break;
				case "openflow-switch":
					supportsExclusive = false;
					supportsShared = false;
					supportsBound = false;
					supportsUnbound = false;
					supportsDiskImage = false;
					supportsInstallService = false;
					supportsExecuteService = false;
					break;
				case FirewallSliverType.TYPE_FIREWALL:
				case DelaySliverType.TYPE_DELAY:
					supportsShared = false;
					supportsDiskImage = false;
					supportsInstallService = false;
					supportsExecuteService = false;
					break;
				case RawPcSliverType.TYPE_RAWPC_V1:
				case RawPcSliverType.TYPE_RAWPC_V2:
					supportsShared = false;
					break;
				case Netfpga2SliverType.TYPE_NETFPGA2:
					supportsUnbound = false;
					supportsShared = false;
					supportsDiskImage = false;
					supportsInstallService = false;
					supportsExecuteService = false;
					break;
				case SliverTypes.XEN_VM:
				case SliverTypes.QEMUPC:
					supportsDiskImage = false;
				case EmulabOpenVzSliverType.TYPE_EMULABOPENVZ:
                                case EmulabXenSliverType.TYPE_EMULABXEN:
				  defaultExclusiveSetting = false;
				default:
			}
		}
	}
}
