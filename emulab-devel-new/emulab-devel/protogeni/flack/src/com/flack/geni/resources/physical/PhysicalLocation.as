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

package com.flack.geni.resources.physical
{
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.shared.resources.IdnUrn;

	/**
	 * Location with resources
	 * 
	 * @author mstrum
	 * 
	 */
	public class PhysicalLocation
	{
		static public const defaultLatitude:Number = 35.693829;
		static public const defaultLongitude:Number = -41.026843;
		
		public var latitude:Number;
		public var longitude:Number;
		
		public var country:String;
		[Bindable]
		public var name:String;
		
		public var nodes:PhysicalNodeCollection = new PhysicalNodeCollection();
		public var links:PhysicalLinkCollection = new PhysicalLinkCollection();
		
		public var managerId:IdnUrn;
		
		/**
		 * 
		 * @param newManager Manager
		 * @param lat Latitude
		 * @param lon Longitude
		 * @param newCountry Country
		 * @param newName Name
		 * 
		 */
		public function PhysicalLocation(newManager:GeniManager,
										 lat:Number = defaultLatitude,
										 lon:Number = defaultLongitude,
										 newCountry:String = "",
										 newName:String = "")
		{
			latitude = lat;
			longitude = lon;
			if(newManager != null)
				managerId = new IdnUrn(newManager.id.full);
			country = newCountry;
			name = newName;
		}
		
		/**
		 * 
		 * @return Collection of links leaving this location to another unique location
		 * 
		 */
		public function get LinksLeaving():PhysicalLinkCollection
		{
			var group:PhysicalLinkCollection = new PhysicalLinkCollection();
			for each (var link:PhysicalLink in links.collection)
			{
				for each(var nodeInterface:PhysicalInterface in link.interfaces.collection)
				{
					if(nodeInterface.owner.location != this && !group.contains(link))
					{
						group.add(link);
						break;
					}
				}
			}
			return group;
		}
	}
}