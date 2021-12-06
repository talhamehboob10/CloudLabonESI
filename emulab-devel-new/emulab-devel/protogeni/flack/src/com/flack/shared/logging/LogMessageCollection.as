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

package com.flack.shared.logging 
{
	import com.flack.shared.SharedMain;

	/**
	 * Handles collections of log messages
	 * 
	 * @author mstrum
	 * 
	 */
	public class LogMessageCollection
	{
		public var collection:Vector.<LogMessage>;
		public function LogMessageCollection()
		{
			collection = new Vector.<LogMessage>();
		}
		
		public function add(msg:LogMessage):void
		{
			collection.push(msg);
		}
		
		public function remove(msg:LogMessage):void
		{
			var idx:int = collection.indexOf(msg);
			if(idx > -1)
				collection.splice(idx, 1);
		}
		
		public function contains(msg:LogMessage):Boolean
		{
			return collection.indexOf(msg) > -1;
		}
		
		public function get length():int
		{
			return collection.length;
		}
		
		public function get Important():LogMessageCollection
		{
			var results:LogMessageCollection = new LogMessageCollection();
			for each(var msg:LogMessage in collection)
			{
				if(msg.importance == LogMessage.IMPORTANCE_HIGH)
					results.add(msg);
			}
			return results;
		}
		
		/**
		 * Returns log messages related to anything in related,
		 * can be a task to get a task's logs or an entity like a manager
		 * 
		 * @param related Items for which log messages should be related to
		 * @return Messages related to 'related'
		 * 
		 */
		public function getRelatedTo(related:Array):LogMessageCollection
		{
			var relatedLogs:LogMessageCollection = new LogMessageCollection();
			for each(var msg:LogMessage in collection)
			{
				for each(var relatedTo:* in related)
				{
					if(msg.relatedTo.indexOf(relatedTo) != -1)
					{
						relatedLogs.add(msg);
						break;
					}
				}
			}
			return relatedLogs;
		}
		
		public function toString():String
		{
			var output:String = "******* Messages *******\n" + SharedMain.ClientString+"\n************************\n";
			for each(var msg:LogMessage in collection)
				output +=  msg.toString(false) + "\n";
			return output;
		}
	}
}