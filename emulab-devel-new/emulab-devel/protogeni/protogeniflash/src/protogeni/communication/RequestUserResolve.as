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
  import flash.events.SecurityErrorEvent;
  import protogeni.resources.Slice;

  public class RequestUserResolve extends Request
  {
    public function RequestUserResolve() : void
    {
		super("UserResolve", "Resolve user", CommunicationUtil.resolve);
		op.addField("type", "User");
		op.setUrl("https://boss.emulab.net:443/protogeni/xmlrpc");
    }
	
	override public function start():Operation
	{
		op.addField("credential", Main.protogeniHandler.CurrentUser.credential);
		op.addField("hrn", Main.protogeniHandler.CurrentUser.urn);
		return op;
	}
	
	override public function complete(code : Number, response : Object) : *
	{
		var newCalls:RequestQueue = new RequestQueue();
		if (code == CommunicationUtil.GENIRESPONSE_SUCCESS)
		{
			Main.protogeniHandler.CurrentUser.uid = response.value.uid;
			Main.protogeniHandler.CurrentUser.hrn = response.value.hrn;
			Main.protogeniHandler.CurrentUser.uuid = response.value.uuid;
			Main.protogeniHandler.CurrentUser.email = response.value.email;
			Main.protogeniHandler.CurrentUser.name = response.value.name;
			
			var slices:Array = response.value.slices;
			if(slices != null && slices.length > 0) {
				for each(var sliceUrn:String in slices)
				{
					var userSlice:Slice = new Slice();
					userSlice.urn = sliceUrn;
					Main.protogeniHandler.CurrentUser.slices.add(userSlice);
					newCalls.push(new RequestSliceResolve(userSlice));
				}
			}
			
			Main.protogeniHandler.dispatchUserChanged();
			Main.protogeniHandler.mapHandler.drawAll();
		}
		else
		{
			Main.protogeniHandler.rpcHandler.codeFailure(name, "Recieved GENI response other than success");
		}
		
		return newCalls.head;
	}
  }
}
