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

package protogeni.communication
{
	import flash.events.ErrorEvent;
	
	public class RequestGetKeys extends Request
	{
		public function RequestGetKeys() : void
		{
			super("GetKeys", "Getting the ssh credential", CommunicationUtil.getKeys);
		}
		
		override public function start():Operation
		{
			op.addField("credential",Main.protogeniHandler.CurrentUser.credential);
			return op;
		}
		
		override public function complete(code : Number, response : Object) : *
		{
			if (code == CommunicationUtil.GENIRESPONSE_SUCCESS)
			{
				Main.protogeniHandler.CurrentUser.keys = response.value;
				Main.protogeniHandler.dispatchUserChanged();
			}
			else
			{
				Main.protogeniHandler.rpcHandler.codeFailure(name, "Recieved GENI response other than success");
			}
			
			return null;
		}
	}
}
