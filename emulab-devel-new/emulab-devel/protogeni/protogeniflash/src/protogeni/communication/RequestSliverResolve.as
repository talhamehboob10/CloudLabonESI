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
	import protogeni.resources.Slice;
	import protogeni.resources.Sliver;

  public class RequestSliverResolve extends Request
  {
    public function RequestSliverResolve(s:Sliver) : void
    {
		super("SliverResolve", "Resolving sliver on " + s.componentManager.Hrn + " on slice named " + s.slice.hrn, CommunicationUtil.resolveResource, true);
		sliver = s;
		op.addField("urn", sliver.urn);
		op.addField("credentials", new Array(sliver.credential));
		op.setExactUrl(sliver.componentManager.Url);
    }

	override public function complete(code : Number, response : Object) : *
	{
		if (code == CommunicationUtil.GENIRESPONSE_SUCCESS)
		{
			sliver.rspec = new XML(response.value.manifest);
			sliver.created = true;
			sliver.parseRspec();
			Main.protogeniHandler.dispatchSliceChanged(sliver.slice);
			return new RequestSliverStatus(sliver);
		}
		else
		{
			// do nothing
		}
		
		return null;
	}
	
	private var sliver:Sliver;
  }
}
