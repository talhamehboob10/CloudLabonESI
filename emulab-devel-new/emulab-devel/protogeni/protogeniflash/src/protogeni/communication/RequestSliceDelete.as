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
	import mx.controls.Alert;
	
	import protogeni.resources.Slice;
	import protogeni.resources.Sliver;

  public class RequestSliceDelete extends Request
  {
    public function RequestSliceDelete(s:Slice) : void
    {
		super("SliceDelete", "Deleting slice named " + s.hrn, CommunicationUtil.deleteSlice);
		slice = s;
		op.addField("slice_urn", slice.urn);
		op.addField("credential", Main.protogeniHandler.CurrentUser.credential);
		// What CM???
    }
	
	override public function complete(code : Number, response : Object) : *
	{
		if (code == CommunicationUtil.GENIRESPONSE_SUCCESS || code == CommunicationUtil.GENIRESPONSE_SEARCHFAILED)
		{
			//??
		}
		else
		{
			//??
		}
	}

    private var slice : Slice;
  }
}
