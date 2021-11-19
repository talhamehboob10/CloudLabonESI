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

package com.flack.geni.resources.virt
{
	import com.flack.geni.resources.Extensions;
	import com.flack.geni.resources.physical.PhysicalInterface;
	import com.flack.shared.resources.IdentifiableObject;
	import com.flack.shared.resources.IdnUrn;

	/**
	 * Interface on a resource used to connect to other resources through links
	 *  
	 * @author mstrum
	 * 
	 */	
	public class VirtualInterface extends IdentifiableObject
	{
		public static var tunnelSecond:int = 1;
		public static var tunnelFirst:int = 0;
		public static function startNextTunnel():void
		{
			tunnelSecond = 1;
			tunnelFirst++;
		}
		public static function getNextTunnel():String
		{
			var first:int = tunnelFirst & 0xff;
			var second:int = tunnelSecond & 0xff;
			tunnelSecond++;
			return "192.168." + String(first) + "." + String(second);
		}
		
		public var clientId:String = "";
		
		public var _owner:VirtualNode;
		[Bindable]
		public function get Owner():VirtualNode
		{
			return _owner;
		}
		public function set Owner(newOwner:VirtualNode):void
		{
			_owner = newOwner;
			if(_owner != null && clientId.length == 0)
				clientId = _owner.slice.getUniqueId(this, _owner.clientId + ":if");
		}
		
		public var bound:Boolean = false;
		public var physicalId:IdnUrn = new IdnUrn();
		public function get Physical():PhysicalInterface
		{
			if(physicalId.full.length > 0 && _owner.Physical != null)
				return _owner.Physical.interfaces.getById(physicalId.full);
			else
				return null;
		}
		public function set Physical(value:PhysicalInterface):void
		{
			if(value != null)
				physicalId = new IdnUrn(value.id.full);
			else
				physicalId = new IdnUrn();
		}
		public function get Bound():Boolean
		{
			return physicalId.full.length > 0;
		}
		
		public var macAddress:String = "";
		public var vmac:String = "";
		
		// tunnel stuff
		public var ip:Ip = new Ip();
		
		[Bindable]
		public var links:VirtualLinkCollection = new VirtualLinkCollection();

		public var capacity:Number;
		
		public var extensions:Extensions = new Extensions();
		
		/**
		 * 
		 * @param own Node where the interface will reside
		 * @param newId IDN-URN
		 * 
		 */
		public function VirtualInterface(own:VirtualNode,
										 newId:String = "")
		{
			super(newId);
			Owner = own;
		}
		
		override public function toString():String
		{
			return "[Interface SliverID="+id.full+", ClientID="+clientId+"]";
		}
	}
}