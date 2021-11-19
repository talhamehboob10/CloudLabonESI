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
	import com.flack.geni.RspecUtil;
	import com.flack.geni.plugins.SliverTypeInterface;
	import com.flack.geni.plugins.SliverTypePart;
	import com.flack.geni.resources.physical.PhysicalNode;
	import com.flack.geni.resources.virt.VirtualInterface;
	import com.flack.geni.resources.virt.VirtualNode;
	
	import mx.collections.ArrayCollection;

	public class PlanetlabSliverType implements SliverTypeInterface
	{
		static public const TYPE_PLANETLAB_V1:String = "plab-vnode";
		static public const TYPE_PLANETLAB_V2:String = "plab-vserver";
		
		public var initscripts:Vector.<String> = null;
		public var selectedInitscript:String = "";
		
		public function PlanetlabSliverType()
		{
		}
		
		public function get Name():String { return TYPE_PLANETLAB_V2; }
		
		public function get namespace():Namespace
		{
			return new Namespace("planetlab", "http://www.planet-lab.org/resources/sfa/ext/planetlab/1");
		}
		
		public function get schema():String
		{
			return "";
		}
		
		public function get Part():SliverTypePart { return new PlanetlabVgroup(); }
		
		public function get Clone():SliverTypeInterface
		{
			var clone:PlanetlabSliverType = new PlanetlabSliverType();
			if(initscripts != null)
			{
				clone.initscripts = new Vector.<String>();
				for each(var iscript:String in initscripts)
					clone.initscripts.push(iscript);
			}
			clone.selectedInitscript = selectedInitscript;
			return clone;
		}
		
		public function get SimpleList():ArrayCollection
		{
			var list:ArrayCollection = new ArrayCollection();
			if(initscripts != null)
			{
				for each(var initScript:String in initscripts)
					list.addItem(initScript);
			}
			return list;
		}
		
		public function canAdd(node:VirtualNode):Boolean
		{
			return true;
		}
		
		public function applyToSliverTypeXml(node:VirtualNode, xml:XML):void
		{
			var planetlabInitscriptXml:XML = new XML("<initscript name=\""+selectedInitscript+"\" />");
			planetlabInitscriptXml.setNamespace(namespace);
			xml.appendChild(planetlabInitscriptXml);
		}
		
		public function applyFromAdvertisedSliverTypeXml(node:PhysicalNode, xml:XML):void
		{
			applyFromSliverTypeXml(null, xml);
		}
		
		public function applyFromSliverTypeXml(node:VirtualNode, xml:XML):void
		{
			for each(var sliverTypeChild:XML in xml.children())
			{
				if(sliverTypeChild.namespace() == namespace)
				{
					if(sliverTypeChild.localName() == "initscript")
					{
						if(node == null)
						{
							if(initscripts == null)
								initscripts = new Vector.<String>();
							initscripts.push(String(sliverTypeChild.@name));
						}
						else
							selectedInitscript = String(sliverTypeChild.@name);
					}
					
				}
			}
		}
		
		public function interfaceRemoved(iface:VirtualInterface):void
		{
		}
		
		public function interfaceAdded(iface:VirtualInterface):void
		{
		}
	}
}