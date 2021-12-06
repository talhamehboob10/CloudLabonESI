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
	import com.flack.shared.utils.StringUtil;
	
	import flash.globalization.DateTimeFormatter;
	import flash.globalization.DateTimeStyle;
	import flash.globalization.LocaleID;

	/**
	 * Details about some event which happened
	 * 
	 * @author mstrum
	 * 
	 */
	final public class LogMessage
	{
		// Levels
		public static const LEVEL_INFO:int = 0;
		public static const LEVEL_WARNING:int = 1;
		public static const LEVEL_FAIL:int = 2;
		public static const LEVEL_DIE:int = 3;
		public static function levelToString(level:int):String
		{
			switch(level)
			{
				case LEVEL_INFO:
					return "Info";
				case LEVEL_WARNING:
					return "*Warning*";
				case LEVEL_FAIL:
					return "**FAIL**";
				case LEVEL_DIE:
					return "***DIE***";
				default:
					return "Unknown ("+level+")";
			}
		}
		
		// Importance
		public static const IMPORTANCE_HIGH:int = 0;
		public static const IMPORTANCE_LOW:int = 1;
		
		
		/**
		 * Items this message is related to (e.g. a manager, slice, user, task, etc.)
		 */
		public var relatedTo:Array;
		
		public var origin:*;
		
		/**
		 * Human-readable name, understandable out of context ("List Resources @ URL")
		 */
		[Bindable]
		public var fullTitleName:String = "";
		/**
		 * Human-readable name, understandable in context ("List Resources")
		 */
		[Bindable]
		public var shortTitleName:String = "";
		/**
		 * 
		 * @return fullTitleName if set, shortTitleName otherwise
		 * 
		 */
		public function get TitleName():String
		{
			if(fullTitleName.length > 0)
				return fullTitleName;
			else
				return shortTitleName;
		}
		
		/**
		 * Human-readable short status to include in the title ("Success", "Failed", "Started", etc.)
		 */
		[Bindable]
		public var titleMessage:String = "";
		
		/**
		 * 
		 * @return "TitleName: titleMessage" if TitleName available, titleMessage otherwise
		 * 
		 */
		public function get Title():String
		{
			if(TitleName.length > 0)
				return TitleName + ": " + titleMessage;
			else
				return titleMessage;
		}
		/**
		 * 
		 * @return "shortTitleName: titleMessage" if shortTitleName set,
		 *         "fullTitleName: titleMessage" if fullTitleName set, 
		 *         "titleMessage" otherwise
		 * 
		 */
		public function get ShortestTitle():String
		{
			if(shortTitleName.length > 0)
				return shortTitleName + ": " + titleMessage;
			else if(fullTitleName.length > 0)
				return fullTitleName + ": " + titleMessage;
			else
				return titleMessage;
		}
		
		/**
		 * Full text
		 */
		[Bindable]
		public var message:String;
		/**
		 * 
		 * @return Shortened version of the message (80 characters or so)
		 * 
		 */
		public function get ShortMessage():String
		{
			return StringUtil.shortenString(message, 80, true);
		}
		
		/**
		 * What level of message is this?
		 */
		public var level:int;
		
		/**
		 * How important is this message?
		 */
		public var importance:int;
		
		/**
		 * When did this event occur?
		 */
		public var timeStamp:Date
		
		/**
		 * 
		 * @param newRelatedTo Objects this message is related to (geni objects, tasks, etc.)
		 * @param newTitleFullName Full name of the message understandable out of context (e.g. list @ url)
		 * @param newTitleMessage Short version of the message to include in the title
		 * @param newMessage Full message (e.g. full XML-RPC result)
		 * @param newTitleShortName Short name of the message understandable in context (e.g. list)
		 * @param newLevel Is this message an error, a warning, just info, etc.
		 * @param newImportance Is this message important?
		 * 
		 */
		public function LogMessage(newRelatedTo:Array,
								   newTitleFullName:String,
								   newTitleMessage:String,
								   newMessage:String,
								   newTitleShortName:String,
								   newLevel:int = LEVEL_INFO,
								   newImportance:int = IMPORTANCE_LOW,
								   newOrigin:* = null)
		{
			if(newRelatedTo == null)
				relatedTo = [];
			else
				relatedTo = newRelatedTo;
			fullTitleName = newTitleFullName;
			titleMessage = newTitleMessage;
			shortTitleName = newTitleShortName;
			message = newMessage;
			level = newLevel;
			importance = newImportance;
			origin = newOrigin;
			timeStamp = new Date();
		}
		
		/**
		 * Sees if this log message is related to any of the given items.
		 * 
		 * @param objects Items tested to see if this message is related to
		 * @return true if this message is related to anything from 'objects'
		 * 
		 */
		public function relatedToAny(objects:Array):Boolean
		{
			for each(var object:* in objects)
			{
				if(relatedTo.indexOf(object) != -1)
					return true;
			}
			return false;
		}
		
		public function toString(includeVersion:Boolean = true):String
		{
			var versionString:String = "";
			if(includeVersion)
				versionString = SharedMain.ClientString+"\n";
			return "-MSG------------------------------\n" +
				"UTC Time: " + (new DateTimeFormatter(LocaleID.DEFAULT, DateTimeStyle.SHORT, DateTimeStyle.SHORT)).formatUTC(timeStamp) + "\n" +
				versionString +
				"Level: " + levelToString(level) + "\n" +
				"Title: " + Title + "\n" +
				"Message:\n" + message + "\n" +
				"\n------------------------------END-";
		}
	}
}