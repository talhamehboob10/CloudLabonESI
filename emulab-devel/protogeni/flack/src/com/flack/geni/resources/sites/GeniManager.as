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

package com.flack.geni.resources.sites
{
	import com.flack.geni.resources.docs.GeniCredentialVersionCollection;
	import com.flack.geni.resources.physical.PhysicalLink;
	import com.flack.geni.resources.physical.PhysicalLinkCollection;
	import com.flack.geni.resources.physical.PhysicalLocationCollection;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.physical.PhysicalNodeCollection;
	import com.flack.geni.resources.sites.managers.ExternalRefCollection;
	import com.flack.geni.resources.sites.managers.SupportedLinkTypeCollection;
	import com.flack.geni.resources.sites.managers.SupportedSliverTypeCollection;
	import com.flack.geni.resources.sites.managers.opstates.OpStateCollection;
	import com.flack.geni.resources.virt.extensions.stitching.AdvertisedStitching;
	import com.flack.shared.resources.docs.RspecVersion;
	import com.flack.shared.resources.docs.RspecVersionCollection;
	import com.flack.shared.resources.sites.ApiDetails;
	import com.flack.shared.resources.sites.FlackManager;
	import com.flack.shared.utils.StringUtil;
	
	/**
	 * Manager within the GENI world
	 * 
	 * @author mstrum
	 * 
	 */
	public class GeniManager extends FlackManager
	{
		public static const ALLOCATE_SINGLE:String = "geni_single";
		public static const ALLOCATE_DISJOINT:String = "geni_disjoint";
		public static const ALLOCATE_MANY:String = "geni_many";
		public static function allocateToHumanReadableString(allocate:String):String
		{
			switch(allocate)
			{
				case ALLOCATE_SINGLE:
					return "Single";
				case ALLOCATE_DISJOINT:
					return "Disjoint";
				case ALLOCATE_MANY:
					return "Many";
				default:
					return allocate;
			}
		}
				
		// Advertised Resources
		[Bindable]
		public var nodes:PhysicalNodeCollection;
		[Bindable]
		public var links:PhysicalLinkCollection;
		
		public var sharedVlans:Vector.<String> = null;
		
		public var opStates:OpStateCollection = new OpStateCollection();
		
		public var stitching:AdvertisedStitching;

		public var externalRefs:ExternalRefCollection = new ExternalRefCollection();
		
		// Support Information
		public var inputRspecVersions:RspecVersionCollection = new RspecVersionCollection();
		[Bindable]
		public var inputRspecVersion:RspecVersion = null;
		
		public var outputRspecVersions:RspecVersionCollection = new RspecVersionCollection();
		[Bindable]
		public var outputRspecVersion:RspecVersion = null;
		
		public var supportedSliverTypes:SupportedSliverTypeCollection = new SupportedSliverTypeCollection();
		public var supportedLinkTypes:SupportedLinkTypeCollection = new SupportedLinkTypeCollection();
		public function get SupportsLinks():Boolean
		{
			return supportedLinkTypes.length > 0;
		}
		
		public var credentialTypes:GeniCredentialVersionCollection = new GeniCredentialVersionCollection();
		
		public var locations:PhysicalLocationCollection;

		public var singleAllocation:Boolean = false;
		public var allocate:String = ALLOCATE_SINGLE;
		
		public var codeVersion:String = "";
		public var type:String;
		public var types:Vector.<String> = new Vector.<String>();
		
		public static const TYPE_ORCA:String = "orca";
		public static const TYPE_FOAM:String = "foam";
		public static const TYPE_PROTOGENI:String = "protogeni";
		public static const TYPE_SFA:String = "sfa";
		public static const TYPE_DCN:String = "dcn";
		public static const TYPE_UNKNOWN:String = "";
		public static function typeToHumanReadable(type:String):String
		{
			switch(type)
			{
				case TYPE_PROTOGENI:
					return "ProtoGENI";
				case TYPE_SFA:
					return "SFA";
				case TYPE_FOAM:
					return "FOAM";
				case TYPE_ORCA:
					return "ORCA";
				case TYPE_DCN:
					return "DCN";
				case TYPE_UNKNOWN:
					return "Unknown";
				default:
					return StringUtil.firstToUpper(type);
			}
		}
		
		/**
		 * 
		 * @param newType Type
		 * @param newApi API type
		 * @param newId IDN-URN
		 * @param newHrn Human-readable name
		 * 
		 */
		public function GeniManager(newType:String = TYPE_UNKNOWN,
									newApi:int = ApiDetails.API_GENIAM,
									newId:String = "",
									newHrn:String = "")
		{
			super(
				newApi,
				newId,
				newHrn
			);
			
			type = newType;
			
			resetComponents();
		}
		
		/**
		 * Clears components, the advertisement, status, and error details
		 * 
		 */
		override public function clear():void
		{
			resetComponents();
			super.clear();
		}
		
		/**
		 * Clears nodes, links, sliver types, and locations
		 * 
		 */
		public function resetComponents():void
		{
			nodes = new PhysicalNodeCollection();
			links = new PhysicalLinkCollection();
			locations = new PhysicalLocationCollection();
			stitching = new AdvertisedStitching();
		}
		
		/**
		 * Sets the API type to use. This can be overriden to, for example,
		 * set the URL based on the api type.
		 * 
		 * @param type Details for the API to use.
		 * 
		 */
		public function setApi(details:ApiDetails):void
		{
			api = details;
			if(details.url.length == 0)
			{
				api.url = url;
				if(api.type == ApiDetails.API_GENIAM && type == GeniManager.TYPE_PROTOGENI)
					api.url += "/am";
			}
		}
		
		/**
		 * 
		 * @param findId Component ID
		 * @return Component matching the ID
		 * 
		 */
		public function getById(findId:String):*
		{
			var component:* = nodes.getById(findId);
			if(component != null) return component;
			component = stitching.getById(findId);
			if(component != null) return component;
			return nodes.getInterfaceById(findId);
		}
		
		override public function makeValidClientIdFor(value:String):String
		{
			if(type == GeniManager.TYPE_PROTOGENI)
			{
				return value.replace(/\./g, "").substr(0, 16);
			}
			return value;
		}
		
		override public function toString():String
		{
			var result:String = "[GeniManager ID=" + id.full
				+ ", Url=" + url
				+ ", Hrn=" + hrn
				+ ", Api=" + api.type
				+ ", Status=" + Status + "]\n";
			if(nodes.length > 0)
			{
				result += "\t[Nodes]\n";
				for each(var node:PhysicalNode in nodes.collection)
					result += node.toString();
				result += "\t[/Nodes]\n";
			}
			if(links.length > 0)
			{
				result += "\t[Links]\n";
				for each(var link:PhysicalLink in links.collection)
					result += link.toString();
				result += "\t[/Links]\n";
			}
			return result += "[/GeniManager]";
		}
	}
}