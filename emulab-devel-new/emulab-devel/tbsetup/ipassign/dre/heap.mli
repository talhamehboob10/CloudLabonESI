(*
 * Copyright (c) 2005-2006 University of Utah and the Flux Group.
 * 
 * {{{EMULAB-LICENSE
 * 
 * This file is part of the Emulab network testbed software.
 * 
 * This file is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or (at
 * your option) any later version.
 * 
 * This file is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
 * License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this file.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * }}}
 *)

(*
 * heap.mli - Interface to the Heap module
 *)

(* The heap itself *)
type 'a heap

(* The infinite weight *)
val inf_weight : int

(* Make a new heap - argument is any value of type 'a *)
val make_heap : 'a -> 'a heap

(* Insert into the heap - the function returned can be used to update
 * the weight of the object, while keeping the heap property *)
val insert : 'a heap -> int -> 'a -> (int -> unit)

val insert_remove : 'a heap -> int -> 'a -> ('b -> unit)

(* Remove the smallest-weighted object from the heap *)
val extract_min : 'a heap -> unit

(* Return the smallest-weighted object, and its weight *)
val min : 'a heap -> (int * 'a)

exception EmptyHeap

val iter : 'a heap -> ('a -> unit) -> unit
val iterw : 'a heap -> (int -> 'a -> unit) -> unit

val size : 'a heap -> int

(* Export a bit more stuff so that we can try a less functional approach
 * to this problem. *)
type 'a heap_data
val insert_obj : 'a heap -> int -> 'a -> 'a heap_data
val update_weight : 'a heap -> 'a heap_data -> int -> unit
