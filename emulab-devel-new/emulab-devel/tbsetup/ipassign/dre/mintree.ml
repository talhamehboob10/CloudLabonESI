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
 * mintree.ml - Algorithms for finding the minimum-height tree from a forest
 * of trees.
 *)

(* Tree we're constructing *)
(* Depth, height, left, right *)
type tree_node = NoNode | TreeNode of (int * int * tree_node * tree_node);;

(* A collection of trees *)
type forest_t = tree_node list;;

(* Maximum depth of a tree *)
let max_depth = 32;;

(* A collection of bins *)
type bins_t = int array;;

(* Caller tried to remove from an empty bin *)
exception EmptyBin;;

(*
 * Add one to a given bin
 *)
let add_to_bin (bins : bins_t) (which : int) : unit =
    (* print_endline ("Bin " ^ (string_of_int which) ^ " incremented to " ^
        (string_of_int (bins.(which) + 1))); *)
    bins.(which) <- bins.(which) + 1
;;

(*
 * Remove one from a given bin
 *)
let remove_from_bin (bins : bins_t) (which : int) : unit =
    (* print_endline ("Bin " ^ (string_of_int which) ^ " decremented to " ^
        (string_of_int (bins.(which) - 1))); *)
    if bins.(which) = 0 then raise EmptyBin;
    bins.(which) <- bins.(which) - 1
;;

(*
 * Make a new set of bins
 *)
let make (size : int) : bins_t =
    Array.make (size + 1) 0
;;

exception TooManyBits;;
(*
 * Find the height of the minimum-height tree from the given set of bins
 *)
let height_of (bins : bins_t) : int =
    (* Make a copy of the bins so we can modify them *)
    let newbins = Array.copy bins in
    let len = Array.length newbins in
    (* This will keep track of how many bit's we've had to use *)
    let bits_used = ref 0 in
    (* Loop for every bin *)
    for i = 0 to len - 1 do
        if newbins.(i) != 0 then (
            let quotient = newbins.(i) / 2 in
            let remainder = newbins.(i) mod 2 in

            (* If we are on a bin that only has one member, then it's
             * possible we're done with the algorithm *)
            let are_done = ref true in
            if (quotient = 0) && (remainder = 1) then (
                (* Look for any later bins that have non-zero values *)
                for j = i + 1 to len - 1 do (
                    if newbins.(j) != 0 then are_done := false;
                ) done;
            ) else (
                (* We can't be done unless we find a one-member bin *)
                are_done := false;
            );
            if !are_done then (
                (* Note, if we're done, we'll continue the outer loop all the
                 * way to the end of the bitspace, but we're guaranteed not to
                 * find anything *)
                bits_used := i
            ) else (
                if (quotient > 0) && (i = len - 1) then (
                    raise TooManyBits
                );
                (* Two trees of this height can be replaced with one of the next
                 * height *)
                newbins.(i + 1) <- newbins.(i + 1) + quotient;
                (* If there's a leftover, we 'promote' it to the next height,
                 * where it'll get combined with some larger subtree *)
                if (remainder != 0) then (
                    newbins.(i + 1) <- newbins.(i + 1) + remainder
                );
                (* Okay, done with this bin *)
                newbins.(i) <- 0
            )
        ) else (
            (* We don't have to do anything to empty bins *)
            ()
        )
    done;
    (* Return the number of bits used *)
    !bits_used
;;

(*
 * Tests
 *)
(*
let mybins = make 32;;
add_to_bin mybins 1;;
add_to_bin mybins 1;;
add_to_bin mybins 1;;
add_to_bin mybins 4;;
add_to_bin mybins 4;;
add_to_bin mybins 4;;
print_endline (string_of_int (height_of  mybins));
*)

(* Given a set of subtrees, find the minimum depth tree *)
let min_depth_tree (forest : forest_t) : tree_node =
    (* Fill up a heap with the heights of the trees as they keys - smallest
     * first *)
    let rec init_heap (forest : forest_t) (heap : tree_node Heap.heap) : unit =
        match forest with
          [] -> ()
        | h :: tail -> match h with
              TreeNode(depth,height,left,right) -> (
                  let _ = Heap.insert heap height h in
                init_heap tail heap
               )
             | NoNode -> raise (Failure "Empty node in forest")
    in
    let heap = Heap.make_heap NoNode in
    init_heap forest heap;
    while (Heap.size heap > 1) do
        let (height1,tree1) = Heap.min heap in
        Heap.extract_min heap;
        let (height2,tree2) = Heap.min heap in
        Heap.extract_min heap;
        let newheight = (max height1 height2) + 1 in
        (*
        print_endline ("Combining h1 = " ^ (string_of_int height1) ^
            " and h2 = " ^ (string_of_int height2) ^ " to get " ^ (string_of_int
            newheight));*)
        (* XXX Putting in a bogus ID, since it doesn't actually matter *)
        let newroot = TreeNode(0,newheight,tree1,tree2) in
        let _ = Heap.insert heap newheight newroot in
        ()
    done;
    let (_,root) = Heap.min heap in
    root
;;
