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
 * Name a grapha using a genetic algorithm
 * Copyright 2005 Robert Ricci for the University of Utah
 * ricci@cs.utah.edu, testbed-ops@emulab.net
 *)

type scoring = DreDistance | Transition;;

let maxgen = ref(Some 1000);;
(* let victorygen = ref(Some 10);; *)
let victorygen = ref None;;
let verbose = ref false;;
let inital_conf_file = ref None;;
let graphfile = ref None;;
let which_scoring = ref DreDistance;;

exception NeedArg;;
let argspec =
  [ "-m", Arg.Int (fun m -> maxgen := Some m),
      "Maximum generations";
    "-g", Arg.Int (fun g -> victorygen := Some g),
      "Victory generations"; 
    "-v", Arg.Unit (fun () -> verbose := true),
      "Verbose output";
    "-i", Arg.String (fun i -> inital_conf_file := Some i),
      "Inital configuration";
    "-T", Arg.Unit (fun () -> which_scoring := Transition),
      "Use Transitions scoring";
  ];;

let anonfunc (str : string) : unit =
    match !graphfile with
      None -> graphfile := Some str
    | Some(_) -> raise (Failure "Only one graph file accepted")
;;

Arg.parse argspec anonfunc "TODO: Write a usage message";;

let g = match !graphfile with
Some(s) -> (let (g,_) = Graph.read_subgraph_file s in g)
        | None -> raise NeedArg
in
let hops = Dijkstra.get_all_first_hops g in
let scoring_function = match !which_scoring with
        Transition -> Dijkstra.score_ordering_transitions hops
      | DreDistance -> Dre.score_ordering (Dre.compute_dre hops) in
(* let dre_matrix = Dre.compute_dre hops in *)
let ga_opts = { Ga.default_opts with
    (* Ga.fitness_function = Dre.score_ordering dre_matrix; *)
    Ga.fitness_function =  scoring_function;
    Ga.termination_score = None;
    Ga.max_generations = !maxgen;
    Ga.crossover_pct = 0.60;
    Ga.verbose = !verbose;
    Ga.score_comparator = Pervasives.compare;
    Ga.victory_generations = !victorygen
} in
let initial_individual = match !inital_conf_file with
  None -> Array.init (Array.length hops) (fun x -> x)
| Some(x) -> Naming.ordering_of_naming (Naming.read_naming_file x)
in
let rec make_random_individuals (seed : Ga.individual) (n : int) : Ga.individual list = 
    if n <= 0 then
        []
    else
        Ga.permutation_randomize seed :: make_random_individuals seed (n - 1)
in
let (ordering,_) = Ga.optimize (initial_individual ::
                                make_random_individuals initial_individual 50)
                               ga_opts in
Naming.print_naming (Naming.naming_of_ordering ordering)

