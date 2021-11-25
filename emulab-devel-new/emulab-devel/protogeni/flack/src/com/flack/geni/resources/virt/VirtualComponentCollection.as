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
	/**
	 * Collection of components
	 * 
	 * @author mstrum
	 * 
	 */
	public class VirtualComponentCollection extends SliverCollection
	{
		public function VirtualComponentCollection(src:Array = null)
		{
			super(src);
		}

		/**
		 * 
		 * @return TRUE if changes have been made but not submitted
		 * 
		 */
		public function get UnsubmittedChanges():Boolean
		{
			for each(var component:VirtualComponent in collection)
			{
				if(component.unsubmittedChanges)
					return true;
			}
			return false;
		}
		
		public function getComponentById(id:String):VirtualComponent
		{
			return super.getById(id) as VirtualComponent;
		}
		
		public function getComponentsByUnsubmittedChanges(changed:Boolean):VirtualComponentCollection
		{
			var components:VirtualComponentCollection = new VirtualComponentCollection();
			for each (var component:VirtualComponent in collection)
			{
				if(component.unsubmittedChanges == changed)
					components.add(component);
			}
			return components;
		}
		
		/**
		 * 
		 * @param id Client ID
		 * @return Component with the given client ID
		 * 
		 */
		public function getByClientId(id:String):VirtualComponent
		{
			for each(var component:VirtualComponent in collection)
			{
				if(component.clientId == id)
					return component;
			}
			return null;
		}
		
		/**
		 * 
		 * @param clientId Partial client ID
		 * @return Nodes with a client id matching part of the given string
		 * 
		 */
		public function searchByClientId(clientId:String):VirtualComponentCollection
		{
			var components:VirtualComponentCollection = new VirtualComponentCollection();
			for each (var component:VirtualComponent in collection)
			{
				if(component.clientId.indexOf(clientId) != -1)
					components.add(component);
			}
			return components;
		}
		
		override public function markStaged():void
		{
			for each(var component:VirtualComponent in collection)
			{
				component.markStaged();
			}
		}
	}
}