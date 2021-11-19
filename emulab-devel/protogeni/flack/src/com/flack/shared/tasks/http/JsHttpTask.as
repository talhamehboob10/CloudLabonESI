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

package com.flack.shared.tasks.http
{
	import com.flack.shared.logging.LogMessage;
	import com.flack.shared.tasks.Task;
	import com.flack.shared.tasks.TaskError;
	import com.flack.shared.tasks.TaskGroup;
	import com.flack.shared.utils.StringUtil;
	import com.mattism.http.xmlrpc.JSLoader;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLRequest;
	
	/**
	 * Downloads a document at the given URL over the TLS JavaScript implementation
	 * 
	 * @author mstrum
	 * 
	 */
	public class JsHttpTask extends Task
	{
		public var url:String;
		
		public var urlRequest:URLRequest;
		public var urlLoader:JSLoader;
		
		/**
		 * 
		 * @param taskUrl URL of document to download
		 * @param taskFullName
		 * @param taskDescription
		 * @param taskShortName
		 * @param taskParent
		 * @param taskRetryWhenPossible
		 * 
		 */
		public function JsHttpTask(taskUrl:String,
								 taskFullName:String = "JS HTTP Task",
								 taskDescription:String = "Download using JS HTTP",
								 taskShortName:String = "",
								 taskParent:TaskGroup = null,
								 taskRetryWhenPossible:Boolean = true)
		{
			super(
				taskFullName,
				taskDescription,
				taskShortName,
				taskParent,
				60,
				0,
				taskRetryWhenPossible
			);
			url = taskUrl;
		}
		
		override protected function runStart():void
		{
			urlRequest = new URLRequest(url);
			urlLoader = new JSLoader();
			urlLoader.addEventListener(Event.COMPLETE, callSuccess);
			urlLoader.addEventListener(ErrorEvent.ERROR, callErrorFailure);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, callIoErrorFailure);
			urlLoader.addEventListener(IOErrorEvent.NETWORK_ERROR, callIoErrorFailure);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, callSecurityFailure);
			try
			{
				urlLoader.load(urlRequest);
			}
			catch (e:Error)
			{
				afterError(new TaskError(StringUtil.errorToString(e), TaskError.FAULT));
			}
		}
		
		public function callSuccess(event:Event):void
		{
			cancelTimers();
			data = urlLoader.data;
			addMessage(
				"Recieved",
				data,
				LogMessage.LEVEL_INFO,
				LogMessage.IMPORTANCE_HIGH
			);
			afterComplete(false);
		}
		
		public function callErrorFailure(event:ErrorEvent):void
		{
			afterError(new TaskError(event.toString(), TaskError.FAULT));
		}
		
		public function callIoErrorFailure(event:IOErrorEvent):void
		{
			afterError(new TaskError(event.toString(), TaskError.FAULT));
		}
		
		public function callSecurityFailure(event:SecurityErrorEvent):void
		{
			afterError(new TaskError(event.toString(), TaskError.FAULT));
		}
		
		override protected function runTimeout():Boolean
		{
			if(retryWhenPossible)
				runCleanup();
			return super.runTimeout();
		}
		
		override protected function runCleanup():void
		{
			if(urlLoader != null)
			{
				urlLoader.close();
				urlLoader.removeEventListener(Event.COMPLETE, callSuccess);
				urlLoader.removeEventListener(ErrorEvent.ERROR, callErrorFailure);
				urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, callIoErrorFailure);
				urlLoader.removeEventListener(IOErrorEvent.NETWORK_ERROR, callIoErrorFailure);
				urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, callSecurityFailure);
			}
		}
	}
}