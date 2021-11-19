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
	import com.flack.geni.RspecUtil;
	import com.flack.shared.utils.StringUtil;

	/**
	 * Collection of physical locations
	 * 
	 * @author mstrum
	 * 
	 */
	public class PhysicalLocationCollection
	{
		public var collection:Vector.<PhysicalLocation>;
		public function PhysicalLocationCollection()
		{
			collection = new Vector.<PhysicalLocation>();
		}
		
		public function add(location:PhysicalLocation):void
		{
			collection.push(location);
		}
		
		public function remove(location:PhysicalLocation):void
		{
			var idx:int = collection.indexOf(location);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(location:PhysicalLocation):Boolean
		{
			return collection.indexOf(location) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		/**
		 * 
		 * @param lat Latitude
		 * @param lng Longitude
		 * @return Physical location located at the given coordinates
		 * 
		 */
		public function getAt(lat:Number, lng:Number):PhysicalLocation
		{
			for each(var location:PhysicalLocation in collection)
			{
				if(location.latitude == lat && location.longitude == lng)
					return location;
			}
			return null;
		}
		
		/**
		 * 
		 * @return Physical location representing the middle of all the locations
		 * 
		 */
		public function get Middle():PhysicalLocation
		{
			var middleLatitude:Number = 0;
			var middleLongitude:Number = 0;
			for each(var location:PhysicalLocation in collection)
			{
				middleLatitude += location.latitude;
				middleLongitude += location.longitude;
			}
			return new PhysicalLocation(null, middleLatitude/collection.length, middleLongitude/collection.length);
		}
		
		/**
		 * 
		 * @return GraphML representation
		 * 
		 */
		public function get GraphML():String
		{
			var graphMl:XML = new XML("<?xml version=\"1.0\" encoding=\"UTF-8\"?><graphml />");
			var graphMlNamespace:Namespace = new Namespace(null, "http://graphml.graphdrawing.org/xmlns");
			graphMl.setNamespace(graphMlNamespace);
			var xsiNamespace:Namespace = RspecUtil.xsiNamespace;
			graphMl.addNamespace(xsiNamespace);
			graphMl.@xsiNamespace::schemaLocation = "http://graphml.graphdrawing.org/xmlns http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd";
			graphMl.@id = "Flack GraphML";
			graphMl.@edgedefault = "undirected";
			
			for each(var location:PhysicalLocation in collection)
			{
				for each(var node:PhysicalNode in location.nodes.collection)
				{
					var nodeXml:XML = <node />;
					nodeXml.@id = node.id;
					nodeXml.@name = node.name;
					for each(var nodeInterface:PhysicalInterface in node.interfaces.collection)
					{
						var nodeInterfaceXml:XML = <port />;
						nodeInterfaceXml.@name = nodeInterface.id;
						nodeXml.appendChild(nodeInterfaceXml);
					}
					graphMl.appendChild(nodeXml);
				}
				
				for each(var link:PhysicalLink in location.links.collection)
				{
					var hyperedgeXml:XML = <hyperedge />;
					hyperedgeXml.@id = link.id;
					for each(var linkInterface:PhysicalInterface in link.interfaces.collection)
					{
						var endpointXml:XML = <endpoint />;
						endpointXml.@node = linkInterface.owner.id;
						endpointXml.@port = linkInterface.id;
						hyperedgeXml.appendChild(endpointXml);
					}
					graphMl.appendChild(hyperedgeXml);
				}
			}
			
			return graphMl;
		}
		
		/**
		 * 
		 * @return DOT graph representation
		 * 
		 */
		public function get DotGraph():String
		{
			var dot:String = "graph Flack {";
			
			for each(var location:PhysicalLocation in collection)
			{
				for each(var node:PhysicalNode in location.nodes.collection)
					dot += "\n\t" + StringUtil.getDotString(node.name) + " [label=\""+node.name+"\"];";
				
				for each(var link:PhysicalLink in location.links.collection)
				{
					for(var i:int = 0; i < link.interfaces.length; i++)
					{
						for(var j:int = i+1; j < link.interfaces.length; j++)
							dot += "\n\t" + StringUtil.getDotString(link.interfaces.collection[i].owner.name) + " -- " + StringUtil.getDotString(link.interfaces.collection[j].owner.name) + ";";
					}
				}
			}
			
			return dot + "\n}";
		}
	}
}