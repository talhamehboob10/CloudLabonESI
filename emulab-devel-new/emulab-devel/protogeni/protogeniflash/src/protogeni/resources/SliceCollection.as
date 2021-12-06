package protogeni.resources
{
	import mx.collections.ArrayCollection;
	import mx.collections.Sort;
	import mx.collections.SortField;
	import mx.utils.ObjectUtil;
	
	public class SliceCollection extends ArrayCollection
	{
		public function SliceCollection(source:Array=null)
		{
			super(source);
		}
		
		public function add(s:Slice):void
		{
			this.addItem(s);
			Main.protogeniHandler.dispatchSlicesChanged();
		}
		
		public function getByUrn(urn:String):Slice
		{
			for each(var existing:Slice in this)
			{
				if(existing.urn == urn)
					return existing;
			}
			return null;
		}
		
		public function addOrReplace(s:Slice):void
		{
			for each(var existing:Slice in this)
			{
				if(existing.urn == s.urn)
				{
					existing = s;
					return;
				}
			}
			add(s);
		}
		
		private function compare(slicea:Slice, sliceb:Slice):int {
			return ObjectUtil.compare(slicea.CompareValue(), sliceb.CompareValue());
		}
		
		public function displaySlices():ArrayCollection {
			var ac : ArrayCollection = new ArrayCollection();
			ac.addItem(new Slice());
			for each(var s:Slice in this) {
				if(s.slivers.length > 0)
					ac.addItem(s);
			}
			
			var dataSortField:SortField = new SortField();
			dataSortField.compareFunction = compare;
			
			var sort:Sort = new Sort();
			sort.fields = [dataSortField];
			ac.sort = sort;
			ac.refresh();
			return ac;
		}
	}
}