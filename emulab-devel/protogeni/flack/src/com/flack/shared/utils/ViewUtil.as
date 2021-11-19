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
	import com.flack.shared.display.areas.AboutArea;
	import com.flack.shared.display.areas.Area;
	import com.flack.shared.display.areas.AreaContent;
	import com.flack.shared.display.areas.LogMessageArea;
	import com.flack.shared.display.components.DataButton;
	import com.flack.shared.display.windows.DefaultWindow;
	import com.flack.shared.display.windows.DocumentWindow;
	import com.flack.shared.display.windows.MultiDocumentWindow;
	import com.flack.shared.logging.LogMessage;
	
	import spark.components.Label;
	
	/**
	 * Common functions for GUI stuff
	 * 
	 * @author mstrum
	 * 
	 */
	public final class ViewUtil
	{
		public static const windowHeight:int = 400;
		public static const windowWidth:int = 700;
		public static const minComponentHeight:int = 24;
		public static const minComponentWidth:int = 24;
		
		public static function assignIcon(val:Boolean):Class
		{
			if (val)
				return ImageUtil.availableIcon;
			else
				return ImageUtil.crossIcon;
		}
		
		// Get labels
		public static function getLabel(text:String, bold:Boolean = false, fontSize:Number = NaN):Label
		{
			var l:Label = new Label();
			l.text = text;
			if(bold)
				l.setStyle("fontWeight", "bold");
			if(fontSize)
				l.setStyle("fontSize", fontSize);
			return l;
		}
		
		public static function viewDocument(document:String, title:String):void
		{
			var documentView:DocumentWindow = new DocumentWindow();
			documentView.title = title;
			documentView.Document = document;
			documentView.showWindow();
		}
		
		public static function viewDocuments(documents:Array, title:String):void
		{
			var documentsView:MultiDocumentWindow = new MultiDocumentWindow();
			documentsView.title = title;
			for each(var docInfo:Object in documents)
				documentsView.addDocument(docInfo.title, docInfo.document);
			documentsView.showWindow();
		}
		
		public static function getButtonFor(data:*):DataButton
		{
			if(data is LogMessage)
				return ViewUtil.getLogMessageButton(data);
			return null;
		}
		
		public static function getLogMessageButton(msg:LogMessage, handleClick:Boolean = true, useShortestMessage:Boolean = false):DataButton
		{
			var img:Class;
			if(msg.level != LogMessage.LEVEL_INFO)
				img = ImageUtil.errorIcon;
			else
				img = ImageUtil.rightIcon;
			
			var logButton:DataButton = new DataButton(
				useShortestMessage ? msg.ShortestTitle : msg.Title,
				StringUtil.shortenString(msg.message, 80, true),
				img,
				handleClick ? msg : null
			);
			logButton.data = msg;
			if(msg.level == LogMessage.LEVEL_FAIL)
				logButton.styleName = "failedStyle";
			else if(msg.level == LogMessage.LEVEL_WARNING)
				logButton.styleName = "inprogressStyle";
			
			return logButton;
		}
		
		public static function viewContentInWindow(content:AreaContent):void
		{
			var area:Area = new Area();
			var window:DefaultWindow = new DefaultWindow();
			area.window = window;
			window.title = content.title;
			window.showWindow();
			window.addElement(area);
			area.Root = content;
		}
		
		public static function viewLogMessage(msg:LogMessage):void
		{
			var msgWindow:LogMessageArea = new LogMessageArea();
			msgWindow.Message = msg;
			viewContentInWindow(msgWindow);
		}
		
		public static function viewAbout():void
		{
			var area:Area = new Area();
			var subarea:AboutArea = new AboutArea();
			var window:DefaultWindow = new DefaultWindow();
			window.maxHeight = 400;
			window.maxWidth = 600;
			area.window = window;
			window.title = subarea.title;
			window.showWindow();
			window.addElement(area);
			area.Root = subarea;
		}
	}
}