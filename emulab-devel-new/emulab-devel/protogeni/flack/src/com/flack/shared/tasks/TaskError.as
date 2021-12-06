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

package com.flack.shared.tasks
{
	/**
	 * Details about an error that occured in a task
	 * 
	 * @author mstrum
	 * 
	 */
	public class TaskError extends Error
	{
		/**
		 * Task timed out
		 */
		public static const TIMEOUT:uint = 0;
		/**
		 * Unexpected problem while executing code, like null pointers
		 */
		public static const CODE_UNEXPECTED:uint = 1;
		/**
		 * Error found while executing in code, like an incorrect format detected
		 */
		public static const CODE_PROBLEM:uint = 2;
		/**
		 * Error outside of the scope of the running code, like an error from JavaScript
		 */
		public static const FAULT:uint = 3;
		
		/**
		 * Data relevant to the error
		 */
		public var data:*;
		
		/**
		 * 
		 * @param message Message of the error
		 * @param id Error number
		 * @param errorData Data related to the error
		 * 
		 */
		public function TaskError(message:String = "",
								  id:uint = 0,
								  errorData:* = null)
		{
			super(message, id);
			data = errorData;
		}
		
		public function toString():String
		{
			return "[TaskError ID="+errorID+" Message=\""+message+"\", ]";
		}
	}
}