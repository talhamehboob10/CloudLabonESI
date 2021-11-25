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
type blob = (Dre.nodeset list * int);;

let initial_metric (hops : int array array)
                           (dest_set : Dre.nodeset) : (Dre.nodeset list * int)  = 
(* For every source: *)
  let add_set (hop_set_list : Dre.nodeset list) (source : int array)
          : Dre.nodeset list =
    let add_hop (dest : int) (hop_set : Dre.nodeset) : Dre.nodeset =
      ((*print_endline "add_hop called"; *) Dre.ISet.add (source.(dest)) hop_set)
    (* Take the union of first hops. *)
    in (Dre.ISet.fold add_hop dest_set Dre.ISet.empty) :: hop_set_list
  in
  let node_list = Array.fold_left add_set [] hops in
  (*
  print_endline ("Node list size " ^ (string_of_int (List.length node_list)));
  print_endline ("  Non-empty sets: " ^ (string_of_int
          ((List.fold_left (fun x s -> (if Dre.ISet.is_empty s then x + 1 else x)))
          0 node_list)));
  print_endline ("Node list size " ^ (string_of_int (List.length node_list)));
  *)
  (node_list, 0);;

let get_metric (data : (Dre.nodeset list * int)) : int =
  match data with
    (_, score) -> score;;

let rec parent_metric (left : Dre.nodeset list)
                  (right : Dre.nodeset list) : (Dre.nodeset list * int) =
  match left with
    []             -> ([], 0)
  | lhead :: ltail -> (match right with
                        []             -> ([], 0)
                      | rhead::rtail ->
  let (res_list, res_score) = (parent_metric ltail rtail) in
  let inter = (Dre.ISet.inter lhead rhead) in
    if (Dre.ISet.is_empty inter)
    then ((Dre.ISet.union lhead rhead)::res_list, res_score)
    else (inter::res_list, res_score + 1));;

let combine_metric (ignore0 : int array array)
                   (ignore1 : Dre.nodeset)
                   (ignore2 : Dre.nodeset)
                   (left : (Dre.nodeset list * int))
                   (right : (Dre.nodeset list * int)) : (Dre.nodeset list * int) =
  let (left_list, left_score) = left in
  let (right_list, right_score) = right in
  parent_metric left_list right_list;;

