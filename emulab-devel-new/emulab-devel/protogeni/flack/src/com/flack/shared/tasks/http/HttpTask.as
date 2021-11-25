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
	import com.flack.shared.utils.NetUtil;
	import com.flack.shared.utils.StringUtil;
	
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.HTTPStatusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	/**
	 * Downloads a document at the given URL over plain HTTP (no TLS JavaScript support, use JsHttpTask if needed)
	 * 
	 * @author mstrum
	 * 
	 */
	public class HttpTask extends Task
	{
		public var url:String;
		
		public var urlRequest:URLRequest;
		public var urlLoader:URLLoader;
		
		/**
		 * 
		 * @param taskUrl URL of document to download
		 * @param taskName
		 * @param taskDescription
		 * @param taskParent
		 * @param taskRetryWhenPossible
		 * 
		 */
		public function HttpTask(taskUrl:String,
								 taskName:String = "HTTP Task",
								 taskDescription:String = "Download using HTTP",
								 taskParent:TaskGroup = null,
								 taskRetryWhenPossible:Boolean = true)
		{
			super(
				taskName,
				taskDescription,
				"",
				taskParent,
				60,
				0,
				taskRetryWhenPossible
			);
			url = taskUrl;
			NetUtil.checkLoadCrossDomain(url);
		}
		
		override protected function runStart():void
		{
			urlRequest = new URLRequest(url);
			urlLoader = new URLLoader();
			urlLoader.addEventListener(Event.COMPLETE, callSuccess);
			urlLoader.addEventListener(ErrorEvent.ERROR, callErrorFailure);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, callIoErrorFailure);
			urlLoader.addEventListener(IOErrorEvent.NETWORK_ERROR, callIoErrorFailure);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, callSecurityFailure);
			//urlLoader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, callHttpStatus);
			urlLoader.addEventListener(HTTPStatusEvent.HTTP_STATUS, callHttpStatus);
			try
			{
				addMessage("Loading", "Loading from " + url);
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
		
		public function callHttpStatus(event:HTTPStatusEvent):void
		{
			this.addMessage("HTTP", event.toString());
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