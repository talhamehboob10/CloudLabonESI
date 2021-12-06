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
	import com.flack.geni.GeniMain;
	import com.flack.geni.display.windows.CreateSliceWindow;
	import com.flack.geni.resources.sites.GeniAuthority;
	import com.flack.geni.resources.sites.GeniManager;
	import com.flack.geni.resources.sites.GeniManagerCollection;
	import com.flack.geni.resources.virt.Slice;
	import com.flack.geni.tasks.xmlrpc.protogeni.ProtogeniXmlrpcTask;
	import com.flack.shared.FlackEvent;
	import com.flack.shared.SharedMain;
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.resources.IdnUrn;
	import com.flack.shared.tasks.TaskError;

	/**
	 * If creating, used to check to make sure slice name is valid and not used.
	 * If getting, gets basic information like what managers have slivers.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ResolveSliceSaTask extends ProtogeniXmlrpcTask
	{
		public var slice:Slice;
		public var isCreating:Boolean;
		public var prompt:Boolean;
		
		/**
		 * 
		 * @param taskSlice Slice to resolve
		 * @param creating Resolving before creating? FALSE if getting.
		 * @param promptUserForName Prompt the user if a different slice name is needed
		 * 
		 */
		public function ResolveSliceSaTask(taskSlice:Slice,
										   creating:Boolean = false,
										   promptUserForName:Boolean = false)
		{
			super(
				taskSlice.authority.url,
				"",
				ProtogeniXmlrpcTask.METHOD_RESOLVE,
				"Resolve " + taskSlice.Name,
				"Resolving slice named " + taskSlice.Name,
				"Resolve Slice"
			);
			relatedTo.push(taskSlice);
			slice = taskSlice;
			isCreating = creating;
			prompt = promptUserForName;
		}
		
		override protected function runStart():void
		{
			if(prompt)
				promptName();
			else
				super.runStart();
		}
		
		public function promptName():void
		{
			var promptForNameWindow:CreateSliceWindow = new CreateSliceWindow();
			promptForNameWindow.onSuccess = userChoseName;
			promptForNameWindow.onCancel = cancel;
			promptForNameWindow.showWindow();
			promptForNameWindow.valueTextinput.restrict = "a-zA-Z0-9\-";
			promptForNameWindow.valueTextinput.maxChars = 19;
			if(slice.Name.length > 0)
				promptForNameWindow.title = "Slice name not valid, please try another";
			else
				promptForNameWindow.title = "Please enter a valid, non-existing slice name";
			promptForNameWindow.SliceName = slice.Name;
		}
		
		public function userChoseName(newName:String, newAuthority:GeniAuthority):void
		{
			slice.authority = newAuthority;
			url = newAuthority.url;
			slice.id = IdnUrn.makeFrom(slice.authority.id.authority, IdnUrn.TYPE_SLICE, newName);
			super.runStart();
		}
		
		override protected function createFields():void
		{
			addNamedField("credential", slice.authority.userCredential.Raw);
			addNamedField("urn", slice.id.full);
			addNamedField("type", "Slice");
		}
		
		override protected function afterComplete(addCompletedMessage:Boolean=false):void
		{
			var msg:String;
			if(isCreating)
			{
				if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
				{
					afterError(
						new TaskError(
							"Already exists. Slice named " + slice.Name + " already exists",
							TaskError.CODE_PROBLEM,
							code
						)
					);
				}
				else if(code == ProtogeniXmlrpcTask.CODE_SEARCHFAILED)
				{
					// Good, the slice doesn't exist, run remove before creating
					parent.add(new RemoveSliceSaTask(slice));
					
					addMessage(
						"Valid",
						"No other slice has the same name. Slice can be created.",
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
					
					super.afterComplete(addCompletedMessage);
				}
				// Bad name
				else if(code == ProtogeniXmlrpcTask.CODE_BADARGS)
				{
					afterError(
						new TaskError(
							"Bad name. Slice creation failed because of a bad name: " + slice.Name,
							TaskError.CODE_PROBLEM,
							code
						)
					);
				}
				else if(code == ProtogeniXmlrpcTask.CODE_FORBIDDEN)
				{
					afterError(
						new TaskError(
							"Forbidden. " + output,
							TaskError.CODE_PROBLEM,
							code
						)
					);
				}
				else
					faultOnSuccess();
			}
			// Getting
			else
			{
				if (code == ProtogeniXmlrpcTask.CODE_SUCCESS)
				{
					slice.id = new IdnUrn(data.urn);
					slice.hrn = data.hrn;
					slice.reportedManagers = new GeniManagerCollection();
					for each(var reportedManagerId:String in data.component_managers)
					{
						var manager:GeniManager = GeniMain.geniUniverse.managers.getById(reportedManagerId);
						if(manager != null)
						{
							slice.reportedManagers.add(manager);
						}
						else
						{
							addMessage("Unknown aggregate in slice",
								"Unknown manager was reported to have resources on " +
								slice.Name + ": " + reportedManagerId,
								LogMessage.LEVEL_WARNING,
								LogMessage.IMPORTANCE_HIGH);
						}
					}
					
					addMessage(
						"Resolved",
						slice.Name + " was reported to have resources on " + slice.reportedManagers.length + " known aggregate(s)",
						LogMessage.LEVEL_INFO,
						LogMessage.IMPORTANCE_HIGH
					);
					
					SharedMain.sharedDispatcher.dispatchChanged(
						FlackEvent.CHANGED_SLICE,
						slice
					);
					
					super.afterComplete(addCompletedMessage);
				}
				else
					faultOnSuccess();
			}
		}
	}
}