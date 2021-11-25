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
	 * All extensions under one namespace for a parent extended object
	 * 
	 * @author mstrum
	 * 
	 */
	public class ExtensionSpace
	{
		public var namespace:Namespace;
		public var attributes:Vector.<ExtensionAttribute> = new Vector.<ExtensionAttribute>();
		public var children:Vector.<XML> = new Vector.<XML>();
		
		public function ExtensionSpace()
		{
		}
		
		public function get Clone():ExtensionSpace
		{
			var newSpace:ExtensionSpace = new ExtensionSpace();
			newSpace.namespace = namespace;
			for each(var ea:ExtensionAttribute in attributes)
			{
				var newEa:ExtensionAttribute = new ExtensionAttribute();
				newEa.name = ea.name;
				newEa.namespace = ea.namespace;
				newEa.value = ea.value;
				newSpace.attributes.push(newEa);
			}
			for each(var child:XML in children)
			{
				newSpace.children.push(child.copy());
			}
			return newSpace;
		}
		
		public function attributesToString():String
		{
			var value:String = "";
			for each(var attribute:ExtensionAttribute in attributes)
				value += attribute.namespace.prefix + ":" + attribute.name + "=\""+attribute.value+"\" ";
			return value;
		}
		
		public function childrenToString():String
		{
			var value:String = "";
			for each(var child:XML in children)
				value += child.toXMLString();
			return value;
		}
	}
}