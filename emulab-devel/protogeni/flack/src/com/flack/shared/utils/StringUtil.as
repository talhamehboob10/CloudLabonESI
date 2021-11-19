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

package com.flack.shared.utils
{
	import flash.globalization.LocaleID;
	import flash.globalization.NumberFormatter;
	import flash.system.Capabilities;

	/**
	 * Common functions used for dealing with strings
	 * 
	 * @author mstrum
	 * 
	 */
	public final class StringUtil
	{
		// Makes the first letter uppercase
		public static function firstToUpper (phrase:String):String
		{
			return  phrase.substring(1, 0).toUpperCase() + phrase.substring(1).toLowerCase();
		}
		
		public static function replaceString(original:String, find:String, replace:String):String
		{
			return original.split(find).join(replace);
		}
		
		// Shortens the given string to a length, taking out from the middle
		public static function shortenString(phrase:String,
											 size:int,
											 shortenEnd:Boolean = false):String
		{
			// Remove any un-needed elements
			phrase = phrase.replace("https://", "").replace("http://", "");
			
			if(phrase.length < size)
				return phrase;
			
			var removeChars:int = phrase.length - size + 3;
			if(shortenEnd)
				return phrase.substring(0, size-3) + "...";
			else
			{
				var upTo:int = (phrase.length / 2) - (removeChars / 2);
				return phrase.substring(0, upTo) + "..." +  phrase.substring(upTo + removeChars);
			}
			
		}
		
		public static function makeSureEndsWith(original:String, letter:String):String
		{
			if(original.charAt(original.length-1) != letter)
				return original + letter;
			else
				return original;
		}
		
		public static function notSet(value:String):Boolean
		{
			return value == null || value.length == 0;
		}
		
		public static function getDotString(name:String):String
		{
			return StringUtil.replaceString(StringUtil.replaceString(name, ".", ""), "-", "");
		}
		
		public static function errorToString(e:Error):String
		{
			return Capabilities.isDebugger ? e.getStackTrace() : e.toString()
		}
		
		public static function mhzToString(speed:int):String
		{
			var numberFormatter:NumberFormatter = new NumberFormatter(LocaleID.DEFAULT);
			numberFormatter.fractionalDigits = 2;
			numberFormatter.trailingZeros = false;
			
			if(speed < 1000)
				return speed + " Mhz";
			else
				return numberFormatter.formatNumber(speed/1000) + " Ghz";
		}
		
		public static function mbToString(size:int):String
		{
			var numberFormatter:NumberFormatter = new NumberFormatter(LocaleID.DEFAULT);
			numberFormatter.fractionalDigits = 2;
			numberFormatter.trailingZeros = false;
			
			if(size < 1024)
				return size + " MB";
			else if(size < 1048576)
				return numberFormatter.formatNumber(size/1024) + " GB";
			else
				return numberFormatter.formatNumber(size/1048576) + " TB";
		}
	}
}