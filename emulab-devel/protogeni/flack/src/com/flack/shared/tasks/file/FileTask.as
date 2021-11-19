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

package com.flack.shared.tasks.file
{
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.utils.StringUtil;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	
	/**
	 * Does NOT support being started by a task group, must be manually started due to security
	 * 
	 * Supports:
	 *  Loading a file the user specifies into data.
	 *  Saving value in data to a file the user specifies.
	 * 
	 * @author mstrum
	 * 
	 */
	public final class FileTask extends Task
	{
		private static const LOADING:Boolean = false;
		private static const SAVING:Boolean = true;
		
		/**
		 * Filename that should be entered into the file dialog by default, if saving
		 */
		public var fileName:String = "";
		
		private var operation:Boolean;
		private var fileReference:FileReference;
		
		/**
		 * Saves if data given, loads otherwise
		 * 
		 * @param saveData Data to save
		 * 
		 */
		public function FileTask(saveData:* = null)
		{
			super(
				(saveData == null ? "Open file" : "Save file"),
				(saveData == null ? "Opens and reads data from a selected file" : "Saves data to a selected file")
			);
			
			fileReference = new FileReference();
			fileReference.addEventListener(Event.SELECT, onFileSelect);
			fileReference.addEventListener(Event.CANCEL, onFileCancel);
			fileReference.addEventListener(Event.COMPLETE, onFileComplete);
			fileReference.addEventListener(IOErrorEvent.IO_ERROR, onFileIoError);
			fileReference.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onFileSecurityError);
			
			data = saveData;
			operation = saveData != null;
		}
		
		/**
		 * MUST be called after a mouse click due to Flash security...
		 * 
		 * @param event Mouse-click event
		 * 
		 */
		public function startOperation(event:Event):void
		{
			super.start();
			
			try
			{
				if(operation)
					fileReference.save(data, fileName);
				else
					fileReference.browse([new FileFilter("All files (*.*)", "*.*")]);
			}
			catch(e:Error)
			{
				afterError(
					new TaskError(
						"Error: " + StringUtil.errorToString(e),
						TaskError.CODE_UNEXPECTED,
						e
					)
				);
			}
		}
		
		private function onFileSelect(event:Event):void
		{
			fileName = fileReference.name;
			if(operation == LOADING)
				fileReference.load();
		}
		
		private function onFileComplete(event:Event):void
		{
			if(operation == LOADING)
				data = fileReference.data.readUTFBytes(fileReference.data.length);
			afterComplete();
		}
		
		private function onFileCancel(event:Event):void
		{
			cancel();
		}
		
		private function onFileIoError(event:IOErrorEvent):void
		{
			afterError(
				new TaskError(
					"IO Error: " + event.text,
					TaskError.FAULT,
					event
				)
			);
		}
		
		private function onFileSecurityError(event:SecurityErrorEvent):void
		{
			afterError(
				new TaskError(
					"Security Error: " + event.text,
					TaskError.FAULT,
					event
				)
			);
		}
		
		override protected function runCleanup():void
		{
			fileReference.removeEventListener(Event.SELECT, onFileSelect);
			fileReference.removeEventListener(Event.CANCEL, onFileCancel);
			fileReference.removeEventListener(Event.COMPLETE, onFileComplete);
			fileReference.removeEventListener(IOErrorEvent.IO_ERROR, onFileIoError);
			fileReference.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onFileSecurityError);
			fileReference = null;
		}
	}
}