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
 * naming.ml
 * Definition of, and functions to read, a naming for a graph
 *)

type naming = int array;;
type ordering = int array;;

let read_naming_file (filename : string) : naming =
    let channel = open_in filename in
    (*
     * This is ridiculously inefficient, but to get much better, we'd need a
     * better file format
     *)
    let rec get_naming () : naming =
        try
            let line = input_line channel in
            let value = int_of_string line in
            Array.append [| value |] (get_naming ())
        with
            End_of_file -> [| |]
    in
    get_naming ()
;;

let naming_of_ordering(order : ordering) : naming =
    let names = Array.make (Array.length order) 0 in
    Array.iteri (fun ind cont -> names.(cont) <- ind) order;
    names
;;

let ordering_of_naming (names : naming) : ordering =
    (* Actually the same operation as naming_from_ordering *)
    naming_of_ordering names
;;

let print_naming (names : naming) : unit =
    Array.iter (fun x -> print_endline (string_of_int x)) names
;;
