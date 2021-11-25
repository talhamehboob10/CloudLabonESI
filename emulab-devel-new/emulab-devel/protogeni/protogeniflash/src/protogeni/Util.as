/*
 * Copyright (c) 2008, 2009 University of Utah and the Flux Group.
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

package protogeni
{
  import flash.external.ExternalInterface;
  import flash.net.*;
  
  import mx.collections.ArrayCollection;
  import mx.formatters.NumberBaseRoundType;
  import mx.formatters.NumberFormatter;

  public class Util
  {
	  public static function showSetup():void
	  {
		  navigateToURL(new URLRequest("https://www.protogeni.net/trac/protogeni/wiki/MapClientManual#Setup"), "_blank");
	  }
	  public static function showManual():void
	  {
		  navigateToURL(new URLRequest("https://www.protogeni.net/trac/protogeni/wiki/MapClientManual"), "_blank");
	  }
	  
	  public static function openWebsite(url:String):void
	  {
		  navigateToURL(new URLRequest(url), "_blank");
	  }
	  
    public static function makeUrn(authority : String,
                                   type : String,
                                   name : String) : String
    {
      return "urn:publicid:IDN+" + authority + "+" + type + "+" + name;
    }
	
	// Takes the given bandwidth and creates a human readable string
	public static function kbsToString(bandwidth:Number):String {
		var bw:String = "";
		if(bandwidth < 1000) {
			return bandwidth + " Kb\\s"
		} else if(bandwidth < 1000000) {
			return bandwidth / 1000 + " Mb\\s"
		} else if(bandwidth < 1000000000) {
			return bandwidth / 1000000 + " Gb\\s"
		}
		return bw;
	}
	
	// Makes the first letter uppercase
	public static function firstToUpper (phrase : String) : String {
		return phrase.substring(1, 0).toUpperCase()+phrase.substring(1);
	}
	
	public static function replaceString(original:String, find:String, replace:String):String {
		return original.split(find).join(replace);
	}
	
	public static function getDotString(name : String) : String {
		return replaceString(replaceString(name, ".", ""), "-", "");
	}
	
	public static function parseProtogeniDate(value:String):Date
	{
		var dateString:String = value;
		dateString = dateString.replace(/(\d{4,4})\-(\d{2,2})\-(\d{2,2})/g, "$1/$2/$3");
		dateString = dateString.replace("T", " ");
		dateString = dateString.replace(/(\+|\-)(\d+):(\d+)/g, " GMT$1$2$3");
		dateString = dateString.replace("Z", " GMT-0000");
		return new Date(Date.parse(dateString));
	}
	
	public static function addIfNonexistingToArray(source:Array, o:*):void
	{
		if(source.indexOf(o) == -1)
			source.push(o);
	}
	
	public static function addIfNonexistingToArrayCollection(source:ArrayCollection, o:*):void
	{
		if(source.getItemIndex(o) == -1)
			source.addItem(o);
	}
	
	public static function findInAny(text:Array, candidates:Array, matchAll:Boolean = false, caseSensitive:Boolean = false):Boolean
	{
		if(!caseSensitive)
		{
			for each(var textTemp:String in text)
			textTemp = textTemp.toLowerCase();
		}
			
		for each(var candidate:String in candidates)
		{
			if(!caseSensitive)
				candidate = candidate.toLowerCase();
			for each(var s:String in text)
			{
				
				if(matchAll)
				{
					if(candidate == s)
						return true;
				}
				else
				{
					if(candidate.indexOf(s) > -1)
						return true;
				}
			}
			
		}
		return false;
	}
	
	// Shortens the given string to a length, taking out from the middle
	public static function shortenString(phrase : String, size : int) : String {
		if(phrase.length < size)
			return phrase;
		
		var removeChars:int = phrase.length - size + 3;
		var upTo:int = (phrase.length / 2) - (removeChars / 2);
		return phrase.substring(0, upTo) + "..." +  phrase.substring(upTo + removeChars);
	}
	
	public static  function getBrowserName():String
	{
		var browser:String;
		var browserAgent:String = ExternalInterface.call("function getBrowser(){return navigator.userAgent;}");
		
		if(browserAgent == null)
			return "Undefined";
		else if(browserAgent.indexOf("Firefox") >= 0)
			browser = "Firefox";
		else if(browserAgent.indexOf("Safari") >= 0)
			browser = "Safari";
		else if(browserAgent.indexOf("MSIE") >= 0)
			browser = "IE";
		else if(browserAgent.indexOf("Opera") >= 0)
			browser = "Opera";
		else
			browser = "Undefined";
		
		return (browser);
	}
	
	public static function keepUniqueObjects(ac:ArrayCollection, oc:ArrayCollection = null):ArrayCollection
	{
		var newAc:ArrayCollection;
		if(oc != null)
			newAc = oc;
		else
			newAc = new ArrayCollection();
		for each(var o:Object in ac) {
			if(o is ArrayCollection)
				newAc = keepUniqueObjects((o as ArrayCollection), newAc);
			else {
				if(!newAc.contains(o))
					newAc.addItem(o);
			}
		}
		return newAc;
	}
  }
}
