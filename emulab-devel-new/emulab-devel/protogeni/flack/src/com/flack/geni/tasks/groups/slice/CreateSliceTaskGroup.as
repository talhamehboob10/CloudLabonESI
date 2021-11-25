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

package com.flack.geni.tasks.groups.slice
{
	import com.flack.geni.GeniMain;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.geni.tasks.xmlrpc.protogeni.sa.ResolveSliceSaTask;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.tasks.SerialTaskGroup;
	import com.flack.shared.tasks.Task;
	
	import mx.controls.Alert;
	
	/**
	 * Creates a new empty slice container.  Call SubmitSlice to allocate resources.
	 * 
	 * @author mstrum
	 * 
	 */
	public class CreateSliceTaskGroup extends SerialTaskGroup
	{
		public var sliceName:String;
		public var newSlice:Slice;
		public var authority:GeniAuthority;
		public var prompt:Boolean;
		
		/**
		 * 
		 * @param newSliceName Desired name for the slice
		 * @param newAuthority Authority to create slice at
		 * @param promptOnInvalidName Prompt the user to change name if not successful?
		 * 
		 */
		public function CreateSliceTaskGroup(newSliceName:String = "",
											 newAuthority:GeniAuthority = null,
											 promptOnInvalidName:Boolean = true)
		{
			super(
				"Create " + newSliceName,
				"Creates an empty slice named " + newSliceName
			);
			sliceName = newSliceName;
			authority = newAuthority == null ? GeniMain.geniUniverse.user.authority : newAuthority;
			prompt = promptOnInvalidName;
		}
		
		override protected function runStart():void
		{
			if(tasks.length == 0)
			{
				newSlice = new Slice(IdnUrn.makeFrom(
					authority.id.authority,
					IdnUrn.TYPE_SLICE,
					sliceName).full
				);
				newSlice.hrn = sliceName;
				newSlice.creator = GeniMain.geniUniverse.user;
				newSlice.authority = authority;
				relatedTo.push(newSlice);
					
				add(new ResolveSliceSaTask(newSlice, true, sliceName.length == 0));
			}
			
			super.runStart();
		}
		
		override public function erroredTask(task:Task):void
		{
			if(task is ResolveSliceSaTask)
			{
				// Only prompt if resolved worked (already exists) or if badargs (bad name)
				if(task.error.data != null
					&& (task.error.data == ProtogeniXmlrpcTask.CODE_BADARGS || task.error.data == ProtogeniXmlrpcTask.CODE_SUCCESS))
				if(prompt)
				{
					add(new ResolveSliceSaTask(newSlice, true, true));
					return;
				}
				else
					Alert.show(task.error.message);
			}
				
			super.erroredTask(task);
		}
	}
}