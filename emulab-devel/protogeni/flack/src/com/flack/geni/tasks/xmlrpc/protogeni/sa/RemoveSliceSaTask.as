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

package com.flack.geni.tasks.xmlrpc.protogeni.sa
{
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	
	/**
	 * Ensures that a slice has been removed. Only works when the slice has expired.
	 * If no slice with the same name exists or if it is removed, the register task is added to the parent task.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class RemoveSliceSaTask extends ProtogeniXmlrpcTask
	{
		public var slice:Slice;
		
		/**
		 * 
		 * @param newSlice Slice to remove
		 * 
		 */
		public function RemoveSliceSaTask(newSlice:Slice)
		{
			super(
				newSlice.authority.url,
				"",
				ProtogeniXmlrpcTask.METHOD_REMOVE,
				"Remove " + newSlice.Name,
				"Remove slice named " + newSlice.Name,
				"Remove Slice"
			);
			relatedTo.push(newSlice);
			slice = newSlice;
		}
		
		override protected function createFields():void
		{
			addNamedField("credential", slice.authority.userCredential.Raw);
			addNamedField("urn", slice.id.full);
			addNamedField("type", "Slice");
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=true):void
		{
			if (
				code == ProtogeniXmlrpcTask.CODE_SUCCESS ||
				code == ProtogeniXmlrpcTask.CODE_SEARCHFAILED
			)
			{
				parent.add(new RegisterSliceSaTask(slice));
				
				super.afterComplete(addCompletedMessage);
			}
			else
				faultOnSuccess();
		}
	}
}