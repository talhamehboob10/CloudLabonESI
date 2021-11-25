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
 * Histogram utility functions
 *)

type elt = { min : float; count : int };;

type t = elt list;;

let rec print_histogram (hist : t) : unit =
    match hist with
      [] -> ()
    | x::xs -> (Printf.printf "%0.4f\t%i\n" x.min x.count; print_histogram xs)
;;

let rec empty_histogram (l : float list) : t =
    match l with
      [] -> []
    | x::xs -> { min = x; count = 0 } :: empty_histogram xs
;;
(* empty_histogram [1.0; 0.5; 0.0];; *)

let rec insert_item (elt : float) (l : t) : t =
    match l with
      [] -> raise (Failure "No place in list for elt")
    | x::xs when elt >= x.min ->
            { min = x.min; count = (x.count + 1) } :: xs
    | x::xs -> x :: insert_item elt xs
;;
(*
insert_item 0.75 (empty_histogram [1.0; 0.5; 0.0]);;
insert_item 0.0 (empty_histogram [1.0; 0.5; 0.0]);;
insert_item 1.0 (empty_histogram [1.0; 0.5; 0.0]);;
*)

let rec fixed_size_steps (low : float) (step : float) (steps : int) : float list =
    if steps = 0 then
        []
    else
        low :: fixed_size_steps (low +. step) step (steps - 1)
;;
(*
fixed_size_steps 0.0 0.1 10;;
fixed_size_steps 0.5 0.25 3;;
*)

let steps_in_range (low : float) (high: float) (steps : int) : float list =
    let step_size = (low +. high) /. (float_of_int (steps -1)) -. low in
    fixed_size_steps low step_size steps
;;
(*
steps_in_range 0.0 1.0 11;;
steps_in_range 0.5 1.0 3;;
*)

let make_histogram (l : float list) (bins : float list) : t =
    let sbins = List.fast_sort (fun x y -> compare y x) bins in
    let rec insert_helper (elts : float list) (accum : t) : t = 
        match elts with
          [] -> accum
        | x::xs -> insert_helper xs (insert_item x accum) in
    insert_helper l (empty_histogram sbins)
;;
(*
make_histogram [1.0; 0.75; 0.5; 0.25; 0.0] [0.5; 0.0];;
make_histogram [1.0; 0.75; 0.5; 0.25; 0.0] [0.0; 1.0];;
print_histogram (make_histogram [1.0; 0.75; 0.5; 0.25; 0.0] [0.5; 0.0]);;
*)
