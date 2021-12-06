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

package com.flack.geni.resources
{
	/**
	 * Holds extension information for a parent object
	 * 
	 * @author mstrum
	 * 
	 */
	public class Extensions
	{
		public var spaces:ExtensionSpaceCollection;
		
		public function Extensions()
		{
			spaces = null;
		}
		
		public function get Clone():Extensions
		{
			var newExtensions:Extensions = new Extensions();
			if(spaces != null)
			{
				for each(var existingSpace:ExtensionSpace in spaces.collection)
					newExtensions.spaces.add(existingSpace.Clone);
			}
			return newExtensions;
		}
		
		static public function buildFromChildren(searchChildren:XMLList, ignoreNamespaces:Array):Extensions
		{
			var extensions:Extensions = new Extensions();
			var space:ExtensionSpace;
			
			for each(var searchChild:XML in searchChildren)
			{
				if(searchChild.name() == null ||
					searchChild.name().uri.length == 0 ||
					ignoreNamespaces.indexOf(searchChild.name().uri) != -1)
					continue;
				
				space = extensions.spaces.getForNamespace(searchChild.namespace());
				if(space == null)
				{
					space = new ExtensionSpace();
					space.namespace = searchChild.namespace();
					extensions.spaces.add(space);
				}
				
				space.children.push(searchChild.copy());
			}
			return extensions;
		}
		
		public function buildFromOriginal(source:XML, ignoreNamespaces:Array):void
		{
			spaces = new ExtensionSpaceCollection();
			var space:ExtensionSpace;
			
			var searchAttributes:XMLList = source.attributes();
			for each(var searchAttribute:XML in searchAttributes)
			{
				if(searchAttribute.name() == null ||
					searchAttribute.name().uri.length == 0 ||
					ignoreNamespaces.indexOf(searchAttribute.name().uri) != -1)
					continue;
				
				if(spaces != null)
					space = spaces.getForNamespace(searchAttribute.namespace());
				if(space == null)
				{
					space = new ExtensionSpace();
					space.namespace = searchAttribute.namespace();
					spaces.add(space);
				}
				
				var newAttribute:ExtensionAttribute = new ExtensionAttribute();
				newAttribute.namespace = searchAttribute.namespace();
				newAttribute.name = searchAttribute.name().localName;
				newAttribute.value = searchAttribute.toString();
				space.attributes.push(newAttribute);
			}
			
			if(source.hasComplexContent())
			{
				var searchChildren:XMLList = source.children();
				for each(var searchChild:XML in searchChildren)
				{
					if(searchChild.name() == null ||
						searchChild.name().uri.length == 0 ||
						ignoreNamespaces.indexOf(searchChild.name().uri) != -1)
						continue;
					
					if(spaces != null)
						space = spaces.getForNamespace(searchChild.namespace());
					if(space == null)
					{
						space = new ExtensionSpace();
						space.namespace = searchChild.namespace();
						spaces.add(space);
					}

					space.children.push(searchChild.copy());
				}
			}
		}
		
		public function createAndApply(name:String):XML
		{
			var namespaceString:String = "";
			var attributeString:String = "";
			var childString:String = "";
			if(spaces != null)
			{
				for each(var space:ExtensionSpace in spaces.collection)
				{
					if(space.namespace.prefix != null && space.namespace.prefix.length > 0)
						namespaceString += "xmlns:" + space.namespace.prefix + "=\"" + space.namespace.uri + "\" ";
					attributeString += space.attributesToString();
					childString += space.childrenToString();
				}
			}
			return new XML("<"+name+" "+namespaceString+" "+attributeString+">"+childString+"</"+name+">");
		}
		
		public function toString():String
		{
			var result:String = "";
			if(spaces != null)
			{
				for each(var space:ExtensionSpace in spaces.collection)
				{
					result += space.childrenToString();
				}
			}
			return result;
		}
	}
}