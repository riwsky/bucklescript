module OUnitTypes
= struct
#1 "oUnitTypes.ml"

(**
  * Commont types for OUnit
  *
  * @author Sylvain Le Gall
  *
  *)

(** See OUnit.mli. *) 
type node = ListItem of int | Label of string

(** See OUnit.mli. *) 
type path = node list 

(** See OUnit.mli. *) 
type log_severity = 
  | LError
  | LWarning
  | LInfo

(** See OUnit.mli. *) 
type test_result =
  | RSuccess of path
  | RFailure of path * string
  | RError of path * string
  | RSkip of path * string
  | RTodo of path * string

(** See OUnit.mli. *) 
type test_event =
  | EStart of path
  | EEnd of path
  | EResult of test_result
  | ELog of log_severity * string
  | ELogRaw of string

(** Events which occur at the global level. *)
type global_event =
  | GStart  (** Start running the tests. *)
  | GEnd    (** Finish running the tests. *)
  | GResults of (float * test_result list * int)

(* The type of test function *)
type test_fun = unit -> unit 

(* The type of tests *)
type test = 
  | TestCase of test_fun
  | TestList of test list
  | TestLabel of string * test

type state = 
    {
      tests_planned : (path * (unit -> unit)) list;
      results : test_result list;
    }


end
module OUnitChooser
= struct
#1 "oUnitChooser.ml"


(**
    Heuristic to pick a test to run.
   
    @author Sylvain Le Gall
  *)

open OUnitTypes

(** Most simple heuristic, just pick the first test. *)
let simple state =
  (* 477 *) List.hd state.tests_planned

end
module OUnitUtils
= struct
#1 "oUnitUtils.ml"

(**
  * Utilities for OUnit
  *
  * @author Sylvain Le Gall
  *)

open OUnitTypes

let is_success = 
  function
    | RSuccess _  -> (* 0 *) true 
    | RFailure _ | RError _  | RSkip _ | RTodo _ -> (* 0 *) false 

let is_failure = 
  function
    | RFailure _ -> (* 4 *) true
    | RSuccess _ | RError _  | RSkip _ | RTodo _ -> (* 950 *) false

let is_error = 
  function 
    | RError _ -> (* 0 *) true
    | RSuccess _ | RFailure _ | RSkip _ | RTodo _ -> (* 954 *) false

let is_skip = 
  function
    | RSkip _ -> (* 0 *) true
    | RSuccess _ | RFailure _ | RError _  | RTodo _ -> (* 954 *) false

let is_todo = 
  function
    | RTodo _ -> (* 0 *) true
    | RSuccess _ | RFailure _ | RError _  | RSkip _ -> (* 954 *) false

let result_flavour = 
  function
    | RError _ -> (* 0 *) "Error"
    | RFailure _ -> (* 4 *) "Failure"
    | RSuccess _ -> (* 0 *) "Success"
    | RSkip _ -> (* 0 *) "Skip"
    | RTodo _ -> (* 0 *) "Todo"

let result_path = 
  function
    | RSuccess path 
    | RError (path, _)
    | RFailure (path, _)
    | RSkip (path, _)
    | RTodo (path, _) -> (* 4 *) path

let result_msg = 
  function
    | RSuccess _ -> (* 0 *) "Success"
    | RError (_, msg)
    | RFailure (_, msg)
    | RSkip (_, msg)
    | RTodo (_, msg) -> (* 4 *) msg

(* Returns true if the result list contains successes only. *)
let rec was_successful = 
  function
    | [] -> (* 3 *) true
    | RSuccess _::t 
    | RSkip _::t -> 
        (* 561 *) was_successful t

    | RFailure _::_
    | RError _::_ 
    | RTodo _::_ -> 
        (* 6 *) false

let string_of_node = 
  function
    | ListItem n -> 
        (* 1916 *) string_of_int n
    | Label s -> 
        (* 2874 *) s

(* Return the number of available tests *)
let rec test_case_count = 
  function
    | TestCase _ -> (* 477 *) 1 
    | TestLabel (_, t) -> (* 546 *) test_case_count t
    | TestList l -> 
        (* 69 *) List.fold_left 
          (fun c t -> (* 543 *) c + test_case_count t) 
          0 l

let string_of_path path =
  (* 958 *) String.concat ":" (List.rev_map string_of_node path)

let buff_format_printf f = 
  (* 0 *) let buff = Buffer.create 13 in
  let fmt = Format.formatter_of_buffer buff in
    f fmt;
    Format.pp_print_flush fmt ();
    Buffer.contents buff

(* Applies function f in turn to each element in list. Function f takes
   one element, and integer indicating its location in the list *)
let mapi f l = 
  (* 0 *) let rec rmapi cnt l = 
    (* 0 *) match l with 
      | [] -> 
          (* 0 *) [] 

      | h :: t -> 
          (* 0 *) (f h cnt) :: (rmapi (cnt + 1) t) 
  in
    rmapi 0 l

let fold_lefti f accu l =
  (* 69 *) let rec rfold_lefti cnt accup l = 
    (* 612 *) match l with
      | [] -> 
          (* 69 *) accup

      | h::t -> 
          (* 543 *) rfold_lefti (cnt + 1) (f accup h cnt) t
  in
    rfold_lefti 0 accu l

end
module OUnitLogger
= struct
#1 "oUnitLogger.ml"
(*
 * Logger for information and various OUnit events.
 *)

open OUnitTypes
open OUnitUtils

type event_type = GlobalEvent of global_event | TestEvent of test_event

let format_event verbose event_type =
  (* 2868 *) match event_type with
    | GlobalEvent e ->
        (* 6 *) begin
          match e with 
            | GStart ->
                (* 0 *) ""
            | GEnd ->
                (* 0 *) ""
            | GResults (running_time, results, test_case_count) -> 
                (* 6 *) let separator1 = String.make (Format.get_margin ()) '=' in
                let separator2 = String.make (Format.get_margin ()) '-' in
                let buf = Buffer.create 1024 in
                let bprintf fmt = (* 25 *) Printf.bprintf buf fmt in
                let print_results = 
                  List.iter 
                    (fun result -> 
                       (* 4 *) bprintf "%s\n%s: %s\n\n%s\n%s\n" 
                         separator1 
                         (result_flavour result) 
                         (string_of_path (result_path result)) 
                         (result_msg result) 
                         separator2)
                in
                let errors   = List.filter is_error results in
                let failures = List.filter is_failure results in
                let skips    = List.filter is_skip results in
                let todos    = List.filter is_todo results in

                  if not verbose then
                    (* 3 *) bprintf "\n";

                  print_results errors;
                  print_results failures;
                  bprintf "Ran: %d tests in: %.2f seconds.\n" 
                    (List.length results) running_time;

                  (* Print final verdict *)
                  if was_successful results then 
                    (* 2 *) begin
                      if skips = [] then
                        (* 2 *) bprintf "OK"
                      else 
                        (* 0 *) bprintf "OK: Cases: %d Skip: %d"
                          test_case_count (List.length skips)
                    end
                  else
                    (* 4 *) begin
                      bprintf
                        "FAILED: Cases: %d Tried: %d Errors: %d \
                              Failures: %d Skip:%d Todo:%d" 
                        test_case_count (List.length results) 
                        (List.length errors) (List.length failures)
                        (List.length skips) (List.length todos);
                    end;
                  bprintf "\n";
                  Buffer.contents buf
        end

    | TestEvent e ->
        (* 2862 *) begin
          let string_of_result = 
            if verbose then
              (* 1431 *) function
                | RSuccess _      -> (* 475 *) "ok\n"
                | RFailure (_, _) -> (* 2 *) "FAIL\n"
                | RError (_, _)   -> (* 0 *) "ERROR\n"
                | RSkip (_, _)    -> (* 0 *) "SKIP\n"
                | RTodo (_, _)    -> (* 0 *) "TODO\n"
            else
              (* 1431 *) function
                | RSuccess _      -> (* 475 *) "."
                | RFailure (_, _) -> (* 2 *) "F"
                | RError (_, _)   -> (* 0 *) "E"
                | RSkip (_, _)    -> (* 0 *) "S"
                | RTodo (_, _)    -> (* 0 *) "T"
          in
            if verbose then
              (* 1431 *) match e with 
                | EStart p -> 
                    (* 477 *) Printf.sprintf "%s start\n" (string_of_path p)
                | EEnd p -> 
                    (* 477 *) Printf.sprintf "%s end\n" (string_of_path p)
                | EResult result -> 
                    (* 477 *) string_of_result result
                | ELog (lvl, str) ->
                    (* 0 *) let prefix = 
                      match lvl with 
                        | LError -> (* 0 *) "E"
                        | LWarning -> (* 0 *) "W"
                        | LInfo -> (* 0 *) "I"
                    in
                      prefix^": "^str
                | ELogRaw str ->
                    (* 0 *) str
            else 
              (* 1431 *) match e with 
                | EStart _ | EEnd _ | ELog _ | ELogRaw _ -> (* 954 *) ""
                | EResult result -> (* 477 *) string_of_result result
        end

let file_logger fn =
  (* 3 *) let chn = open_out fn in
    (fun ev ->
       (* 1434 *) output_string chn (format_event true ev);
       flush chn),
    (fun () -> (* 3 *) close_out chn)

let std_logger verbose =
  (* 3 *) (fun ev -> 
     (* 1434 *) print_string (format_event verbose ev);
     flush stdout),
  (fun () -> (* 3 *) ())

let null_logger =
  ignore, ignore

let create output_file_opt verbose (log,close) =
  (* 3 *) let std_log, std_close = std_logger verbose in
  let file_log, file_close = 
    match output_file_opt with 
      | Some fn ->
          (* 3 *) file_logger fn
      | None ->
          (* 0 *) null_logger
  in
    (fun ev ->
       (* 1434 *) std_log ev; file_log ev; log ev),
    (fun () ->
       (* 3 *) std_close (); file_close (); close ())

let printf log fmt =
  (* 0 *) Printf.ksprintf
    (fun s ->
       (* 0 *) log (TestEvent (ELogRaw s)))
    fmt

end
module OUnit : sig 
#1 "oUnit.mli"
(***********************************************************************)
(* The OUnit library                                                   *)
(*                                                                     *)
(* Copyright (C) 2002-2008 Maas-Maarten Zeeman.                        *)
(* Copyright (C) 2010 OCamlCore SARL                                   *)
(*                                                                     *)
(* See LICENSE for details.                                            *)
(***********************************************************************)

(** Unit test building blocks
 
    @author Maas-Maarten Zeeman
    @author Sylvain Le Gall
  *)

(** {2 Assertions} 

    Assertions are the basic building blocks of unittests. *)

(** Signals a failure. This will raise an exception with the specified
    string. 

    @raise Failure signal a failure *)
val assert_failure : string -> 'a

(** Signals a failure when bool is false. The string identifies the 
    failure.
    
    @raise Failure signal a failure *)
val assert_bool : string -> bool -> unit

(** Shorthand for assert_bool 

    @raise Failure to signal a failure *)
val ( @? ) : string -> bool -> unit

(** Signals a failure when the string is non-empty. The string identifies the
    failure. 
    
    @raise Failure signal a failure *) 
val assert_string : string -> unit

(** [assert_command prg args] Run the command provided.

    @param exit_code expected exit code
    @param sinput provide this [char Stream.t] as input of the process
    @param foutput run this function on output, it can contains an
                   [assert_equal] to check it
    @param use_stderr redirect [stderr] to [stdout]
    @param env Unix environment
    @param verbose if a failure arise, dump stdout/stderr of the process to stderr

    @since 1.1.0
  *)
val assert_command : 
    ?exit_code:Unix.process_status ->
    ?sinput:char Stream.t ->
    ?foutput:(char Stream.t -> unit) ->
    ?use_stderr:bool ->
    ?env:string array ->
    ?verbose:bool ->
    string -> string list -> unit

(** [assert_equal expected real] Compares two values, when they are not equal a
    failure is signaled.

    @param cmp customize function to compare, default is [=]
    @param printer value printer, don't print value otherwise
    @param pp_diff if not equal, ask a custom display of the difference
                using [diff fmt exp real] where [fmt] is the formatter to use
    @param msg custom message to identify the failure

    @raise Failure signal a failure 
    
    @version 1.1.0
  *)
val assert_equal : 
  ?cmp:('a -> 'a -> bool) ->
  ?printer:('a -> string) -> 
  ?pp_diff:(Format.formatter -> ('a * 'a) -> unit) ->
  ?msg:string -> 'a -> 'a -> unit

(** Asserts if the expected exception was raised. 
   
    @param msg identify the failure

    @raise Failure description *)
val assert_raises : ?msg:string -> exn -> (unit -> 'a) -> unit

val assert_raise_any : ?msg:string ->  (unit -> 'a) -> unit

(** {2 Skipping tests } 
  
   In certain condition test can be written but there is no point running it, because they
   are not significant (missing OS features for example). In this case this is not a failure
   nor a success. Following functions allow you to escape test, just as assertion but without
   the same error status.
  
   A test skipped is counted as success. A test todo is counted as failure.
  *)

(** [skip cond msg] If [cond] is true, skip the test for the reason explain in [msg].
    For example [skip_if (Sys.os_type = "Win32") "Test a doesn't run on windows"].
    
    @since 1.0.3
  *)
val skip_if : bool -> string -> unit

(** The associated test is still to be done, for the reason given.
    
    @since 1.0.3
  *)
val todo : string -> unit

(** {2 Compare Functions} *)

(** Compare floats up to a given relative error. 
    
    @param epsilon if the difference is smaller [epsilon] values are equal
  *)
val cmp_float : ?epsilon:float -> float -> float -> bool

(** {2 Bracket}

    A bracket is a functional implementation of the commonly used
    setUp and tearDown feature in unittests. It can be used like this:

    ["MyTestCase" >:: (bracket test_set_up test_fun test_tear_down)] 
    
  *)

(** [bracket set_up test tear_down] The [set_up] function runs first, then
    the [test] function runs and at the end [tear_down] runs. The 
    [tear_down] function runs even if the [test] failed and help to clean
    the environment.
  *)
val bracket: (unit -> 'a) -> ('a -> unit) -> ('a -> unit) -> unit -> unit

(** [bracket_tmpfile test] The [test] function takes a temporary filename
    and matching output channel as arguments. The temporary file is created
    before the test and removed after the test.

    @param prefix see [Filename.open_temp_file]
    @param suffix see [Filename.open_temp_file]
    @param mode see [Filename.open_temp_file]
    
    @since 1.1.0
  *)
val bracket_tmpfile: 
  ?prefix:string -> 
  ?suffix:string -> 
  ?mode:open_flag list ->
  ((string * out_channel) -> unit) -> unit -> unit 

(** {2 Constructing Tests} *)

(** The type of test function *)
type test_fun = unit -> unit

(** The type of tests *)
type test =
    TestCase of test_fun
  | TestList of test list
  | TestLabel of string * test

(** Create a TestLabel for a test *)
val (>:) : string -> test -> test

(** Create a TestLabel for a TestCase *)
val (>::) : string -> test_fun -> test

(** Create a TestLabel for a TestList *)
val (>:::) : string -> test list -> test

(** Some shorthands which allows easy test construction.

   Examples:

   - ["test1" >: TestCase((fun _ -> ()))] =>  
   [TestLabel("test2", TestCase((fun _ -> ())))]
   - ["test2" >:: (fun _ -> ())] => 
   [TestLabel("test2", TestCase((fun _ -> ())))]
   - ["test-suite" >::: ["test2" >:: (fun _ -> ());]] =>
   [TestLabel("test-suite", TestSuite([TestLabel("test2", TestCase((fun _ -> ())))]))]
*)

(** [test_decorate g tst] Apply [g] to test function contains in [tst] tree.
    
    @since 1.0.3
  *)
val test_decorate : (test_fun -> test_fun) -> test -> test

(** [test_filter paths tst] Filter test based on their path string representation. 
    
    @param skip] if set, just use [skip_if] for the matching tests.
    @since 1.0.3
  *)
val test_filter : ?skip:bool -> string list -> test -> test option

(** {2 Retrieve Information from Tests} *)

(** Returns the number of available test cases *)
val test_case_count : test -> int

(** Types which represent the path of a test *)
type node = ListItem of int | Label of string
type path = node list (** The path to the test (in reverse order). *)

(** Make a string from a node *)
val string_of_node : node -> string

(** Make a string from a path. The path will be reversed before it is 
    tranlated into a string *)
val string_of_path : path -> string

(** Returns a list with paths of the test *)
val test_case_paths : test -> path list

(** {2 Performing Tests} *)

(** Severity level for log. *) 
type log_severity = 
  | LError
  | LWarning
  | LInfo

(** The possible results of a test *)
type test_result =
    RSuccess of path
  | RFailure of path * string
  | RError of path * string
  | RSkip of path * string
  | RTodo of path * string

(** Events which occur during a test run. *)
type test_event =
    EStart of path                (** A test start. *)
  | EEnd of path                  (** A test end. *)
  | EResult of test_result        (** Result of a test. *)
  | ELog of log_severity * string (** An event is logged in a test. *)
  | ELogRaw of string             (** Print raw data in the log. *)

(** Perform the test, allows you to build your own test runner *)
val perform_test : (test_event -> 'a) -> test -> test_result list

(** A simple text based test runner. It prints out information
    during the test. 

    @param verbose print verbose message
  *)
val run_test_tt : ?verbose:bool -> test -> test_result list

(** Main version of the text based test runner. It reads the supplied command 
    line arguments to set the verbose level and limit the number of test to 
    run.
    
    @param arg_specs add extra command line arguments
    @param set_verbose call a function to set verbosity

    @version 1.1.0
  *)
val run_test_tt_main : 
    ?arg_specs:(Arg.key * Arg.spec * Arg.doc) list -> 
    ?set_verbose:(bool -> unit) -> 
    test -> test_result list

end = struct
#1 "oUnit.ml"
(***********************************************************************)
(* The OUnit library                                                   *)
(*                                                                     *)
(* Copyright (C) 2002-2008 Maas-Maarten Zeeman.                        *)
(* Copyright (C) 2010 OCamlCore SARL                                   *)
(*                                                                     *)
(* See LICENSE for details.                                            *)
(***********************************************************************)

open OUnitUtils
include OUnitTypes

(*
 * Types and global states.
 *)

let global_verbose = ref false

let global_output_file = 
  let pwd = Sys.getcwd () in
  let ocamlbuild_dir = Filename.concat pwd "_build" in
  let dir = 
    if Sys.file_exists ocamlbuild_dir && Sys.is_directory ocamlbuild_dir then
      (* 0 *) ocamlbuild_dir
    else 
      (* 3 *) pwd
  in
    ref (Some (Filename.concat dir "oUnit.log"))

let global_logger = ref (fst OUnitLogger.null_logger)

let global_chooser = ref OUnitChooser.simple

let bracket set_up f tear_down () =
  (* 0 *) let fixture = 
    set_up () 
  in
  let () = 
    try
      let () = f fixture in
        tear_down fixture
    with e -> 
      (* 0 *) let () = 
        tear_down fixture
      in
        raise e
  in
    ()

let bracket_tmpfile ?(prefix="ounit-") ?(suffix=".txt") ?mode f =
  (* 0 *) bracket
    (fun () ->
       (* 0 *) Filename.open_temp_file ?mode prefix suffix)
    f 
    (fun (fn, chn) ->
       (* 0 *) begin
         try 
           close_out chn
         with _ ->
           (* 0 *) ()
       end;
       begin
         try
           Sys.remove fn
         with _ ->
           (* 0 *) ()
       end)

exception Skip of string
let skip_if b msg =
  (* 0 *) if b then
    (* 0 *) raise (Skip msg)

exception Todo of string
let todo msg =
  (* 0 *) raise (Todo msg)

let assert_failure msg = 
  (* 2 *) failwith ("OUnit: " ^ msg)

let assert_bool msg b =
  (* 6028287 *) if not b then (* 2 *) assert_failure msg

let assert_string str =
  (* 0 *) if not (str = "") then (* 0 *) assert_failure str

let assert_equal ?(cmp = ( = )) ?printer ?pp_diff ?msg expected actual =
  (* 6004524 *) let get_error_string () =
    (* 0 *) let res =
      buff_format_printf
        (fun fmt ->
           (* 0 *) Format.pp_open_vbox fmt 0;
           begin
             match msg with 
               | Some s ->
                   (* 0 *) Format.pp_open_box fmt 0;
                   Format.pp_print_string fmt s;
                   Format.pp_close_box fmt ();
                   Format.pp_print_cut fmt ()
               | None -> 
                   (* 0 *) ()
           end;

           begin
             match printer with
               | Some p ->
                   (* 0 *) Format.fprintf fmt
                     "@[expected: @[%s@]@ but got: @[%s@]@]@,"
                     (p expected)
                     (p actual)

               | None ->
                   (* 0 *) Format.fprintf fmt "@[not equal@]@,"
           end;

           begin
             match pp_diff with 
               | Some d ->
                   (* 0 *) Format.fprintf fmt 
                     "@[differences: %a@]@,"
                      d (expected, actual)

               | None ->
                   (* 0 *) ()
           end;
           Format.pp_close_box fmt ())
    in
    let len = 
      String.length res
    in
      if len > 0 && res.[len - 1] = '\n' then
        (* 0 *) String.sub res 0 (len - 1)
      else
        (* 0 *) res
  in
    if not (cmp expected actual) then 
      (* 0 *) assert_failure (get_error_string ())

let assert_command 
    ?(exit_code=Unix.WEXITED 0)
    ?(sinput=Stream.of_list [])
    ?(foutput=ignore)
    ?(use_stderr=true)
    ?env
    ?verbose
    prg args =

    (* 0 *) bracket_tmpfile 
      (fun (fn_out, chn_out) ->
         (* 0 *) let cmd_print fmt =
           (* 0 *) let () = 
             match env with
               | Some e ->
                   (* 0 *) begin
                     Format.pp_print_string fmt "env";
                     Array.iter (Format.fprintf fmt "@ %s") e;
                     Format.pp_print_space fmt ()
                   end
               
               | None ->
                   (* 0 *) ()
           in
             Format.pp_print_string fmt prg;
             List.iter (Format.fprintf fmt "@ %s") args
         in

         (* Start the process *)
         let in_write = 
           Unix.dup (Unix.descr_of_out_channel chn_out)
         in
         let (out_read, out_write) = 
           Unix.pipe () 
         in
         let err = 
           if use_stderr then
             (* 0 *) in_write
           else
             (* 0 *) Unix.stderr
         in
         let args = 
           Array.of_list (prg :: args)
         in
         let pid =
           OUnitLogger.printf !global_logger "%s"
             (buff_format_printf
                (fun fmt ->
                   (* 0 *) Format.fprintf fmt "@[Starting command '%t'@]\n" cmd_print));
           Unix.set_close_on_exec out_write;
           match env with 
             | Some e -> 
                 (* 0 *) Unix.create_process_env prg args e out_read in_write err
             | None -> 
                 (* 0 *) Unix.create_process prg args out_read in_write err
         in
         let () =
           Unix.close out_read; 
           Unix.close in_write
         in
         let () =
           (* Dump sinput into the process stdin *)
           let buff = Bytes.of_string " " in
             Stream.iter 
               (fun c ->
                  (* 0 *) let _i : int =
                    Bytes.set buff 0  c;
                    Unix.write out_write buff 0 1
                  in
                    ())
               sinput;
             Unix.close out_write
         in
         let _, real_exit_code =
           let rec wait_intr () = 
             (* 0 *) try 
               Unix.waitpid [] pid
             with Unix.Unix_error (Unix.EINTR, _, _) ->
               (* 0 *) wait_intr ()
           in
             wait_intr ()
         in
         let exit_code_printer =
           function
             | Unix.WEXITED n ->
                 (* 0 *) Printf.sprintf "exit code %d" n
             | Unix.WSTOPPED n ->
                 (* 0 *) Printf.sprintf "stopped by signal %d" n
             | Unix.WSIGNALED n ->
                 (* 0 *) Printf.sprintf "killed by signal %d" n
         in

           (* Dump process output to stderr *)
           begin
             let chn = open_in fn_out in
             let buff = String.make 4096 'X' in
             let len = ref (-1) in
               while !len <> 0 do 
                 (* 0 *) len := input chn buff 0 (String.length buff);
                 OUnitLogger.printf !global_logger "%s" (String.sub buff 0 !len);
               done;
               close_in chn
           end;

           (* Check process status *)
           assert_equal 
             ~msg:(buff_format_printf 
                     (fun fmt ->
                        (* 0 *) Format.fprintf fmt 
                          "@[Exit status of command '%t'@]" cmd_print))
             ~printer:exit_code_printer
             exit_code
             real_exit_code;

           begin
             let chn = open_in fn_out in
               try 
                 foutput (Stream.of_channel chn)
               with e ->
                 (* 0 *) close_in chn;
                 raise e
           end)
      ()

let raises f =
  (* 24 *) try
    f ();
    None
  with e -> 
    (* 24 *) Some e

let assert_raises ?msg exn (f: unit -> 'a) = 
  (* 18 *) let pexn = 
    Printexc.to_string 
  in
  let get_error_string () =
    (* 0 *) let str = 
      Format.sprintf 
        "expected exception %s, but no exception was raised." 
        (pexn exn)
    in
      match msg with
        | None -> 
            (* 0 *) assert_failure str
              
        | Some s -> 
            (* 0 *) assert_failure (s^"\n"^str)
  in    
    match raises f with
      | None -> 
          (* 0 *) assert_failure (get_error_string ())

      | Some e -> 
          (* 18 *) assert_equal ?msg ~printer:pexn exn e


let assert_raise_any ?msg (f: unit -> 'a) = 
  (* 6 *) let pexn = 
    Printexc.to_string 
  in
  let get_error_string () =
    (* 0 *) let str = 
      Format.sprintf 
        "expected exception , but no exception was raised." 
        
    in
      match msg with
        | None -> 
            (* 0 *) assert_failure str
              
        | Some s -> 
            (* 0 *) assert_failure (s^"\n"^str)
  in    
    match raises f with
      | None -> 
          (* 0 *) assert_failure (get_error_string ())

      | Some exn -> 
          (* 6 *) assert_bool (pexn exn) true
(* Compare floats up to a given relative error *)
let cmp_float ?(epsilon = 0.00001) a b =
  (* 0 *) abs_float (a -. b) <= epsilon *. (abs_float a) ||
    abs_float (a -. b) <= epsilon *. (abs_float b) 
      
(* Now some handy shorthands *)
let (@?) = assert_bool

(* Some shorthands which allows easy test construction *)
let (>:) s t = (* 0 *) TestLabel(s, t)             (* infix *)
let (>::) s f = (* 477 *) TestLabel(s, TestCase(f))  (* infix *)
let (>:::) s l = (* 69 *) TestLabel(s, TestList(l)) (* infix *)

(* Utility function to manipulate test *)
let rec test_decorate g =
  function
    | TestCase f -> 
        (* 0 *) TestCase (g f)
    | TestList tst_lst ->
        (* 0 *) TestList (List.map (test_decorate g) tst_lst)
    | TestLabel (str, tst) ->
        (* 0 *) TestLabel (str, test_decorate g tst)

let test_case_count = OUnitUtils.test_case_count 
let string_of_node = OUnitUtils.string_of_node
let string_of_path = OUnitUtils.string_of_path
    
(* Returns all possible paths in the test. The order is from test case
   to root 
 *)
let test_case_paths test = 
  (* 0 *) let rec tcps path test = 
    (* 0 *) match test with 
      | TestCase _ -> 
          (* 0 *) [path] 

      | TestList tests -> 
          (* 0 *) List.concat 
            (mapi (fun t i -> (* 0 *) tcps ((ListItem i)::path) t) tests)

      | TestLabel (l, t) -> 
          (* 0 *) tcps ((Label l)::path) t
  in
    tcps [] test

(* Test filtering with their path *)
module SetTestPath = Set.Make(String)

let test_filter ?(skip=false) only test =
  (* 0 *) let set_test =
    List.fold_left 
      (fun st str -> (* 0 *) SetTestPath.add str st)
      SetTestPath.empty
      only
  in
  let rec filter_test path tst =
    (* 0 *) if SetTestPath.mem (string_of_path path) set_test then
      (* 0 *) begin
        Some tst
      end

    else
      (* 0 *) begin
        match tst with
          | TestCase f ->
              (* 0 *) begin
                if skip then
                  (* 0 *) Some 
                    (TestCase 
                       (fun () ->
                          (* 0 *) skip_if true "Test disabled";
                          f ()))
                else
                  (* 0 *) None
              end

          | TestList tst_lst ->
              (* 0 *) begin
                let ntst_lst =
                  fold_lefti 
                    (fun ntst_lst tst i ->
                       (* 0 *) let nntst_lst =
                         match filter_test ((ListItem i) :: path) tst with
                           | Some tst ->
                               (* 0 *) tst :: ntst_lst
                           | None ->
                               (* 0 *) ntst_lst
                       in
                         nntst_lst)
                    []
                    tst_lst
                in
                  if not skip && ntst_lst = [] then
                    (* 0 *) None
                  else
                    (* 0 *) Some (TestList (List.rev ntst_lst))
              end

          | TestLabel (lbl, tst) ->
              (* 0 *) begin
                let ntst_opt =
                  filter_test 
                    ((Label lbl) :: path)
                    tst
                in
                  match ntst_opt with 
                    | Some ntst ->
                        (* 0 *) Some (TestLabel (lbl, ntst))
                    | None ->
                        (* 0 *) if skip then
                          (* 0 *) Some (TestLabel (lbl, tst))
                        else
                          (* 0 *) None
              end
      end
  in
    filter_test [] test


(* The possible test results *)
let is_success = OUnitUtils.is_success
let is_failure = OUnitUtils.is_failure
let is_error   = OUnitUtils.is_error  
let is_skip    = OUnitUtils.is_skip   
let is_todo    = OUnitUtils.is_todo   

(* TODO: backtrace is not correct *)
let maybe_backtrace = ""
  (* Printexc.get_backtrace () *)
    (* (if Printexc.backtrace_status () then *)
    (*    "\n" ^ Printexc.get_backtrace () *)
    (*  else "") *)
(* Events which can happen during testing *)

(* DEFINE MAYBE_BACKTRACE = *)
(* IFDEF BACKTRACE THEN *)
(*     (if Printexc.backtrace_status () then *)
(*        "\n" ^ Printexc.get_backtrace () *)
(*      else "") *)
(* ELSE *)
(*     "" *)
(* ENDIF *)

(* Run all tests, report starts, errors, failures, and return the results *)
let perform_test report test =
  (* 3 *) let run_test_case f path =
    (* 477 *) try 
      f ();
      RSuccess path
    with
      | Failure s -> 
          (* 2 *) RFailure (path, s ^ maybe_backtrace)

      | Skip s -> 
          (* 0 *) RSkip (path, s)

      | Todo s -> 
          (* 0 *) RTodo (path, s)

      | s -> 
          (* 0 *) RError (path, (Printexc.to_string s) ^ maybe_backtrace)
  in
  let rec flatten_test path acc = 
    function
      | TestCase(f) -> 
          (* 477 *) (path, f) :: acc

      | TestList (tests) ->
          (* 69 *) fold_lefti 
            (fun acc t cnt -> 
               (* 543 *) flatten_test 
                 ((ListItem cnt)::path) 
                 acc t)
            acc tests
      
      | TestLabel (label, t) -> 
          (* 546 *) flatten_test ((Label label)::path) acc t
  in
  let test_cases = List.rev (flatten_test [] [] test) in
  let runner (path, f) = 
    (* 477 *) let result = 
      report (EStart path);
      run_test_case f path 
    in
      report (EResult result);
      report (EEnd path);
      result
  in
  let rec iter state = 
    (* 480 *) match state.tests_planned with 
      | [] ->
          (* 3 *) state.results
      | _ ->
          (* 477 *) let (path, f) = !global_chooser state in            
          let result = runner (path, f) in
            iter 
              {
                results = result :: state.results;
                tests_planned = 
                  List.filter 
                    (fun (path', _) -> (* 38160 *) path <> path') state.tests_planned
              }
  in
    iter {results = []; tests_planned = test_cases}

(* Function which runs the given function and returns the running time
   of the function, and the original result in a tuple *)
let time_fun f x y =
  (* 3 *) let begin_time = Unix.gettimeofday () in
  let result = f x y in
  let end_time = Unix.gettimeofday () in
    (end_time -. begin_time, result)

(* A simple (currently too simple) text based test runner *)
let run_test_tt ?verbose test =
  (* 3 *) let log, log_close = 
    OUnitLogger.create 
      !global_output_file 
      !global_verbose 
      OUnitLogger.null_logger
  in
  let () = 
    global_logger := log
  in

  (* Now start the test *)
  let running_time, results = 
    time_fun 
      perform_test 
      (fun ev ->
         (* 1431 *) log (OUnitLogger.TestEvent ev))
      test 
  in
    
    (* Print test report *)
    log (OUnitLogger.GlobalEvent (GResults (running_time, results, test_case_count test)));

    (* Reset logger. *)
    log_close ();
    global_logger := fst OUnitLogger.null_logger;

    (* Return the results possibly for further processing *)
    results
      
(* Call this one from you test suites *)
let run_test_tt_main ?(arg_specs=[]) ?(set_verbose=ignore) suite = 
  (* 3 *) let only_test = ref [] in
  let () = 
    Arg.parse
      (Arg.align
         [
           "-verbose", 
           Arg.Set global_verbose, 
           " Run the test in verbose mode.";

           "-only-test", 
           Arg.String (fun str -> (* 0 *) only_test := str :: !only_test),
           "path Run only the selected test";

           "-output-file",
           Arg.String (fun s -> (* 0 *) global_output_file := Some s),
           "fn Output verbose log in this file.";

           "-no-output-file",
           Arg.Unit (fun () -> (* 0 *) global_output_file := None),
           " Prevent to write log in a file.";

           "-list-test",
           Arg.Unit
             (fun () -> 
                (* 0 *) List.iter
                  (fun pth ->
                     (* 0 *) print_endline (string_of_path pth))
                  (test_case_paths suite);
                exit 0),
           " List tests";
         ] @ arg_specs
      )
      (fun x -> (* 0 *) raise (Arg.Bad ("Bad argument : " ^ x)))
      ("usage: " ^ Sys.argv.(0) ^ " [-verbose] [-only-test path]*")
  in
  let nsuite = 
    if !only_test = [] then
      (* 3 *) suite
    else
      (* 0 *) begin
        match test_filter ~skip:true !only_test suite with 
          | Some test ->
              (* 0 *) test
          | None ->
              (* 0 *) failwith ("Filtering test "^
                        (String.concat ", " !only_test)^
                        " lead to no test")
      end
  in

  let result = 
    set_verbose !global_verbose;
    run_test_tt ~verbose:!global_verbose nsuite 
  in
    if not (was_successful result) then
      (* 2 *) exit 1
    else
      (* 1 *) result

end
module Ext_array : sig 
#1 "ext_array.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)






(** Some utilities for {!Array} operations *)
val reverse_range : 'a array -> int -> int -> unit
val reverse_in_place : 'a array -> unit
val reverse : 'a array -> 'a array 
val reverse_of_list : 'a list -> 'a array

val filter : ('a -> bool) -> 'a array -> 'a array

val filter_map : ('a -> 'b option) -> 'a array -> 'b array

val range : int -> int -> int array

val map2i : (int -> 'a -> 'b -> 'c ) -> 'a array -> 'b array -> 'c array

val to_list_map : ('a -> 'b option) -> 'a array -> 'b list 

val to_list_map_acc : 
  ('a -> 'b option) -> 
  'a array -> 
  'b list -> 
  'b list 

val of_list_map : ('a -> 'b) -> 'a list -> 'b array 

val rfind_with_index : 'a array -> ('a -> 'b -> bool) -> 'b -> int


type 'a split = [ `No_split | `Split of 'a array * 'a array ]

val rfind_and_split : 
  'a array ->
  ('a -> 'b -> bool) ->
  'b -> 'a split

val find_and_split : 
  'a array ->
  ('a -> 'b -> bool) ->
  'b -> 'a split

val exists : ('a -> bool) -> 'a array -> bool 

val is_empty : 'a array -> bool 
end = struct
#1 "ext_array.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)





let reverse_range a i len =
  (* 3 *) if len = 0 then (* 0 *) ()
  else
    (* 3 *) for k = 0 to (len-1)/2 do
      (* 3 *) let t = Array.unsafe_get a (i+k) in
      Array.unsafe_set a (i+k) ( Array.unsafe_get a (i+len-1-k));
      Array.unsafe_set a (i+len-1-k) t;
    done


let reverse_in_place a =
  (* 0 *) reverse_range a 0 (Array.length a)

let reverse a =
  (* 6 *) let b_len = Array.length a in
  if b_len = 0 then (* 3 *) [||] else  
  (* 3 *) let b = Array.copy a in  
  for i = 0 to  b_len - 1 do
      (* 6 *) Array.unsafe_set b i (Array.unsafe_get a (b_len - 1 -i )) 
  done;
  b  

let reverse_of_list =  function
  | [] -> (* 3 *) [||]
  | hd::tl as l ->
    (* 6 *) let len = List.length l in
    let a = Array.make len hd in
    let rec fill i = function
      | [] -> (* 6 *) a
      | hd::tl -> (* 6 *) Array.unsafe_set a (len - i - 2) hd; fill (i+1) tl in
    fill 0 tl

let filter f a =
  (* 0 *) let arr_len = Array.length a in
  let rec aux acc i =
    (* 0 *) if i = arr_len 
    then (* 0 *) reverse_of_list acc 
    else
      (* 0 *) let v = Array.unsafe_get a i in
      if f  v then 
        (* 0 *) aux (v::acc) (i+1)
      else (* 0 *) aux acc (i + 1) 
  in aux [] 0


let filter_map (f : _ -> _ option) a =
  (* 0 *) let arr_len = Array.length a in
  let rec aux acc i =
    (* 0 *) if i = arr_len 
    then (* 0 *) reverse_of_list acc 
    else
      (* 0 *) let v = Array.unsafe_get a i in
      match f  v with 
      | Some v -> 
        (* 0 *) aux (v::acc) (i+1)
      | None -> 
        (* 0 *) aux acc (i + 1) 
  in aux [] 0

let range from to_ =
  (* 0 *) if from > to_ then (* 0 *) invalid_arg "Ext_array.range"  
  else (* 0 *) Array.init (to_ - from + 1) (fun i -> (* 0 *) i + from)

let map2i f a b = 
  (* 0 *) let len = Array.length a in 
  if len <> Array.length b then 
    (* 0 *) invalid_arg "Ext_array.map2i"  
  else
    (* 0 *) Array.mapi (fun i a -> (* 0 *) f i  a ( Array.unsafe_get b i )) a 


 let rec tolist_aux a f  i res =
    (* 42 *) if i < 0 then (* 6 *) res else
      (* 36 *) let v = Array.unsafe_get a i in
      tolist_aux a f  (i - 1)
        (match f v with
         | Some v -> (* 18 *) v :: res
         | None -> (* 18 *) res) 

let to_list_map f a = 
  (* 0 *) tolist_aux a f (Array.length a - 1) []

let to_list_map_acc f a acc = 
  (* 6 *) tolist_aux a f (Array.length a - 1) acc


(* TODO: What would happen if [f] raise, memory leak? *)
let of_list_map f a = 
  (* 9 *) match a with 
  | [] -> (* 3 *) [||]
  | h::tl -> 
    (* 6 *) let hd = f h in 
    let len = List.length tl + 1 in 
    let arr = Array.make len hd  in
    let rec fill i = function
    | [] -> (* 6 *) arr 
    | hd :: tl -> 
      (* 6 *) Array.unsafe_set arr i (f hd); 
      fill (i + 1) tl in 
    fill 1 tl
  
(**
{[
# rfind_with_index [|1;2;3|] (=) 2;;
- : int = 1
# rfind_with_index [|1;2;3|] (=) 1;;
- : int = 0
# rfind_with_index [|1;2;3|] (=) 3;;
- : int = 2
# rfind_with_index [|1;2;3|] (=) 4;;
- : int = -1
]}
*)
let rfind_with_index arr cmp v = 
  (* 0 *) let len = Array.length arr in 
  let rec aux i = 
    (* 0 *) if i < 0 then (* 0 *) i
    else (* 0 *) if  cmp (Array.unsafe_get arr i) v then (* 0 *) i
    else (* 0 *) aux (i - 1) in 
  aux (len - 1)

type 'a split = [ `No_split | `Split of 'a array * 'a array ]
let rfind_and_split arr cmp v : _ split = 
  (* 0 *) let i = rfind_with_index arr cmp v in 
  if  i < 0 then 
    (* 0 *) `No_split 
  else 
    (* 0 *) `Split (Array.sub arr 0 i , Array.sub arr  (i + 1 ) (Array.length arr - i - 1 ))


let find_with_index arr cmp v = 
  (* 12 *) let len  = Array.length arr in 
  let rec aux i len = 
    (* 36 *) if i >= len then (* 3 *) -1 
    else (* 33 *) if cmp (Array.unsafe_get arr i ) v then (* 9 *) i 
    else (* 24 *) aux (i + 1) len in 
  aux 0 len

let find_and_split arr cmp v : _ split = 
  (* 12 *) let i = find_with_index arr cmp v in 
  if i < 0 then 
    (* 3 *) `No_split
  else
    (* 9 *) `Split (Array.sub arr 0 i, Array.sub arr (i + 1 ) (Array.length arr - i - 1))        

(** TODO: available since 4.03, use {!Array.exists} *)

let exists p a =
  (* 0 *) let n = Array.length a in
  let rec loop i =
    (* 0 *) if i = n then (* 0 *) false
    else (* 0 *) if p (Array.unsafe_get a i) then (* 0 *) true
    else (* 0 *) loop (succ i) in
  loop 0


let is_empty arr =
  (* 0 *) Array.length arr = 0
end
module Ext_bytes : sig 
#1 "ext_bytes.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)







(** Port the {!Bytes.escaped} from trunk to make it not locale sensitive *)

val escaped : bytes -> bytes

end = struct
#1 "ext_bytes.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








external char_code: char -> int = "%identity"
external char_chr: int -> char = "%identity"

let escaped s =
  (* 0 *) let n = Pervasives.ref 0 in
  for i = 0 to Bytes.length s - 1 do
    (* 0 *) n := !n +
      (match Bytes.unsafe_get s i with
       | '"' | '\\' | '\n' | '\t' | '\r' | '\b' -> (* 0 *) 2
       | ' ' .. '~' -> (* 0 *) 1
       | _ -> (* 0 *) 4)
  done;
  if !n = Bytes.length s then (* 0 *) Bytes.copy s else (* 0 *) begin
    let s' = Bytes.create !n in
    n := 0;
    for i = 0 to Bytes.length s - 1 do
      (* 0 *) begin match Bytes.unsafe_get s i with
      | ('"' | '\\') as c ->
          (* 0 *) Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n c
      | '\n' ->
          (* 0 *) Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 'n'
      | '\t' ->
          (* 0 *) Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 't'
      | '\r' ->
          (* 0 *) Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 'r'
      | '\b' ->
          (* 0 *) Bytes.unsafe_set s' !n '\\'; incr n; Bytes.unsafe_set s' !n 'b'
      | (' ' .. '~') as c -> (* 0 *) Bytes.unsafe_set s' !n c
      | c ->
          (* 0 *) let a = char_code c in
          Bytes.unsafe_set s' !n '\\';
          incr n;
          Bytes.unsafe_set s' !n (char_chr (48 + a / 100));
          incr n;
          Bytes.unsafe_set s' !n (char_chr (48 + (a / 10) mod 10));
          incr n;
          Bytes.unsafe_set s' !n (char_chr (48 + a mod 10));
      end;
      incr n
    done;
    s'
  end

end
module Ext_string : sig 
#1 "ext_string.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








(** Extension to the standard library [String] module, avoid locale sensitivity *) 


val trim : string -> string 

val split_by : ?keep_empty:bool -> (char -> bool) -> string -> string list
(** default is false *)

val split : ?keep_empty:bool -> string -> char -> string list
(** default is false *)

val quick_split_by_ws : string -> string list 
(** split by space chars for quick scripting *)


val starts_with : string -> string -> bool

(**
   return [-1] when not found, the returned index is useful 
   see [ends_with_then_chop]
*)
val ends_with_index : string -> string -> int

val ends_with : string -> string -> bool

(**
   {[
     ends_with_then_chop "a.cmj" ".cmj"
     "a"
   ]}
   This is useful in controlled or file case sensitve system
*)
val ends_with_then_chop : string -> string -> string option


val escaped : string -> string

(** the range is [start, finish) 
*)
val for_all_range : 
  string -> start:int -> finish:int -> (char -> bool) -> bool 

val for_all : (char -> bool) -> string -> bool

val is_empty : string -> bool

val repeat : int -> string -> string 

val equal : string -> string -> bool

val find : ?start:int -> sub:string -> string -> int

val contain_substring : string -> string -> bool 

val non_overlap_count : sub:string -> string -> int 

val rfind : sub:string -> string -> int

val tail_from : string -> int -> string

val digits_of_str : string -> offset:int -> int -> int

val starts_with_and_number : string -> offset:int -> string -> int

val unsafe_concat_with_length : int -> string -> string list -> string


(** returns negative number if not found *)
val rindex_neg : string -> char -> int 

val rindex_opt : string -> char -> int option

type check_result = 
    | Good | Invalid_module_name | Suffix_mismatch

val is_valid_source_name :
   string -> check_result

val no_char : string -> char -> int -> int -> bool 


val no_slash : string -> bool 

(** return negative means no slash, otherwise [i] means the place for first slash *)
val no_slash_idx : string -> int 

(** if no conversion happens, reference equality holds *)
val replace_slash_backward : string -> string 

(** if no conversion happens, reference equality holds *)
val replace_backward_slash : string -> string 

val empty : string 

external compare : string -> string -> int = "caml_string_length_based_compare" "noalloc";;

val single_space : string

val concat3 : string -> string -> string -> string 
val concat4 : string -> string -> string -> string -> string 
val concat5 : string -> string -> string -> string -> string -> string  
val inter2 : string -> string -> string
val inter3 : string -> string -> string -> string 
val inter4 : string -> string -> string -> string -> string
val concat_array : string -> string array -> string 

val single_colon : string 

val parent_dir_lit : string
val current_dir_lit : string

end = struct
#1 "ext_string.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)







(*
   {[ split " test_unsafe_obj_ffi_ppx.cmi" ~keep_empty:false ' ']}
*)
let split_by ?(keep_empty=false) is_delim str =
  (* 3258 *) let len = String.length str in
  let rec loop acc last_pos pos =
    (* 140796 *) if pos = -1 then
      (* 3258 *) if last_pos = 0 && not keep_empty then

        (* 2895 *) acc
      else 
        (* 363 *) String.sub str 0 last_pos :: acc
    else
    (* 137538 *) if is_delim str.[pos] then
      (* 53268 *) let new_len = (last_pos - pos - 1) in
      if new_len <> 0 || keep_empty then 
        (* 9381 *) let v = String.sub str (pos + 1) new_len in
        loop ( v :: acc)
          pos (pos - 1)
      else (* 43887 *) loop acc pos (pos - 1)
    else (* 84270 *) loop acc last_pos (pos - 1)
  in
  loop [] len (len - 1)

let trim s = 
  (* 12 *) let i = ref 0  in
  let j = String.length s in 
  while !i < j &&  
        let u = String.unsafe_get s !i in 
        u = '\t' || u = '\n' || u = ' ' 
  do 
    (* 27 *) incr i;
  done;
  let k = ref (j - 1)  in 
  while !k >= !i && 
        let u = String.unsafe_get s !k in 
        u = '\t' || u = '\n' || u = ' ' do 
    (* 18 *) decr k ;
  done;
  String.sub s !i (!k - !i + 1)

let split ?keep_empty  str on = 
  (* 519 *) if str = "" then (* 0 *) [] else 
    (* 519 *) split_by ?keep_empty (fun x -> (* 72960 *) (x : char) = on) str  ;;

let quick_split_by_ws str : string list = 
  (* 2739 *) split_by ~keep_empty:false (fun x -> (* 64578 *) x = '\t' || x = '\n' || x = ' ') str

let starts_with s beg = 
  (* 12 *) let beg_len = String.length beg in
  let s_len = String.length s in
  beg_len <=  s_len &&
  (let i = ref 0 in
   while !i <  beg_len 
         && String.unsafe_get s !i =
            String.unsafe_get beg !i do 
     (* 12 *) incr i 
   done;
   !i = beg_len
  )


(** return an index which is minus when [s] does not 
    end with [beg]
*)
let ends_with_index s end_ = 
  (* 189 *) let s_finish = String.length s - 1 in
  let s_beg = String.length end_ - 1 in
  if s_beg > s_finish then (* 0 *) -1
  else
    (* 189 *) let rec aux j k = 
      (* 477 *) if k < 0 then (* 81 *) (j + 1)
      else (* 396 *) if String.unsafe_get s j = String.unsafe_get end_ k then 
        (* 288 *) aux (j - 1) (k - 1)
      else  (* 108 *) -1 in 
    aux s_finish s_beg

let ends_with s end_ = (* 0 *) ends_with_index s end_ >= 0 

let ends_with_then_chop s beg = 
  (* 6 *) let i =  ends_with_index s beg in 
  if i >= 0 then (* 3 *) Some (String.sub s 0 i) 
  else (* 3 *) None

let check_suffix_case = ends_with 
let check_suffix_case_then_chop = ends_with_then_chop

let check_any_suffix_case s suffixes = 
  (* 0 *) List.exists (fun x -> (* 0 *) check_suffix_case s x) suffixes

let check_any_suffix_case_then_chop s suffixes = 
  (* 81 *) let rec aux suffixes = 
    (* 186 *) match suffixes with 
    | [] -> (* 3 *) None 
    | x::xs -> 
      (* 183 *) let id = ends_with_index s x in 
      if id >= 0 then (* 78 *) Some (String.sub s 0 id)
      else (* 105 *) aux xs in 
  aux suffixes    



(**  In OCaml 4.02.3, {!String.escaped} is locale senstive, 
     this version try to make it not locale senstive, this bug is fixed
     in the compiler trunk     
*)
let escaped s =
  (* 0 *) let rec needs_escape i =
    (* 0 *) if i >= String.length s then (* 0 *) false else
      (* 0 *) match String.unsafe_get s i with
      | '"' | '\\' | '\n' | '\t' | '\r' | '\b' -> (* 0 *) true
      | ' ' .. '~' -> (* 0 *) needs_escape (i+1)
      | _ -> (* 0 *) true
  in
  if needs_escape 0 then
    (* 0 *) Bytes.unsafe_to_string (Ext_bytes.escaped (Bytes.unsafe_of_string s))
  else
    (* 0 *) s

(* it is unsafe to expose such API as unsafe since 
   user can provide bad input range 

*)
let rec unsafe_for_all_range s ~start ~finish p =     
  (* 123 *) start > finish ||
  p (String.unsafe_get s start) && 
  unsafe_for_all_range s ~start:(start + 1) ~finish p

let for_all_range s ~start ~finish p = 
  (* 18 *) let len = String.length s in 
  if start < 0 || finish >= len then (* 3 *) invalid_arg "Ext_string.for_all_range"
  else (* 15 *) unsafe_for_all_range s ~start ~finish p 

let for_all (p : char -> bool) s =   
  (* 9 *) unsafe_for_all_range s ~start:0  ~finish:(String.length s - 1) p 

let is_empty s = (* 12 *) String.length s = 0


let repeat n s  =
  (* 0 *) let len = String.length s in
  let res = Bytes.create(n * len) in
  for i = 0 to pred n do
    (* 0 *) String.blit s 0 res (i * len) len
  done;
  Bytes.to_string res

let equal (x : string) y  = (* 0 *) x = y



let unsafe_is_sub ~sub i s j ~len =
  (* 2749 *) let rec check k =
    (* 3496 *) if k = len
    then (* 118 *) true
    else 
      (* 3378 *) String.unsafe_get sub (i+k) = 
      String.unsafe_get s (j+k) && check (k+1)
  in
  j+len <= String.length s && check 0


exception Local_exit 
let find ?(start=0) ~sub s =
  (* 138 *) let n = String.length sub in
  let s_len = String.length s in 
  let i = ref start in  
  try
    while !i + n <= s_len do
      (* 2725 *) if unsafe_is_sub ~sub 0 s !i ~len:n then
        (* 112 *) raise_notrace Local_exit;
      incr i
    done;
    -1
  with Local_exit ->
    (* 112 *) !i

let contain_substring s sub = 
  (* 48 *) find s ~sub >= 0 

(** TODO: optimize 
    avoid nonterminating when string is empty 
*)
let non_overlap_count ~sub s = 
  (* 21 *) let sub_len = String.length sub in 
  let rec aux  acc off = 
    (* 84 *) let i = find ~start:off ~sub s  in 
    if i < 0 then (* 21 *) acc 
    else (* 63 *) aux (acc + 1) (i + sub_len) in
  if String.length sub = 0 then (* 0 *) invalid_arg "Ext_string.non_overlap_count"
  else (* 21 *) aux 0 0  


let rfind ~sub s =
  (* 6 *) let n = String.length sub in
  let i = ref (String.length s - n) in
  let module M = struct exception Exit end in 
  try
    while !i >= 0 do
      (* 24 *) if unsafe_is_sub ~sub 0 s !i ~len:n then 
        (* 6 *) raise_notrace Local_exit;
      decr i
    done;
    -1
  with Local_exit ->
    (* 6 *) !i

let tail_from s x = 
  (* 6 *) let len = String.length s  in 
  if  x > len then (* 0 *) invalid_arg ("Ext_string.tail_from " ^s ^ " : "^ string_of_int x )
  else (* 6 *) String.sub s x (len - x)


(**
   {[ 
     digits_of_str "11_js" 2 == 11     
   ]}
*)
let digits_of_str s ~offset x = 
  (* 15 *) let rec aux i acc s x  = 
    (* 45 *) if i >= x then (* 15 *) acc 
    else (* 30 *) aux (i + 1) (10 * acc + Char.code s.[offset + i] - 48 (* Char.code '0' *)) s x in 
  aux 0 0 s x 



(*
   {[
     starts_with_and_number "js_fn_mk_01" 0 "js_fn_mk_" = 1 ;;
     starts_with_and_number "js_fn_run_02" 0 "js_fn_mk_" = -1 ;;
     starts_with_and_number "js_fn_mk_03" 6 "mk_" = 3 ;;
     starts_with_and_number "js_fn_mk_04" 6 "run_" = -1;;
     starts_with_and_number "js_fn_run_04" 6 "run_" = 4;;
     (starts_with_and_number "js_fn_run_04" 6 "run_" = 3) = false ;;
   ]}
*)
let starts_with_and_number s ~offset beg =
  (* 18 *) let beg_len = String.length beg in
  let s_len = String.length s in
  let finish_delim = offset + beg_len in 

  if finish_delim >  s_len  then (* 0 *) -1 
  else 
    (* 18 *) let i = ref offset  in
    while !i <  finish_delim
          && String.unsafe_get s !i =
             String.unsafe_get beg (!i - offset) do 
      (* 78 *) incr i 
    done;
    if !i = finish_delim then 
      (* 12 *) digits_of_str ~offset:finish_delim s 2 
    else 
      (* 6 *) -1 

let equal (x : string) y  = (* 26489913 *) x = y

let unsafe_concat_with_length len sep l =
  (* 0 *) match l with 
  | [] -> (* 0 *) ""
  | hd :: tl -> (* num is positive *)
    (* 0 *) let r = Bytes.create len in
    let hd_len = String.length hd in 
    let sep_len = String.length sep in 
    String.unsafe_blit hd 0 r 0 hd_len;
    let pos = ref hd_len in
    List.iter
      (fun s ->
         (* 0 *) let s_len = String.length s in
         String.unsafe_blit sep 0 r !pos sep_len;
         pos := !pos +  sep_len;
         String.unsafe_blit s 0 r !pos s_len;
         pos := !pos + s_len)
      tl;
    Bytes.unsafe_to_string r


let rec rindex_rec s i c =
  (* 63 *) if i < 0 then (* 6 *) i else
  (* 57 *) if String.unsafe_get s i = c then (* 15 *) i else (* 42 *) rindex_rec s (i - 1) c;;

let rec rindex_rec_opt s i c =
  (* 0 *) if i < 0 then (* 0 *) None else
  (* 0 *) if String.unsafe_get s i = c then (* 0 *) Some i else (* 0 *) rindex_rec_opt s (i - 1) c;;

let rindex_neg s c = 
  (* 21 *) rindex_rec s (String.length s - 1) c;;

let rindex_opt s c = 
  (* 0 *) rindex_rec_opt s (String.length s - 1) c;;

let is_valid_module_file (s : string) = 
  (* 78 *) let len = String.length s in 
  len > 0 &&
  match String.unsafe_get s 0 with 
  | 'A' .. 'Z'
  | 'a' .. 'z' -> 
    (* 36 *) unsafe_for_all_range s ~start:1 ~finish:(len - 1)
      (fun x -> 
         (* 27 *) match x with 
         | 'A'..'Z' | 'a'..'z' | '0'..'9' | '_' | '\'' -> (* 21 *) true
         | _ -> (* 6 *) false )
  | _ -> (* 36 *) false 

type check_result = 
  | Good 
  | Invalid_module_name 
  | Suffix_mismatch
(** 
   TODO: move to another module 
   Make {!Ext_filename} not stateful
*)
let is_valid_source_name name : check_result =
  (* 81 *) match check_any_suffix_case_then_chop name [
      ".ml"; 
      ".re";
      ".mli"; ".mll"; ".rei"
    ] with 
  | None -> (* 3 *) Suffix_mismatch
  | Some x -> 
    (* 78 *) if is_valid_module_file  x then
      (* 30 *) Good
    else (* 48 *) Invalid_module_name  

(** TODO: can be improved to return a positive integer instead *)
let rec unsafe_no_char x ch i  last_idx = 
  (* 102 *) i > last_idx  || 
  (String.unsafe_get x i <> ch && unsafe_no_char x ch (i + 1)  last_idx)

let rec unsafe_no_char_idx x ch i last_idx = 
  (* 39 *) if i > last_idx  then (* 3 *) -1 
  else 
    (* 36 *) if String.unsafe_get x i <> ch then 
      (* 27 *) unsafe_no_char_idx x ch (i + 1)  last_idx
    else (* 9 *) i

let no_char x ch i len  : bool =
  (* 0 *) let str_len = String.length x in 
  if i < 0 || i >= str_len || len >= str_len then (* 0 *) invalid_arg "Ext_string.no_char"   
  else (* 0 *) unsafe_no_char x ch i len 


let no_slash x = 
  (* 15 *) unsafe_no_char x '/' 0 (String.length x - 1)

let no_slash_idx x = 
  (* 12 *) unsafe_no_char_idx x '/' 0 (String.length x - 1)

let replace_slash_backward (x : string ) = 
  (* 3 *) let len = String.length x in 
  if unsafe_no_char x '/' 0  (len - 1) then (* 0 *) x 
  else 
    (* 3 *) String.map (function 
        | '/' -> (* 9 *) '\\'
        | x -> (* 12 *) x ) x 

let replace_backward_slash (x : string)=
  (* 12 *) let len = String.length x in
  if unsafe_no_char x '\\' 0  (len -1) then (* 6 *) x 
  else  
    (* 6 *) String.map (function 
        |'\\'-> (* 15 *) '/'
        | x -> (* 24 *) x) x

let empty = ""

external compare : string -> string -> int = "caml_string_length_based_compare" "noalloc";;

let single_space = " "
let single_colon = ":"

let concat_array sep (s : string array) =   
  (* 27 *) let s_len = Array.length s in 
  match s_len with 
  | 0 -> (* 3 *) empty 
  | 1 -> (* 3 *) Array.unsafe_get s 0
  | _ ->     
    (* 21 *) let sep_len = String.length sep in 
    let len = ref 0 in 
    for i = 0 to  s_len - 1 do 
      (* 96 *) len := !len + String.length (Array.unsafe_get s i)
    done;
    let target = 
      Bytes.create 
        (!len + (s_len - 1) * sep_len ) in    
    let hd = (Array.unsafe_get s 0) in     
    let hd_len = String.length hd in 
    String.unsafe_blit hd  0  target 0 hd_len;   
    let current_offset = ref hd_len in     
    for i = 1 to s_len - 1 do 
      (* 75 *) String.unsafe_blit sep 0 target  !current_offset sep_len;
      let cur = Array.unsafe_get s i in 
      let cur_len = String.length cur in     
      let new_off_set = (!current_offset + sep_len ) in
      String.unsafe_blit cur 0 target new_off_set cur_len; 
      current_offset := 
        new_off_set + cur_len ; 
    done;
    Bytes.unsafe_to_string target   

let concat3 a b c = 
  (* 9 *) let a_len = String.length a in 
  let b_len = String.length b in 
  let c_len = String.length c in 
  let len = a_len + b_len + c_len in 
  let target = Bytes.create len in 
  String.unsafe_blit a 0 target 0 a_len ; 
  String.unsafe_blit b 0 target a_len b_len;
  String.unsafe_blit c 0 target (a_len + b_len) c_len;
  Bytes.unsafe_to_string target

let concat4 a b c d =
  (* 6 *) let a_len = String.length a in 
  let b_len = String.length b in 
  let c_len = String.length c in 
  let d_len = String.length d in 
  let len = a_len + b_len + c_len + d_len in 
  
  let target = Bytes.create len in 
  String.unsafe_blit a 0 target 0 a_len ; 
  String.unsafe_blit b 0 target a_len b_len;
  String.unsafe_blit c 0 target (a_len + b_len) c_len;
  String.unsafe_blit d 0 target (a_len + b_len + c_len) d_len;
  Bytes.unsafe_to_string target


let concat5 a b c d e =
  (* 3 *) let a_len = String.length a in 
  let b_len = String.length b in 
  let c_len = String.length c in 
  let d_len = String.length d in 
  let e_len = String.length e in 
  let len = a_len + b_len + c_len + d_len + e_len in 
  
  let target = Bytes.create len in 
  String.unsafe_blit a 0 target 0 a_len ; 
  String.unsafe_blit b 0 target a_len b_len;
  String.unsafe_blit c 0 target (a_len + b_len) c_len;
  String.unsafe_blit d 0 target (a_len + b_len + c_len) d_len;
  String.unsafe_blit e 0 target (a_len + b_len + c_len + d_len) e_len;
  Bytes.unsafe_to_string target



let inter2 a b = 
    (* 3 *) concat3 a single_space b 


let inter3 a b c = 
  (* 3 *) concat5 a  single_space  b  single_space  c 





let inter4 a b c d =
  (* 3 *) concat_array single_space [| a; b ; c; d|]
  
    
let parent_dir_lit = ".."    
let current_dir_lit = "."

end
module Ounit_array_tests
= struct
#1 "ounit_array_tests.ml"
let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal
let suites = 
    __FILE__
    >:::
    [
     __LOC__ >:: begin fun _ ->
        (* 3 *) Ext_array.find_and_split 
            [|"a"; "b";"c"|]
            Ext_string.equal "--" =~ `No_split
     end;
    __LOC__ >:: begin fun _ ->
        (* 3 *) Ext_array.find_and_split 
            [|"a"; "b";"c";"--"|]
            Ext_string.equal "--" =~ `Split ([|"a";"b";"c"|],[||])
     end;
     __LOC__ >:: begin fun _ ->
        (* 3 *) Ext_array.find_and_split 
            [|"--"; "a"; "b";"c";"--"|]
            Ext_string.equal "--" =~ `Split ([||], [|"a";"b";"c";"--"|])
     end;
    __LOC__ >:: begin fun _ ->
        (* 3 *) Ext_array.find_and_split 
            [| "u"; "g"; "--"; "a"; "b";"c";"--"|]
            Ext_string.equal "--" =~ `Split ([|"u";"g"|], [|"a";"b";"c";"--"|])
     end;
    __LOC__ >:: begin fun _ ->
        (* 3 *) Ext_array.reverse [|1;2|] =~ [|2;1|];
        Ext_array.reverse [||] =~ [||]  
    end     ;
    __LOC__ >:: begin fun _ -> 
        (* 3 *) Ext_array.of_list_map succ [] =~ [||];
        Ext_array.of_list_map succ [1]  =~ [|2|];
        Ext_array.of_list_map succ [1;2;3]  =~ [|2;3;4|];
    end; 
    __LOC__ >:: begin fun _ -> 
        (* 3 *) Ext_array.to_list_map_acc
        (fun x -> (* 18 *) if x mod 2 = 0 then (* 9 *) Some x else (* 9 *) None )
        [|1;2;3;4;5;6|] [1;2;3]
        =~ [2;4;6;1;2;3]
    end;
    __LOC__ >:: begin fun _ -> 
        (* 3 *) Ext_array.to_list_map_acc
        (fun x -> (* 18 *) if x mod 2 = 0 then (* 9 *) Some x else (* 9 *) None )
        [|1;2;3;4;5;6|] []
        =~ [2;4;6]
    end;
    ]
end
module Ounit_tests_util
= struct
#1 "ounit_tests_util.ml"



let time ?nums description  f  =
  (* 0 *) match nums with 
  | None -> 
    (* 0 *) begin 
      let start = Unix.gettimeofday () in 
      ignore @@ f ();
      let finish = Unix.gettimeofday () in
      Printf.printf "\n%s elapsed %f\n" description (finish -. start) ;
      flush stdout; 
    end

  | Some nums -> 
    (* 0 *) begin 
        let start = Unix.gettimeofday () in 
        for i = 0 to nums - 1 do 
          (* 0 *) ignore @@ f ();
        done  ;
      let finish = Unix.gettimeofday () in
      Printf.printf "\n%s elapsed %f\n" description (finish -. start)  ;
      flush stdout;
    end

end
module Set_gen
= struct
#1 "set_gen.ml"
(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(** balanced tree based on stdlib distribution *)

type 'a t = 
  | Empty 
  | Node of 'a t * 'a * 'a t * int 

type 'a enumeration = 
  | End | More of 'a * 'a t * 'a enumeration


let rec cons_enum s e = 
  (* 0 *) match s with 
  | Empty -> (* 0 *) e 
  | Node(l,v,r,_) -> (* 0 *) cons_enum l (More(v,r,e))

let rec height = function
  | Empty -> (* 35814 *) 0 
  | Node(_,_,_,h) -> (* 108192 *) h   

(* Smallest and greatest element of a set *)

let rec min_elt = function
    Empty -> (* 0 *) raise Not_found
  | Node(Empty, v, r, _) -> (* 0 *) v
  | Node(l, v, r, _) -> (* 0 *) min_elt l

let rec max_elt = function
    Empty -> (* 0 *) raise Not_found
  | Node(l, v, Empty, _) -> (* 0 *) v
  | Node(l, v, r, _) -> (* 0 *) max_elt r




let empty = Empty

let is_empty = function Empty -> (* 9 *) true | _ -> (* 36 *) false

let rec cardinal_aux acc  = function
  | Empty -> (* 63906 *) acc 
  | Node (l,_,r, _) -> 
    (* 63300 *) cardinal_aux  (cardinal_aux (acc + 1)  r ) l 

let cardinal s = (* 606 *) cardinal_aux 0 s 

let rec elements_aux accu = function
  | Empty -> (* 1599 *) accu
  | Node(l, v, r, _) -> (* 1560 *) elements_aux (v :: elements_aux accu r) l

let elements s =
  (* 39 *) elements_aux [] s

let choose = min_elt

let rec iter f = function
  | Empty -> (* 0 *) ()
  | Node(l, v, r, _) -> (* 0 *) iter f l; f v; iter f r

let rec fold f s accu =
  (* 0 *) match s with
  | Empty -> (* 0 *) accu
  | Node(l, v, r, _) -> (* 0 *) fold f r (f v (fold f l accu))

let rec for_all p = function
  | Empty -> (* 0 *) true
  | Node(l, v, r, _) -> (* 0 *) p v && for_all p l && for_all p r

let rec exists p = function
  | Empty -> (* 0 *) false
  | Node(l, v, r, _) -> (* 0 *) p v || exists p l || exists p r


let max_int3 (a : int) b c = 
  (* 0 *) if a >= b then 
    (* 0 *) if a >= c then (* 0 *) a 
    else (* 0 *) c
  else 
  (* 0 *) if b >=c then (* 0 *) b
  else (* 0 *) c     
let max_int_2 (a : int) b =  
  (* 377145 *) if a >= b then (* 303222 *) a else (* 73923 *) b 



exception Height_invariant_broken
exception Height_diff_borken 

let rec check_height_and_diff = 
  function 
  | Empty -> (* 377769 *) 0
  | Node(l,_,r,h) -> 
    (* 377145 *) let hl = check_height_and_diff l in
    let hr = check_height_and_diff r in
    if h <>  max_int_2 hl hr + 1 then (* 0 *) raise Height_invariant_broken
    else  
      (* 377145 *) let diff = (abs (hl - hr)) in  
      if  diff > 2 then (* 0 *) raise Height_diff_borken 
      else (* 377145 *) h     

let check tree = 
  (* 624 *) ignore (check_height_and_diff tree)
(* 
    Invariants: 
    1. {[ l < v < r]}
    2. l and r balanced 
    3. [height l] - [height r] <= 2
*)
let create l v r = 
  (* 548388 *) let hl = match l with Empty -> (* 54351 *) 0 | Node (_,_,_,h) -> (* 494037 *) h in
  let hr = match r with Empty -> (* 54588 *) 0 | Node (_,_,_,h) -> (* 493800 *) h in
  Node(l,v,r, if hl >= hr then (* 422007 *) hl + 1 else (* 126381 *) hr + 1)         

(* Same as create, but performs one step of rebalancing if necessary.
    Invariants:
    1. {[ l < v < r ]}
    2. l and r balanced 
    3. | height l - height r | <= 3.

    Proof by indunction

    Lemma: the height of  [bal l v r] will bounded by [max l r] + 1 
*)
(*
let internal_bal l v r =
  match l with
  | Empty ->
    begin match r with 
      | Empty -> Node(Empty,v,Empty,1)
      | Node(rl,rv,rr,hr) -> 
        if hr > 2 then
          begin match rl with
            | Empty -> create (* create l v rl *) (Node (Empty,v,Empty,1)) rv rr 
            | Node(rll,rlv,rlr,hrl) -> 
              let hrr = height rr in 
              if hrr >= hrl then 
                Node  
                  ((Node (Empty,v,rl,hrl+1))(* create l v rl *),
                   rv, rr, if hrr = hrl then hrr + 2 else hrr + 1) 
              else 
                let hrll = height rll in 
                let hrlr = height rlr in 
                create
                  (Node(Empty,v,rll,hrll + 1)) 
                  (* create l v rll *) 
                  rlv 
                  (Node (rlr,rv,rr, if hrlr > hrr then hrlr + 1 else hrr + 1))
                  (* create rlr rv rr *)    
          end 
        else Node (l,v,r, hr + 1)  
    end
  | Node(ll,lv,lr,hl) ->
    begin match r with 
      | Empty ->
        if hl > 2 then 
          (*if height ll >= height lr then create ll lv (create lr v r)
            else*)
          begin match lr with 
            | Empty -> 
              create ll lv (Node (Empty,v,Empty, 1)) 
            (* create lr v r *)  
            | Node(lrl,lrv,lrr,hlr) -> 
              if height ll >= hlr then 
                create ll lv
                  (Node(lr,v,Empty,hlr+1)) 
                  (*create lr v r*)
              else 
                let hlrr = height lrr in  
                create 
                  (create ll lv lrl)
                  lrv
                  (Node(lrr,v,Empty,hlrr + 1)) 
                  (*create lrr v r*)
          end 
        else Node(l,v,r, hl+1)    
      | Node(rl,rv,rr,hr) ->
        if hl > hr + 2 then           
          begin match lr with 
            | Empty ->   create ll lv (create lr v r)
            | Node(lrl,lrv,lrr,_) ->
              if height ll >= height lr then create ll lv (create lr v r)
              else 
                create (create ll lv lrl) lrv (create lrr v r)
          end 
        else
        if hr > hl + 2 then             
          begin match rl with 
            | Empty ->
              let hrr = height rr in   
              Node(
                (Node (l,v,Empty,hl + 1))
                (*create l v rl*)
                ,
                rv,
                rr,
                if hrr > hr then hrr + 1 else hl + 2 
              )
            | Node(rll,rlv,rlr,_) ->
              let hrr = height rr in 
              let hrl = height rl in 
              if hrr >= hrl then create (create l v rl) rv rr else 
                create (create l v rll) rlv (create rlr rv rr)
          end
        else  
          Node(l,v,r, if hl >= hr then hl+1 else hr + 1)
    end
*)
let internal_bal l v r =
  (* 5027541 *) let hl = match l with Empty -> (* 273393 *) 0 | Node(_,_,_,h) -> (* 4754148 *) h in
  let hr = match r with Empty -> (* 295482 *) 0 | Node(_,_,_,h) -> (* 4732059 *) h in
  if hl > hr + 2 then (* 35505 *) begin
    match l with
      Empty -> (* 0 *) assert false
    | Node(ll, lv, lr, _) ->   
      (* 35505 *) if height ll >= height lr then
        (* [ll] >~ [lr] 
           [ll] >~ [r] 
           [ll] ~~ [ lr ^ r]  
        *)
        (* 18999 *) create ll lv (create lr v r)
      else (* 16506 *) begin
        match lr with
          Empty -> (* 0 *) assert false
        | Node(lrl, lrv, lrr, _)->
          (* [lr] >~ [ll]
             [lr] >~ [r]
             [ll ^ lrl] ~~ [lrr ^ r]   
          *)
          (* 16506 *) create (create ll lv lrl) lrv (create lrr v r)
      end
  end else (* 4992036 *) if hr > hl + 2 then (* 36498 *) begin
    match r with
      Empty -> (* 0 *) assert false
    | Node(rl, rv, rr, _) ->
      (* 36498 *) if height rr >= height rl then
        (* 19890 *) create (create l v rl) rv rr
      else (* 16608 *) begin
        match rl with
          Empty -> (* 0 *) assert false
        | Node(rll, rlv, rlr, _) ->
          (* 16608 *) create (create l v rll) rlv (create rlr rv rr)
      end
  end else
    (* 4955538 *) Node(l, v, r, (if hl >= hr then (* 3395340 *) hl + 1 else (* 1560198 *) hr + 1))    

let rec remove_min_elt = function
    Empty -> (* 0 *) invalid_arg "Set.remove_min_elt"
  | Node(Empty, v, r, _) -> (* 0 *) r
  | Node(l, v, r, _) -> (* 0 *) internal_bal (remove_min_elt l) v r

let singleton x = (* 198870 *) Node(Empty, x, Empty, 1)    

(* 
   All elements of l must precede the elements of r.
       Assume | height l - height r | <= 2.
   weak form of [concat] 
*)

let internal_merge l r =
  (* 0 *) match (l, r) with
  | (Empty, t) -> (* 0 *) t
  | (t, Empty) -> (* 0 *) t
  | (_, _) -> (* 0 *) internal_bal l (min_elt r) (remove_min_elt r)

(* Beware: those two functions assume that the added v is *strictly*
    smaller (or bigger) than all the present elements in the tree; it
    does not test for equality with the current min (or max) element.
    Indeed, they are only used during the "join" operation which
    respects this precondition.
*)

let rec add_min_element v = function
  | Empty -> (* 120441 *) singleton v
  | Node (l, x, r, h) ->
    (* 103746 *) internal_bal (add_min_element v l) x r

let rec add_max_element v = function
  | Empty -> (* 78429 *) singleton v
  | Node (l, x, r, h) ->
    (* 102672 *) internal_bal l x (add_max_element v r)

(** 
    Invariants:
    1. l < v < r 
    2. l and r are balanced 

    Proof by induction
    The height of output will be ~~ (max (height l) (height r) + 2)
    Also use the lemma from [bal]
*)
let rec internal_join l v r =
  (* 463794 *) match (l, r) with
    (Empty, _) -> (* 120441 *) add_min_element v r
  | (_, Empty) -> (* 78429 *) add_max_element v l
  | (Node(ll, lv, lr, lh), Node(rl, rv, rr, rh)) ->
    (* 264924 *) if lh > rh + 2 then 
      (* proof by induction:
         now [height of ll] is [lh - 1] 
      *)
      (* 6309 *) internal_bal ll lv (internal_join lr v r) 
    else
    (* 258615 *) if rh > lh + 2 then (* 5190 *) internal_bal (internal_join l v rl) rv rr 
    else (* 253425 *) create l v r


(*
    Required Invariants: 
    [t1] < [t2]  
*)
let internal_concat t1 t2 =
  (* 0 *) match (t1, t2) with
  | (Empty, t) -> (* 0 *) t
  | (t, Empty) -> (* 0 *) t
  | (_, _) -> (* 0 *) internal_join t1 (min_elt t2) (remove_min_elt t2)

let rec filter p = function
  | Empty -> (* 0 *) Empty
  | Node(l, v, r, _) ->
    (* call [p] in the expected left-to-right order *)
    (* 0 *) let l' = filter p l in
    let pv = p v in
    let r' = filter p r in
    if pv then (* 0 *) internal_join l' v r' else (* 0 *) internal_concat l' r'


let rec partition p = function
  | Empty -> (* 0 *) (Empty, Empty)
  | Node(l, v, r, _) ->
    (* call [p] in the expected left-to-right order *)
    (* 0 *) let (lt, lf) = partition p l in
    let pv = p v in
    let (rt, rf) = partition p r in
    if pv
    then (* 0 *) (internal_join lt v rt, internal_concat lf rf)
    else (* 0 *) (internal_concat lt rt, internal_join lf v rf)

let of_sorted_list l =
  (* 3 *) let rec sub n l =
    (* 1533 *) match n, l with
    | 0, l -> (* 0 *) Empty, l
    | 1, x0 :: l -> (* 0 *) Node (Empty, x0, Empty, 1), l
    | 2, x0 :: x1 :: l -> (* 69 *) Node (Node(Empty, x0, Empty, 1), x1, Empty, 2), l
    | 3, x0 :: x1 :: x2 :: l ->
      (* 699 *) Node (Node(Empty, x0, Empty, 1), x1, Node(Empty, x2, Empty, 1), 2),l
    | n, l ->
      (* 765 *) let nl = n / 2 in
      let left, l = sub nl l in
      match l with
      | [] -> (* 0 *) assert false
      | mid :: l ->
        (* 765 *) let right, l = sub (n - nl - 1) l in
        create left mid right, l
  in
  fst (sub (List.length l) l)

let of_sorted_array l =   
  (* 1206 *) let rec sub start n l  =
    (* 235362 *) if n = 0 then (* 3 *) Empty else 
    (* 235359 *) if n = 1 then 
      (* 16554 *) let x0 = Array.unsafe_get l start in
      Node (Empty, x0, Empty, 1)
    else (* 218805 *) if n = 2 then     
      (* 66369 *) let x0 = Array.unsafe_get l start in 
      let x1 = Array.unsafe_get l (start + 1) in 
      Node (Node(Empty, x0, Empty, 1), x1, Empty, 2) else
    (* 152436 *) if n = 3 then 
      (* 35358 *) let x0 = Array.unsafe_get l start in 
      let x1 = Array.unsafe_get l (start + 1) in
      let x2 = Array.unsafe_get l (start + 2) in
      Node (Node(Empty, x0, Empty, 1), x1, Node(Empty, x2, Empty, 1), 2)
    else 
      (* 117078 *) let nl = n / 2 in
      let left = sub start nl l in
      let mid = start + nl in 
      let v = Array.unsafe_get l mid in 
      let right = sub (mid + 1) (n - nl - 1) l in        
      create left v right
  in
  sub 0 (Array.length l) l 

let is_ordered cmp tree =
  (* 624 *) let rec is_ordered_min_max tree =
    (* 754914 *) match tree with
    | Empty -> (* 377769 *) `Empty
    | Node(l,v,r,_) -> 
      (* 377145 *) begin match is_ordered_min_max l with
        | `No -> (* 0 *) `No 
        | `Empty ->
          (* 182796 *) begin match is_ordered_min_max r with
            | `No  -> (* 0 *) `No
            | `Empty -> (* 144216 *) `V (v,v)
            | `V(l,r) ->
              (* 38580 *) if cmp v l < 0 then
                (* 38580 *) `V(v,r)
              else
                (* 0 *) `No
          end
        | `V(min_v,max_v)->
          (* 194349 *) begin match is_ordered_min_max r with
            | `No -> (* 0 *) `No
            | `Empty -> 
              (* 50754 *) if cmp max_v v < 0 then 
                (* 50754 *) `V(min_v,v)
              else
                (* 0 *) `No 
            | `V(min_v_r, max_v_r) ->
              (* 143595 *) if cmp max_v min_v_r < 0 then
                (* 143595 *) `V(min_v,max_v_r)
              else (* 0 *) `No
          end
      end  in 
  is_ordered_min_max tree <> `No 

let invariant cmp t = 
  (* 0 *) check t ; 
  is_ordered cmp t 

let rec compare_aux cmp e1 e2 =
  (* 0 *) match (e1, e2) with
    (End, End) -> (* 0 *) 0
  | (End, _)  -> (* 0 *) -1
  | (_, End) -> (* 0 *) 1
  | (More(v1, r1, e1), More(v2, r2, e2)) ->
    (* 0 *) let c = cmp v1 v2 in
    if c <> 0
    then (* 0 *) c
    else (* 0 *) compare_aux cmp (cons_enum r1 e1) (cons_enum r2 e2)

let compare cmp s1 s2 =
  (* 0 *) compare_aux cmp (cons_enum s1 End) (cons_enum s2 End)


module type S = sig
  type elt 
  type t
  val empty: t
  val is_empty: t -> bool
  val iter: (elt -> unit) -> t -> unit
  val fold: (elt -> 'a -> 'a) -> t -> 'a -> 'a
  val for_all: (elt -> bool) -> t -> bool
  val exists: (elt -> bool) -> t -> bool
  val singleton: elt -> t
  val cardinal: t -> int
  val elements: t -> elt list
  val min_elt: t -> elt
  val max_elt: t -> elt
  val choose: t -> elt
  val of_sorted_list : elt list -> t 
  val of_sorted_array : elt array -> t
  val partition: (elt -> bool) -> t -> t * t

  val mem: elt -> t -> bool
  val add: elt -> t -> t
  val remove: elt -> t -> t
  val union: t -> t -> t
  val inter: t -> t -> t
  val diff: t -> t -> t
  val compare: t -> t -> int
  val equal: t -> t -> bool
  val subset: t -> t -> bool
  val filter: (elt -> bool) -> t -> t

  val split: elt -> t -> t * bool * t
  val find: elt -> t -> elt
  val of_list: elt list -> t
  val of_sorted_list : elt list ->  t
  val of_sorted_array : elt array -> t 
  val invariant : t -> bool 
end 

end
module Ext_int : sig 
#1 "ext_int.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


type t = int
val compare : t -> t -> int 
val equal : t -> t -> bool 

end = struct
#1 "ext_int.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


type t = int

let compare (x : t) (y : t) = (* 5001357 *) Pervasives.compare x y 

let equal (x : t) (y : t) = (* 0 *) x = y

end
module Set_int : sig 
#1 "set_int.mli"


include Set_gen.S with type elt = int 
end = struct
#1 "set_int.ml"
# 1 "ext/set.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


# 41
type elt = int 
let compare_elt = Ext_int.compare 
type t = elt Set_gen.t


# 57
let empty = Set_gen.empty 
let is_empty = Set_gen.is_empty
let iter = Set_gen.iter
let fold = Set_gen.fold
let for_all = Set_gen.for_all 
let exists = Set_gen.exists 
let singleton = Set_gen.singleton 
let cardinal = Set_gen.cardinal
let elements = Set_gen.elements
let min_elt = Set_gen.min_elt
let max_elt = Set_gen.max_elt
let choose = Set_gen.choose 
let of_sorted_list = Set_gen.of_sorted_list
let of_sorted_array = Set_gen.of_sorted_array
let partition = Set_gen.partition 
let filter = Set_gen.filter 
let of_sorted_list = Set_gen.of_sorted_list
let of_sorted_array = Set_gen.of_sorted_array

let rec split x (tree : _ Set_gen.t) : _ Set_gen.t * bool * _ Set_gen.t =  (* 0 *) match tree with 
  | Empty ->
    (* 0 *) (Empty, false, Empty)
  | Node(l, v, r, _) ->
    (* 0 *) let c = compare_elt x v in
    if c = 0 then (* 0 *) (l, true, r)
    else (* 0 *) if c < 0 then
      (* 0 *) let (ll, pres, rl) = split x l in (ll, pres, Set_gen.internal_join rl v r)
    else
      (* 0 *) let (lr, pres, rr) = split x r in (Set_gen.internal_join l v lr, pres, rr)
let rec add x (tree : _ Set_gen.t) : _ Set_gen.t =  (* 5027775 *) match tree with 
  | Empty -> (* 301548 *) Node(Empty, x, Empty, 1)
  | Node(l, v, r, _) as t ->
    (* 4726227 *) let c = compare_elt x v in
    if c = 0 then (* 12 *) t else
    (* 4726215 *) if c < 0 then (* 2354556 *) Set_gen.internal_bal (add x l) v r else (* 2371659 *) Set_gen.internal_bal l v (add x r)

let rec union (s1 : _ Set_gen.t) (s2 : _ Set_gen.t) : _ Set_gen.t  =
  (* 0 *) match (s1, s2) with
  | (Empty, t2) -> (* 0 *) t2
  | (t1, Empty) -> (* 0 *) t1
  | (Node(l1, v1, r1, h1), Node(l2, v2, r2, h2)) ->
    (* 0 *) if h1 >= h2 then
      (* 0 *) if h2 = 1 then (* 0 *) add v2 s1 else (* 0 *) begin
        let (l2, _, r2) = split v1 s2 in
        Set_gen.internal_join (union l1 l2) v1 (union r1 r2)
      end
    else
    (* 0 *) if h1 = 1 then (* 0 *) add v1 s2 else (* 0 *) begin
      let (l1, _, r1) = split v2 s1 in
      Set_gen.internal_join (union l1 l2) v2 (union r1 r2)
    end    

let rec inter (s1 : _ Set_gen.t)  (s2 : _ Set_gen.t) : _ Set_gen.t  =
  (* 0 *) match (s1, s2) with
  | (Empty, t2) -> (* 0 *) Empty
  | (t1, Empty) -> (* 0 *) Empty
  | (Node(l1, v1, r1, _), t2) ->
    (* 0 *) begin match split v1 t2 with
      | (l2, false, r2) ->
        (* 0 *) Set_gen.internal_concat (inter l1 l2) (inter r1 r2)
      | (l2, true, r2) ->
        (* 0 *) Set_gen.internal_join (inter l1 l2) v1 (inter r1 r2)
    end 

let rec diff (s1 : _ Set_gen.t) (s2 : _ Set_gen.t) : _ Set_gen.t  =
  (* 0 *) match (s1, s2) with
  | (Empty, t2) -> (* 0 *) Empty
  | (t1, Empty) -> (* 0 *) t1
  | (Node(l1, v1, r1, _), t2) ->
    (* 0 *) begin match split v1 t2 with
      | (l2, false, r2) ->
        (* 0 *) Set_gen.internal_join (diff l1 l2) v1 (diff r1 r2)
      | (l2, true, r2) ->
        (* 0 *) Set_gen.internal_concat (diff l1 l2) (diff r1 r2)    
    end


let rec mem x (tree : _ Set_gen.t) =  (* 276 *) match tree with 
  | Empty -> (* 54 *) false
  | Node(l, v, r, _) ->
    (* 222 *) let c = compare_elt x v in
    c = 0 || mem x (if c < 0 then (* 57 *) l else (* 69 *) r)

let rec remove x (tree : _ Set_gen.t) : _ Set_gen.t = (* 0 *) match tree with 
  | Empty -> (* 0 *) Empty
  | Node(l, v, r, _) ->
    (* 0 *) let c = compare_elt x v in
    if c = 0 then (* 0 *) Set_gen.internal_merge l r else
    (* 0 *) if c < 0 then (* 0 *) Set_gen.internal_bal (remove x l) v r else (* 0 *) Set_gen.internal_bal l v (remove x r)

let compare s1 s2 = (* 0 *) Set_gen.compare compare_elt s1 s2 


let equal s1 s2 =
  (* 0 *) compare s1 s2 = 0

let rec subset (s1 : _ Set_gen.t) (s2 : _ Set_gen.t) =
  (* 0 *) match (s1, s2) with
  | Empty, _ ->
    (* 0 *) true
  | _, Empty ->
    (* 0 *) false
  | Node (l1, v1, r1, _), (Node (l2, v2, r2, _) as t2) ->
    (* 0 *) let c = compare_elt v1 v2 in
    if c = 0 then
      (* 0 *) subset l1 l2 && subset r1 r2
    else (* 0 *) if c < 0 then
      (* 0 *) subset (Node (l1, v1, Empty, 0)) l2 && subset r1 t2
    else
      (* 0 *) subset (Node (Empty, v1, r1, 0)) r2 && subset l1 t2




let rec find x (tree : _ Set_gen.t) = (* 0 *) match tree with
  | Empty -> (* 0 *) raise Not_found
  | Node(l, v, r, _) ->
    (* 0 *) let c = compare_elt x v in
    if c = 0 then (* 0 *) v
    else (* 0 *) find x (if c < 0 then (* 0 *) l else (* 0 *) r)



let of_list l =
  (* 0 *) match l with
  | [] -> (* 0 *) empty
  | [x0] -> (* 0 *) singleton x0
  | [x0; x1] -> (* 0 *) add x1 (singleton x0)
  | [x0; x1; x2] -> (* 0 *) add x2 (add x1 (singleton x0))
  | [x0; x1; x2; x3] -> (* 0 *) add x3 (add x2 (add x1 (singleton x0)))
  | [x0; x1; x2; x3; x4] -> (* 0 *) add x4 (add x3 (add x2 (add x1 (singleton x0))))
  | _ -> (* 0 *) of_sorted_list (List.sort_uniq compare_elt l)

let of_array l = 
  (* 0 *) Array.fold_left (fun  acc x -> (* 0 *) add x acc) empty l

(* also check order *)
let invariant t =
  (* 3 *) Set_gen.check t ;
  Set_gen.is_ordered compare_elt t          






end
module Set_poly : sig 
#1 "set_poly.mli"
(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(** Balanced tree based on stdlib distribution *)



type 'a t
(** this operation is exposed intentionally , so that
    users can whip up a specialized collection quickly
*)



val mem: 'a -> 'a t -> bool
(** [mem x s] tests whether [x] belongs to the set [s]. *)

val add: 'a -> 'a t -> 'a t
(** [add x s] returns a set containing all elements of [s],
    plus [x]. If [x] was already in [s], [s] is returned unchanged. *)

val remove: 'a -> 'a t -> 'a t
(** [remove x s] returns a set containing all elements of [s],
    except [x]. If [x] was not in [s], [s] is returned unchanged. *)

val union: 'a t -> 'a t -> 'a t

val inter: 'a t -> 'a t -> 'a t

val diff: 'a t -> 'a t -> 'a t


val compare: 'a t -> 'a t -> int

val equal: 'a t -> 'a t -> bool

val subset: 'a t -> 'a t -> bool



val split: 'a -> 'a t -> 'a t * bool * 'a t
(** [split x s] returns a triple [(l, present, r)], where
      [l] is the set of elements of [s] that are
      strictly less than [x];
      [r] is the set of elements of [s] that are
      strictly greater than [x];
      [present] is [false] if [s] contains no element equal to [x],
      or [true] if [s] contains an element equal to [x]. *)

val find: 'a -> 'a t -> 'a
(** [find x s] returns the element of [s] equal to [x] (according
    to [Ord.compare]), or raise [Not_found] if no such element
    exists.
*)

val of_list: 'a list -> 'a t

val of_array : 'a array -> 'a t

val invariant : 'a t -> bool


val of_sorted_list : 'a list -> 'a t 
val of_sorted_array : 'a array -> 'a t 
val cardinal : 'a t -> int
val empty : 'a t 
val is_empty : 'a t -> bool 

end = struct
#1 "set_poly.ml"
# 1 "ext/set.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


# 50
type 'a t = 'a Set_gen.t
let compare_elt = Pervasives.compare


# 57
let empty = Set_gen.empty 
let is_empty = Set_gen.is_empty
let iter = Set_gen.iter
let fold = Set_gen.fold
let for_all = Set_gen.for_all 
let exists = Set_gen.exists 
let singleton = Set_gen.singleton 
let cardinal = Set_gen.cardinal
let elements = Set_gen.elements
let min_elt = Set_gen.min_elt
let max_elt = Set_gen.max_elt
let choose = Set_gen.choose 
let of_sorted_list = Set_gen.of_sorted_list
let of_sorted_array = Set_gen.of_sorted_array
let partition = Set_gen.partition 
let filter = Set_gen.filter 
let of_sorted_list = Set_gen.of_sorted_list
let of_sorted_array = Set_gen.of_sorted_array

let rec split x (tree : _ Set_gen.t) : _ Set_gen.t * bool * _ Set_gen.t =  (* 452295 *) match tree with 
  | Empty ->
    (* 2118 *) (Empty, false, Empty)
  | Node(l, v, r, _) ->
    (* 450177 *) let c = compare_elt x v in
    if c = 0 then (* 184536 *) (l, true, r)
    else (* 265641 *) if c < 0 then
      (* 135045 *) let (ll, pres, rl) = split x l in (ll, pres, Set_gen.internal_join rl v r)
    else
      (* 130596 *) let (lr, pres, rr) = split x r in (Set_gen.internal_join l v lr, pres, rr)
let rec add x (tree : _ Set_gen.t) : _ Set_gen.t =  (* 214020 *) match tree with 
  | Empty -> (* 7860 *) Node(Empty, x, Empty, 1)
  | Node(l, v, r, _) as t ->
    (* 206160 *) let c = compare_elt x v in
    if c = 0 then (* 122751 *) t else
    (* 83409 *) if c < 0 then (* 40971 *) Set_gen.internal_bal (add x l) v r else (* 42438 *) Set_gen.internal_bal l v (add x r)

let rec union (s1 : _ Set_gen.t) (s2 : _ Set_gen.t) : _ Set_gen.t  =
  (* 373908 *) match (s1, s2) with
  | (Empty, t2) -> (* 63345 *) t2
  | (t1, Empty) -> (* 2298 *) t1
  | (Node(l1, v1, r1, h1), Node(l2, v2, r2, h2)) ->
    (* 308265 *) if h1 >= h2 then
      (* 302610 *) if h2 = 1 then (* 121611 *) add v2 s1 else (* 180999 *) begin
        let (l2, _, r2) = split v1 s2 in
        Set_gen.internal_join (union l1 l2) v1 (union r1 r2)
      end
    else
    (* 5655 *) if h1 = 1 then (* 0 *) add v1 s2 else (* 5655 *) begin
      let (l1, _, r1) = split v2 s1 in
      Set_gen.internal_join (union l1 l2) v2 (union r1 r2)
    end    

let rec inter (s1 : _ Set_gen.t)  (s2 : _ Set_gen.t) : _ Set_gen.t  =
  (* 0 *) match (s1, s2) with
  | (Empty, t2) -> (* 0 *) Empty
  | (t1, Empty) -> (* 0 *) Empty
  | (Node(l1, v1, r1, _), t2) ->
    (* 0 *) begin match split v1 t2 with
      | (l2, false, r2) ->
        (* 0 *) Set_gen.internal_concat (inter l1 l2) (inter r1 r2)
      | (l2, true, r2) ->
        (* 0 *) Set_gen.internal_join (inter l1 l2) v1 (inter r1 r2)
    end 

let rec diff (s1 : _ Set_gen.t) (s2 : _ Set_gen.t) : _ Set_gen.t  =
  (* 0 *) match (s1, s2) with
  | (Empty, t2) -> (* 0 *) Empty
  | (t1, Empty) -> (* 0 *) t1
  | (Node(l1, v1, r1, _), t2) ->
    (* 0 *) begin match split v1 t2 with
      | (l2, false, r2) ->
        (* 0 *) Set_gen.internal_join (diff l1 l2) v1 (diff r1 r2)
      | (l2, true, r2) ->
        (* 0 *) Set_gen.internal_concat (diff l1 l2) (diff r1 r2)    
    end


let rec mem x (tree : _ Set_gen.t) =  (* 0 *) match tree with 
  | Empty -> (* 0 *) false
  | Node(l, v, r, _) ->
    (* 0 *) let c = compare_elt x v in
    c = 0 || mem x (if c < 0 then (* 0 *) l else (* 0 *) r)

let rec remove x (tree : _ Set_gen.t) : _ Set_gen.t = (* 0 *) match tree with 
  | Empty -> (* 0 *) Empty
  | Node(l, v, r, _) ->
    (* 0 *) let c = compare_elt x v in
    if c = 0 then (* 0 *) Set_gen.internal_merge l r else
    (* 0 *) if c < 0 then (* 0 *) Set_gen.internal_bal (remove x l) v r else (* 0 *) Set_gen.internal_bal l v (remove x r)

let compare s1 s2 = (* 0 *) Set_gen.compare compare_elt s1 s2 


let equal s1 s2 =
  (* 0 *) compare s1 s2 = 0

let rec subset (s1 : _ Set_gen.t) (s2 : _ Set_gen.t) =
  (* 0 *) match (s1, s2) with
  | Empty, _ ->
    (* 0 *) true
  | _, Empty ->
    (* 0 *) false
  | Node (l1, v1, r1, _), (Node (l2, v2, r2, _) as t2) ->
    (* 0 *) let c = compare_elt v1 v2 in
    if c = 0 then
      (* 0 *) subset l1 l2 && subset r1 r2
    else (* 0 *) if c < 0 then
      (* 0 *) subset (Node (l1, v1, Empty, 0)) l2 && subset r1 t2
    else
      (* 0 *) subset (Node (Empty, v1, r1, 0)) r2 && subset l1 t2




let rec find x (tree : _ Set_gen.t) = (* 0 *) match tree with
  | Empty -> (* 0 *) raise Not_found
  | Node(l, v, r, _) ->
    (* 0 *) let c = compare_elt x v in
    if c = 0 then (* 0 *) v
    else (* 0 *) find x (if c < 0 then (* 0 *) l else (* 0 *) r)



let of_list l =
  (* 0 *) match l with
  | [] -> (* 0 *) empty
  | [x0] -> (* 0 *) singleton x0
  | [x0; x1] -> (* 0 *) add x1 (singleton x0)
  | [x0; x1; x2] -> (* 0 *) add x2 (add x1 (singleton x0))
  | [x0; x1; x2; x3] -> (* 0 *) add x3 (add x2 (add x1 (singleton x0)))
  | [x0; x1; x2; x3; x4] -> (* 0 *) add x4 (add x3 (add x2 (add x1 (singleton x0))))
  | _ -> (* 0 *) of_sorted_list (List.sort_uniq compare_elt l)

let of_array l = 
  (* 9 *) Array.fold_left (fun  acc x -> (* 9000 *) add x acc) empty l

(* also check order *)
let invariant t =
  (* 621 *) Set_gen.check t ;
  Set_gen.is_ordered compare_elt t          






end
module Ounit_bal_tree_tests
= struct
#1 "ounit_bal_tree_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal


let suites = 
  __FILE__ >:::
  [
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_bool __LOC__
        (Set_poly.invariant 
           (Set_poly.of_array (Array.init 1000 (fun n -> (* 3000 *) n))))
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_bool __LOC__
        (Set_poly.invariant 
           (Set_poly.of_array (Array.init 1000 (fun n -> (* 3000 *) 1000-n))))
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_bool __LOC__
        (Set_poly.invariant 
           (Set_poly.of_array (Array.init 1000 (fun n -> (* 3000 *) Random.int 1000))))
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_bool __LOC__
        (Set_poly.invariant 
           (Set_poly.of_sorted_list (Array.to_list (Array.init 1000 (fun n -> (* 3000 *) n)))))
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) let arr = Array.init 1000 (fun n -> (* 3000 *) n) in
      let set = (Set_poly.of_sorted_array arr) in
      OUnit.assert_bool __LOC__
        (Set_poly.invariant set );
      OUnit.assert_equal 1000 (Set_poly.cardinal set)    
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) for i = 0 to 200 do 
        (* 603 *) let arr = Array.init i (fun n -> (* 60300 *) n) in
        let set = (Set_poly.of_sorted_array arr) in
        OUnit.assert_bool __LOC__
          (Set_poly.invariant set );
        OUnit.assert_equal i (Set_poly.cardinal set)
      done    
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) let arr_size = 200 in
      let arr_sets = Array.make 200 Set_poly.empty in  
      for i = 0 to arr_size - 1 do
        (* 600 *) let size = Random.int 1000 in  
        let arr = Array.init size (fun n -> (* 309144 *) n) in
        arr_sets.(i)<- (Set_poly.of_sorted_array arr)            
      done;
      let large = Array.fold_left Set_poly.union Set_poly.empty arr_sets in 
      OUnit.assert_bool __LOC__ (Set_poly.invariant large)
    end;

     __LOC__ >:: begin fun _ ->
      (* 3 *) let arr_size = 1_00_000 in
      let v = ref Set_int.empty in 
      for i = 0 to arr_size - 1 do
        (* 300000 *) let size = Random.int 0x3FFFFFFF in  
         v := Set_int.add size !v                      
      done;       
      OUnit.assert_bool __LOC__ (Set_int.invariant !v)
    end;

  ]


type ident = { stamp : int ; name : string ; mutable flags : int}

module Ident_set = Set.Make(struct type t = ident 
    let compare = Pervasives.compare end)

let compare_ident x y = 
  (* 0 *) let a =  compare (x.stamp : int) y.stamp in 
  if a <> 0 then (* 0 *) a 
  else 
    (* 0 *) let b = compare (x.name : string) y.name in 
    if b <> 0 then (* 0 *) b 
    else (* 0 *) compare (x.flags : int) y.flags     

let rec add x (tree : _ Set_gen.t) : _ Set_gen.t =
  (* 0 *) match tree with  
    | Empty -> (* 0 *) Node(Empty, x, Empty, 1)
  | Node(l, v, r, _) as t ->
    (* 0 *) let c = compare_ident x v in
    if c = 0 then (* 0 *) t else
    (* 0 *) if c < 0 then (* 0 *) Set_gen.internal_bal (add x l) v r else (* 0 *) Set_gen.internal_bal l v (add x r)

let rec mem x (tree : _ Set_gen.t) = 
  (* 0 *) match tree with 
   | Empty -> (* 0 *) false
   | Node(l, v, r, _) ->
    (* 0 *) let c = compare_ident x v in
    c = 0 || mem x (if c < 0 then (* 0 *) l else (* 0 *) r)

module Ident_set2 = Set.Make(struct type t = ident 
    let compare  = compare_ident            
  end)

let bench () = 
  (* 0 *) let times = 1_000_000 in
  Ounit_tests_util.time "functor set" begin fun _ -> 
    (* 0 *) let v = ref Ident_set.empty in  
    for i = 0 to  times do
      (* 0 *) v := Ident_set.add   {stamp = i ; name = "name"; flags = -1 } !v 
    done;
    for i = 0 to times do
      (* 0 *) ignore @@ Ident_set.mem   {stamp = i; name = "name" ; flags = -1} !v 
    done 
  end ;
  Ounit_tests_util.time "functor set (specialized)" begin fun _ -> 
    (* 0 *) let v = ref Ident_set2.empty in  
    for i = 0 to  times do
      (* 0 *) v := Ident_set2.add   {stamp = i ; name = "name"; flags = -1 } !v 
    done;
    for i = 0 to times do
      (* 0 *) ignore @@ Ident_set2.mem   {stamp = i; name = "name" ; flags = -1} !v 
    done 
  end ;

  Ounit_tests_util.time "poly set" begin fun _ -> 
    (* 0 *) let v = ref Set_poly.empty in  
    for i = 0 to  times do
      (* 0 *) v := Set_poly.add   {stamp = i ; name = "name"; flags = -1 } !v 
    done;
    for i = 0 to times do
      (* 0 *) ignore @@ Set_poly.mem   {stamp = i; name = "name" ; flags = -1} !v 
    done;
  end;
  Ounit_tests_util.time "poly set (specialized)" begin fun _ -> 
    (* 0 *) let v = ref Set_gen.empty in  
    for i = 0 to  times do
      (* 0 *) v := add   {stamp = i ; name = "name"; flags = -1 } !v 
    done;
    for i = 0 to times do
      (* 0 *) ignore @@ mem   {stamp = i; name = "name" ; flags = -1} !v 
    done 

  end ; 

end
module Literals : sig 
#1 "literals.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)






val js_array_ctor : string 
val js_type_number : string
val js_type_string : string
val js_type_object : string
val js_undefined : string
val js_prop_length : string

val param : string
val partial_arg : string
val prim : string

(**temporary varaible used in {!Js_ast_util} *)
val tmp : string 

val create : string 

val app : string
val app_array : string

val runtime : string
val stdlib : string
val imul : string

val setter_suffix : string
val setter_suffix_len : int


val debugger : string
val raw_expr : string
val raw_stmt : string
val unsafe_downgrade : string
val fn_run : string
val method_run : string
val fn_method : string
val fn_mk : string

(** callback actually, not exposed to user yet *)
(* val js_fn_runmethod : string *)

val bs_deriving : string
val bs_deriving_dot : string
val bs_type : string

(** nodejs *)

val node_modules : string
val node_modules_length : int
val package_json : string
val bsconfig_json : string
val build_ninja : string
val suffix_cmj : string
val suffix_cmi : string
val suffix_ml : string
val suffix_mlast : string 
val suffix_mliast : string
val suffix_mll : string
val suffix_re : string
val suffix_rei : string 

val suffix_d : string
val suffix_mlastd : string
val suffix_mliastd : string
val suffix_js : string
val suffix_mli : string 
val suffix_cmt : string 
val suffix_cmti : string 

val commonjs : string 
val amdjs : string 
val goog : string 
val es6 : string 
val es6_global : string
val amdjs_global : string 
val unused_attribute : string 
val dash_nostdlib : string

val reactjs_jsx_ppx_exe : string 

val unescaped_j_delimiter : string 
val escaped_j_delimiter : string 

val unescaped_js_delimiter : string 

val native : string
val bytecode : string
val js : string

end = struct
#1 "literals.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)







let js_array_ctor = "Array"
let js_type_number = "number"
let js_type_string = "string"
let js_type_object = "object" 
let js_undefined = "undefined"
let js_prop_length = "length"

let prim = "prim"
let param = "param"
let partial_arg = "partial_arg"
let tmp = "tmp"

let create = "create" (* {!Caml_exceptions.create}*)

let app = "_"
let app_array = "app" (* arguments are an array*)

let runtime = "runtime" (* runtime directory *)

let stdlib = "stdlib"

let imul = "imul" (* signed int32 mul *)

let setter_suffix = "#="
let setter_suffix_len = String.length setter_suffix

let debugger = "debugger"
let raw_expr = "raw_expr"
let raw_stmt = "raw_stmt"
let unsafe_downgrade = "unsafe_downgrade"
let fn_run = "fn_run"
let method_run = "method_run"

let fn_method = "fn_method"
let fn_mk = "fn_mk"
(*let js_fn_runmethod = "js_fn_runmethod"*)

let bs_deriving = "bs.deriving"
let bs_deriving_dot = "bs.deriving."
let bs_type = "bs.type"


(** nodejs *)
let node_modules = "node_modules"
let node_modules_length = String.length "node_modules"
let package_json = "package.json"
let bsconfig_json = "bsconfig.json"
let build_ninja = "build.ninja"

let suffix_cmj = ".cmj"
let suffix_cmi = ".cmi"
let suffix_mll = ".mll"
let suffix_ml = ".ml"
let suffix_mli = ".mli"
let suffix_re = ".re"
let suffix_rei = ".rei"

let suffix_cmt = ".cmt" 
let suffix_cmti = ".cmti" 
let suffix_mlast = ".mlast"
let suffix_mliast = ".mliast"
let suffix_d = ".d"
let suffix_mlastd = ".mlast.d"
let suffix_mliastd = ".mliast.d"
let suffix_js = ".js"

let commonjs = "commonjs" 
let amdjs = "amdjs"
let goog = "goog"
let es6 = "es6"
let es6_global = "es6-global"
let amdjs_global = "amdjs-global"
let unused_attribute = "Unused attribute " 
let dash_nostdlib = "-nostdlib"

let reactjs_jsx_ppx_exe  = "reactjs_jsx_ppx.exe"

let unescaped_j_delimiter = "j"
let unescaped_js_delimiter = "js"
let escaped_j_delimiter =  "*j" (* not user level syntax allowed *)

let native = "native"
let bytecode = "bytecode"
let js = "js"

end
module Ounit_cmd_util : sig 
#1 "ounit_cmd_util.mli"
type output = {
  stderr : string ; 
  stdout : string ;
  exit_code : int 
}


val perform : string -> string array -> output 


val perform_bsc : string array -> output 


val bsc_eval : string -> output 

val debug_output : output -> unit 
end = struct
#1 "ounit_cmd_util.ml"
let (//) = Filename.concat

(** may nonterminate when [cwd] is '.' *)
let rec unsafe_root_dir_aux cwd  = 
  (* 6 *) if Sys.file_exists (cwd//Literals.bsconfig_json) then (* 3 *) cwd 
  else (* 3 *) unsafe_root_dir_aux (Filename.dirname cwd)     

let project_root = unsafe_root_dir_aux (Sys.getcwd ())
let jscomp = project_root // "jscomp"
let bsc_bin = jscomp // "bin" 

let bsc_exe = bsc_bin // "bsc.exe"
let runtime_dir = jscomp // "runtime"
let others_dir = jscomp // "others"
let stdlib_dir = jscomp // "stdlib"

let rec safe_dup fd =
  (* 0 *) let new_fd = Unix.dup fd in
  if (Obj.magic new_fd : int) >= 3 then
    (* 0 *) new_fd (* [dup] can not be 0, 1, 2*)
  else (* 0 *) begin
    let res = safe_dup fd in
    Unix.close new_fd;
    res
  end

let safe_close fd =
  (* 120 *) try Unix.close fd with Unix.Unix_error(_,_,_) -> (* 0 *) ()


type output = {
  stderr : string ; 
  stdout : string ;
  exit_code : int 
}

let perform command args = 
  (* 60 *) let new_fd_in, new_fd_out = Unix.pipe () in 
  let err_fd_in, err_fd_out = Unix.pipe () in 
  match Unix.fork () with 
  | 0 -> 
    (* 0 *) begin try 
        safe_close new_fd_in;  
        safe_close err_fd_in;
        Unix.dup2 err_fd_out Unix.stderr ; 
        Unix.dup2 new_fd_out Unix.stdout; 
        Unix.execv command args 
      with _ -> 
        (* 0 *) exit 127
    end
  | pid ->
    (* when all the descriptors on a pipe's input are closed and the pipe is 
        empty, a call to [read] on its output returns zero: end of file.
       when all the descriptiors on a pipe's output are closed, a call to 
       [write] on its input kills the writing process (EPIPE).
    *)
    (* 60 *) safe_close new_fd_out ; 
    safe_close err_fd_out ; 
    let in_chan = Unix.in_channel_of_descr new_fd_in in 
    let err_in_chan = Unix.in_channel_of_descr err_fd_in in 
    let buf = Buffer.create 1024 in 
    let err_buf = Buffer.create 1024 in 
    (try 
       while true do 
         (* 237 *) Buffer.add_string buf (input_line in_chan );             
         Buffer.add_char buf '\n'
       done;
     with
       End_of_file -> (* 60 *) ()) ; 
    (try 
       while true do 
         (* 459 *) Buffer.add_string err_buf (input_line err_in_chan );
         Buffer.add_char err_buf '\n'
       done;
     with
       End_of_file -> (* 60 *) ()) ; 
    let exit_code = match snd @@ Unix.waitpid [] pid with 
      | Unix.WEXITED exit_code -> (* 60 *) exit_code 
      | Unix.WSIGNALED _signal_number 
      | Unix.WSTOPPED _signal_number  -> (* 0 *) 127 in 
    {
      stdout = Buffer.contents buf ; 
      stderr = Buffer.contents err_buf;
      exit_code 
    }


let perform_bsc args = 
  (* 60 *) perform bsc_exe 
    (Array.append 
       [|bsc_exe ; 
         "-bs-package-name" ; "bs-platform"; 
         "-bs-no-version-header"; 
         "-bs-cross-module-opt";
         "-w";
         "-40";
         "-I" ;
         runtime_dir ; 
         "-I"; 
         others_dir ; 
         "-I" ; 
         stdlib_dir
       |] args)

let bsc_eval str = 
  (* 51 *) perform_bsc [|"-bs-eval"; str|]        

  let debug_output o = 
  (* 1 *) Printf.printf "\nexit_code:%d\nstdout:%s\nstderr:%s\n"
    o.exit_code o.stdout o.stderr

end
module Ounit_cmd_tests
= struct
#1 "ounit_cmd_tests.ml"
let (//) = Filename.concat




let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal





(* let output_of_exec_command command args =
    let readme, writeme = Unix.pipe () in 
    let pid = Unix.create_process command args Unix.stdin writeme Unix.stderr in 
    let in_chan = Unix.in_channel_of_descr readme *)


let react = {|
type u 

external a : u = "react" [@@bs.module]

external b : unit -> int = "bool" [@@bs.module "react"]

let v = a
let h = b ()

|}        
let foo_react = {|
type bla


external foo : bla = "foo.react" [@@bs.module]

external bar : unit -> bla  = "bar" [@@bs.val] [@@bs.module "foo.react"]

let c = foo 

let d = bar ()

|}

let perform_bsc = Ounit_cmd_util.perform_bsc
let bsc_eval = Ounit_cmd_util.bsc_eval


let suites = 
  __FILE__
  >::: [
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let v_output = perform_bsc  [| "-v" |] in 
      OUnit.assert_bool __LOC__ ((perform_bsc [| "-h" |]).exit_code  <> 0  );
      OUnit.assert_bool __LOC__ (v_output.exit_code = 0);
      (* Printf.printf "\n*>%s" v_output.stdout; *)
      (* Printf.printf "\n*>%s" v_output.stderr ; *)
    end; 
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let simple_quote = 
        perform_bsc  [| "-bs-eval"; {|let str = "'a'" |}|] in 
      OUnit.assert_bool __LOC__ (simple_quote.exit_code = 0)
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_be_warning = 
        bsc_eval  {|let bla4 foo x y= foo##(method1 x y [@bs]) |} in 
      (* debug_output should_be_warning; *)
      OUnit.assert_bool __LOC__ (Ext_string.contain_substring
                                   should_be_warning.stderr Literals.unused_attribute)
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let dedupe_require = 
        bsc_eval (react ^ foo_react) in 
      OUnit.assert_bool __LOC__ (Ext_string.non_overlap_count
                                   dedupe_require.stdout ~sub:"require" = 2
                                )     
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let dedupe_require = 
        bsc_eval react in 
      OUnit.assert_bool __LOC__ (Ext_string.non_overlap_count
                                   dedupe_require.stdout ~sub:"require" = 1
                                )     
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let dedupe_require = 
        bsc_eval foo_react in 
      OUnit.assert_bool __LOC__ (Ext_string.non_overlap_count
                                   dedupe_require.stdout ~sub:"require" = 1
                                )     
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
external ff : 
    resp -> (_ [@bs.as "x"]) -> int -> unit = 
    "x" [@@bs.set]      
      |} in 
      OUnit.assert_bool __LOC__ 
      (Ext_string.contain_substring should_err.stderr
      "Ill defined"
      )
    end;

    __LOC__ >:: begin fun _ -> 
(** used in return value 
    This should fail, we did not 
    support uncurry return value yet
*)
    (* 3 *) let should_err = bsc_eval {|
    external v3 :
    int -> int -> (int -> int -> int [@bs.uncurry])
    = ""[@@bs.val]

    |} in 
    (* Ounit_cmd_util.debug_output should_err;*)
    OUnit.assert_bool __LOC__
    (Ext_string.contain_substring 
    should_err.stderr "bs.uncurry")
    end ;

    __LOC__ >:: begin fun _ -> 
    (* 3 *) let should_err = bsc_eval {|
    external v4 :  
    (int -> int -> int [@bs.uncurry]) = ""
    [@@bs.val]

    |} in 
    (* Ounit_cmd_util.debug_output should_err ; *)
    OUnit.assert_bool __LOC__
    (Ext_string.contain_substring 
    should_err.stderr "bs.uncurry")
  end ;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
      {js| \uFFF|js}
      |} in 
      OUnit.assert_bool __LOC__ (not @@ Ext_string.is_empty should_err.stderr)
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
      external mk : int -> ([`a|`b] [@bs.string]) = "" [@@bs.val]
      |} in 
      OUnit.assert_bool __LOC__ (not @@ Ext_string.is_empty should_err.stderr)
    end;
    
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
      external mk : int -> ([`a|`b] ) = "" [@@bs.val]
      |} in 
      OUnit.assert_bool __LOC__ ( Ext_string.is_empty should_err.stderr)
      (* give a warning or ? 
         ( [`a | `b ] [@bs.string] ) 
         (* auto-convert to ocaml poly-variant *)
      *)
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
      type t 
      external mk : int -> (_ [@bs.as {json| { x : 3 } |json}]) ->  t = "" [@@bs.val]
      |} in 
      OUnit.assert_bool __LOC__ (Ext_string.contain_substring should_err.stderr "Invalid json literal")
    end
    ;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
      type t 
      external mk : int -> (_ [@bs.as {json| { "x" : 3 } |json}]) ->  t = "" [@@bs.val]
      |} in 
      OUnit.assert_bool __LOC__ (Ext_string.is_empty should_err.stderr)
    end
    ;
    (* #1510 *)
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
       let should_fail = fun [@bs.this] (Some x) y u -> y + u 
      |} in 
      OUnit.assert_bool __LOC__ 
        (Ext_string.contain_substring  should_err.stderr "simple")
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let should_err = bsc_eval {|
       let should_fail = fun [@bs.this] (Some x as v) y u -> y + u 
      |} in 
      (* Ounit_cmd_util.debug_output should_err; *)
      OUnit.assert_bool __LOC__ 
        (Ext_string.contain_substring  should_err.stderr "simple")
    end;
    
  ]


end
module Ounit_ffi_error_debug_test
= struct
#1 "ounit_ffi_error_debug_test.ml"
let (//) = Filename.concat




let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal




let bsc_eval = Ounit_cmd_util.bsc_eval

let debug_output = Ounit_cmd_util.debug_output


let suites = 
    __FILE__ 
    >::: [
        __LOC__ >:: begin fun _ -> 
        (* 3 *) let output = bsc_eval {|
external err : 
   hi_should_error:([`a of int | `b of string ] [@bs.string]) ->         
   unit -> _ = "" [@@bs.obj]
        |} in
        OUnit.assert_bool __LOC__
            (Ext_string.contain_substring output.stderr "hi_should_error")
        end;
        __LOC__ >:: begin fun _ -> 
(* 3 *) let output = bsc_eval {|
    external err : 
   ?hi_should_error:([`a of int | `b of string ] [@bs.string]) ->         
   unit -> _ = "" [@@bs.obj]
        |} in
        OUnit.assert_bool __LOC__
            (Ext_string.contain_substring output.stderr "hi_should_error")        
        end;
        __LOC__ >:: begin fun _ -> 
        (* 3 *) let output = bsc_eval {|
    external err : 
   ?hi_should_error:([`a of int | `b of string ] [@bs.string]) ->         
   unit -> unit = "" [@@bs.val]
        |} in
        OUnit.assert_bool __LOC__
            (Ext_string.contain_substring output.stderr "hi_should_error")        
        end

        

    ]
end
module Ext_util : sig 
#1 "ext_util.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


 
val power_2_above : int -> int -> int


val stats_to_string : Hashtbl.statistics -> string 
end = struct
#1 "ext_util.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

(**
   {[
     (power_2_above 16 63 = 64)
       (power_2_above 16 76 = 128)
   ]}
*)
let rec power_2_above x n =
  (* 276 *) if x >= n then (* 105 *) x
  else (* 171 *) if x * 2 > Sys.max_array_length then (* 0 *) x
  else (* 171 *) power_2_above (x * 2) n


let stats_to_string ({num_bindings; num_buckets; max_bucket_length; bucket_histogram} : Hashtbl.statistics) = 
  (* 12 *) Printf.sprintf 
    "bindings: %d,buckets: %d, longest: %d, hist:[%s]" 
    num_bindings 
    num_buckets 
    max_bucket_length
    (String.concat "," (Array.to_list (Array.map string_of_int bucket_histogram)))
end
module Hash_set_gen
= struct
#1 "hash_set_gen.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


(* We do dynamic hashing, and resize the table and rehash the elements
   when buckets become too long. *)

type 'a t =
  { mutable size: int;                        (* number of entries *)
    mutable data: 'a list array;  (* the buckets *)
    initial_size: int;                        (* initial array size *)
  }




let create  initial_size =
  (* 24 *) let s = Ext_util.power_2_above 16 initial_size in
  { initial_size = s; size = 0; data = Array.make s [] }

let clear h =
  (* 0 *) h.size <- 0;
  let len = Array.length h.data in
  for i = 0 to len - 1 do
    (* 0 *) Array.unsafe_set h.data i  []
  done

let reset h =
  (* 0 *) h.size <- 0;
  h.data <- Array.make h.initial_size [ ]


let copy h = (* 0 *) { h with data = Array.copy h.data }

let length h = (* 33 *) h.size

let iter f h =
  (* 0 *) let rec do_bucket = function
    | [ ] ->
      (* 0 *) ()
    | k ::  rest ->
      (* 0 *) f k ; do_bucket rest in
  let d = h.data in
  for i = 0 to Array.length d - 1 do
    (* 0 *) do_bucket (Array.unsafe_get d i)
  done

let fold f h init =
  (* 0 *) let rec do_bucket b accu =
    (* 0 *) match b with
      [ ] ->
      (* 0 *) accu
    | k ::  rest ->
      (* 0 *) do_bucket rest (f k  accu) in
  let d = h.data in
  let accu = ref init in
  for i = 0 to Array.length d - 1 do
    (* 0 *) accu := do_bucket (Array.unsafe_get d i) !accu
  done;
  !accu

let resize indexfun h =
  (* 42 *) let odata = h.data in
  let osize = Array.length odata in
  let nsize = osize * 2 in
  if nsize < Sys.max_array_length then (* 42 *) begin
    let ndata = Array.make nsize [ ] in
    h.data <- ndata;          (* so that indexfun sees the new bucket count *)
    let rec insert_bucket = function
        [ ] -> (* 7392 *) ()
      | key :: rest ->
        (* 14826 *) let nidx = indexfun h key in
        ndata.(nidx) <- key :: ndata.(nidx);
        insert_bucket rest
    in
    for i = 0 to osize - 1 do
      (* 7392 *) insert_bucket (Array.unsafe_get odata i)
    done
  end

let elements set = 
  (* 0 *) fold  (fun k  acc ->  (* 0 *) k :: acc) set []




let stats h =
  (* 0 *) let mbl =
    Array.fold_left (fun m b -> (* 0 *) max m (List.length b)) 0 h.data in
  let histo = Array.make (mbl + 1) 0 in
  Array.iter
    (fun b ->
       (* 0 *) let l = List.length b in
       histo.(l) <- histo.(l) + 1)
    h.data;
  {Hashtbl.num_bindings = h.size;
   num_buckets = Array.length h.data;
   max_bucket_length = mbl;
   bucket_histogram = histo }

let rec small_bucket_mem eq_key key lst =
  (* 78609 *) match lst with 
  | [] -> (* 6096 *) false 
  | key1::rest -> 
    (* 72513 *) eq_key key   key1 ||
    match rest with 
    | [] -> (* 5895 *) false 
    | key2 :: rest -> 
      (* 22194 *) eq_key key   key2 ||
      match rest with 
      | [] -> (* 3987 *) false 
      | key3 :: rest -> 
        (* 9591 *) eq_key key   key3 ||
        small_bucket_mem eq_key key rest 

let rec remove_bucket eq_key key (h : _ t) buckets = 
  (* 34053 *) match buckets with 
  | [ ] ->
    (* 12006 *) [ ]
  | k :: next ->
    (* 22047 *) if  eq_key k   key
    then (* 3039 *) begin h.size <- h.size - 1; next end
    else (* 19008 *) k :: remove_bucket eq_key key h next    

module type S =
sig
  type key
  type t
  val create: int ->  t
  val clear : t -> unit
  val reset : t -> unit
  val copy: t -> t
  val remove:  t -> key -> unit
  val add :  t -> key -> unit
  val of_array : key array -> t 
  val check_add : t -> key -> bool
  val mem :  t -> key -> bool
  val iter: (key -> unit) ->  t -> unit
  val fold: (key -> 'b -> 'b) ->  t -> 'b -> 'b
  val length:  t -> int
  val stats:  t -> Hashtbl.statistics
  val elements : t -> key list 
end

end
module Hash_set : sig 
#1 "hash_set.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

(** Ideas are based on {!Hashtbl}, 
    however, {!Hashtbl.add} does not really optimize and has a bad semantics for {!Hash_set}, 
    This module fixes the semantics of [add].
    [remove] is not optimized since it is not used too much 
*)





module Make ( H : Hashtbl.HashedType) : (Hash_set_gen.S with type key = H.t)
(** A naive t implementation on top of [hashtbl], the value is [unit]*)


end = struct
#1 "hash_set.ml"
# 1 "ext/hash_set.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)
# 43
module Make (H: Hashtbl.HashedType) : (Hash_set_gen.S with type key = H.t) = struct 
type key = H.t 
let eq_key = H.equal
let key_index (h :  _ Hash_set_gen.t ) key =
  (* 39588 *) (H.hash  key) land (Array.length h.data - 1)
type t = key Hash_set_gen.t



# 62
let create = Hash_set_gen.create
let clear = Hash_set_gen.clear
let reset = Hash_set_gen.reset
let copy = Hash_set_gen.copy
let iter = Hash_set_gen.iter
let fold = Hash_set_gen.fold
let length = Hash_set_gen.length
let stats = Hash_set_gen.stats
let elements = Hash_set_gen.elements



let remove (h : _ Hash_set_gen.t) key =  
  (* 12006 *) let i = key_index h key in
  let h_data = h.data in
  let old_h_size = h.size in 
  let new_bucket = Hash_set_gen.remove_bucket eq_key key h (Array.unsafe_get h_data i) in
  if old_h_size <> h.size then  
    (* 3003 *) Array.unsafe_set h_data i new_bucket



let add (h : _ Hash_set_gen.t) key =
  (* 12309 *) let i = key_index h key  in 
  let h_data = h.data in 
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 6306 *) begin 
      Array.unsafe_set h_data i (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 15 *) Hash_set_gen.resize key_index h
    end

let of_array arr = 
  (* 0 *) let len = Array.length arr in 
  let tbl = create len in 
  for i = 0 to len - 1  do
    (* 0 *) add tbl (Array.unsafe_get arr i);
  done ;
  tbl 
  
    
let check_add (h : _ Hash_set_gen.t) key =
  (* 0 *) let i = key_index h key  in 
  let h_data = h.data in  
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 0 *) begin 
      Array.unsafe_set h_data i  (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 0 *) Hash_set_gen.resize key_index h;
      true 
    end
  else (* 0 *) false 


let mem (h :  _ Hash_set_gen.t) key =
  (* 9306 *) Hash_set_gen.small_bucket_mem eq_key key (Array.unsafe_get h.data (key_index h key)) 

# 122
end
  

end
module Hash_set_poly : sig 
#1 "hash_set_poly.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


type   'a t 

val create : int -> 'a t

val clear : 'a t -> unit

val reset : 'a t -> unit

val copy : 'a t -> 'a t

val add : 'a t -> 'a  -> unit
val remove : 'a t -> 'a -> unit

val mem : 'a t -> 'a -> bool

val iter : ('a -> unit) -> 'a t -> unit

val elements : 'a t -> 'a list

val length : 'a t -> int 

val stats:  'a t -> Hashtbl.statistics

end = struct
#1 "hash_set_poly.ml"
# 1 "ext/hash_set.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)
# 51
external seeded_hash_param :
  int -> int -> int -> 'a -> int = "caml_hash" "noalloc"
let key_index (h :  _ Hash_set_gen.t ) (key : 'a) =
  (* 62907 *) seeded_hash_param 10 100 0 key land (Array.length h.data - 1)
let eq_key = (=)
type  'a t = 'a Hash_set_gen.t 


# 62
let create = Hash_set_gen.create
let clear = Hash_set_gen.clear
let reset = Hash_set_gen.reset
let copy = Hash_set_gen.copy
let iter = Hash_set_gen.iter
let fold = Hash_set_gen.fold
let length = Hash_set_gen.length
let stats = Hash_set_gen.stats
let elements = Hash_set_gen.elements



let remove (h : _ Hash_set_gen.t) key =  
  (* 3033 *) let i = key_index h key in
  let h_data = h.data in
  let old_h_size = h.size in 
  let new_bucket = Hash_set_gen.remove_bucket eq_key key h (Array.unsafe_get h_data i) in
  if old_h_size <> h.size then  
    (* 33 *) Array.unsafe_set h_data i new_bucket



let add (h : _ Hash_set_gen.t) key =
  (* 45012 *) let i = key_index h key  in 
  let h_data = h.data in 
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 9009 *) begin 
      Array.unsafe_set h_data i (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 27 *) Hash_set_gen.resize key_index h
    end

let of_array arr = 
  (* 0 *) let len = Array.length arr in 
  let tbl = create len in 
  for i = 0 to len - 1  do
    (* 0 *) add tbl (Array.unsafe_get arr i);
  done ;
  tbl 
  
    
let check_add (h : _ Hash_set_gen.t) key =
  (* 0 *) let i = key_index h key  in 
  let h_data = h.data in  
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 0 *) begin 
      Array.unsafe_set h_data i  (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 0 *) Hash_set_gen.resize key_index h;
      true 
    end
  else (* 0 *) false 


let mem (h :  _ Hash_set_gen.t) key =
  (* 6003 *) Hash_set_gen.small_bucket_mem eq_key key (Array.unsafe_get h.data (key_index h key)) 

  

end
module Bs_hash_stubs
= struct
#1 "bs_hash_stubs.ml"
external hash_string :  string -> int = "caml_bs_hash_string" "noalloc";;

external hash_string_int :  string -> int  -> int = "caml_bs_hash_string_and_int" "noalloc";;

external hash_string_small_int :  string -> int  -> int = "caml_bs_hash_string_and_small_int" "noalloc";;

external hash_stamp_and_name : int -> string -> int = "caml_bs_hash_stamp_and_name" "noalloc";;

external hash_small_int : int -> int = "caml_bs_hash_small_int" "noalloc";;

external hash_int :  int  -> int = "caml_bs_hash_int" "noalloc";;

external string_length_based_compare : string -> string -> int  = "caml_string_length_based_compare" "noalloc";;


external    
    int_unsafe_blit : 
    int array -> int -> int array -> int -> int -> unit = "caml_int_array_blit" "noalloc";;
end
module Ordered_hash_set_gen
= struct
#1 "ordered_hash_set_gen.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

module type S =
sig
  type key
  type t
  val create: int ->  t
  val clear: t -> unit
  val reset: t -> unit
  val copy: t -> t
  val add:  t -> key -> unit
  val mem:  t -> key -> bool
  val rank: t -> key -> int (* -1 if not found*)
  val iter: (key -> int -> unit) ->  t -> unit
  val fold: (key -> int -> 'b -> 'b) ->  t -> 'b -> 'b
  val length:  t -> int
  val stats:  t -> Hashtbl.statistics
  val choose_exn: t -> key 
  val of_array: key array -> t 
  val to_sorted_array: t -> key array
  val replace: t -> key -> key -> unit 
  val reset_to_list : t -> key list -> unit
  exception Replace_failure of bool 
end

exception Replace_failure of bool 


(** when it is true, it means the old key does not exist ,
    when it is false, it means the new key already exist
  *)

(* We do dynamic hashing, and resize the table and rehash the elements
   when buckets become too long. *)
type 'a bucket = 
  | Empty 
  | Cons of 'a * int * 'a bucket

type 'a t =
  { mutable size: int; (* number of entries *)
    mutable data: 'a bucket array;  
    mutable data_mask: int ; 
    initial_size: int;
  }
(* Invariant
   [data_mask = Array.length data - 1 ]
   [Array.length data is power of 2]
*)


let create  initial_size =
  (* 39 *) let initial_size = Ext_util.power_2_above 16 initial_size in
  { initial_size ; 
    size = 0; 
    data = Array.make initial_size Empty;
    data_mask = initial_size - 1 ;  
  }

let clear h =
  (* 6 *) h.size <- 0;
  let h_data = h.data in 
  for i = 0 to h.data_mask  do 
    (* 4718592 *) Array.unsafe_set h_data i  Empty
  done

(** Note this function is only used internally, make sure [h_initial_size] 
    is a power of 16 *)
let reset_with_size h h_initial_size  =
  (* 0 *) h.size <- 0;
  h.data <- Array.make h_initial_size Empty;
  h.data_mask <- h_initial_size - 1

let reset h  =
  (* 0 *) reset_with_size h h.initial_size


let copy h = (* 0 *) { h with data = Array.copy h.data }

let length h = (* 15 *) h.size


let rec insert_bucket nmask ndata hash = function
  | Empty -> (* 1364742 *) ()
  | Cons(key,info,rest) ->
    (* 1793442 *) let nidx = hash key land nmask in (* so that indexfun sees the new bucket count *)
    Array.unsafe_set ndata nidx  (Cons(key,info, (Array.unsafe_get ndata nidx)));
    insert_bucket nmask ndata hash rest

let resize hash h =
  (* 72 *) let odata = h.data in
  let odata_mask = h.data_mask in 
  let nsize = (odata_mask + 1) * 2 in
  if nsize < Sys.max_array_length then (* 72 *) begin
    let ndata = Array.make nsize Empty in
    h.data <- ndata;          
    let nmask = nsize - 1 in
    h.data_mask <- nmask ; 
    for i = 0 to odata_mask do
      (* 1579056 *) match Array.unsafe_get odata i with 
      | Empty -> (* 214314 *) ()
      | Cons(key,info,rest) -> 
        (* 1364742 *) let nidx = hash key land nmask in 
        Array.unsafe_set ndata nidx  (Cons(key,info, (Array.unsafe_get ndata nidx)));
        insert_bucket nmask ndata hash rest 
    done
  end


let rec do_bucket f = function
  | Empty ->
    (* 4718592 *) ()
  | Cons(k ,i,  rest) ->
    (* 6000000 *) f k i ; do_bucket f rest 

let iter f h =
  (* 6 *) let d = h.data in
  for i = 0 to h.data_mask do
    (* 4718592 *) do_bucket f (Array.unsafe_get d i)
  done

(* find one element *)
let choose_exn h = 
  (* 30 *) let rec aux arr offset last_index = 
    (* 147 *) if offset > last_index then 
      (* 3 *) raise Not_found (* This happens when size is 0, otherwise it is never called *)
    else 
      (* 144 *) match Array.unsafe_get arr offset with 
      | Empty -> (* 117 *) aux arr (offset + 1) last_index 
      | Cons (k,_,rest) -> (* 27 *) k 
  in
  let h_data = h.data in 
  aux h_data 0 h.data_mask

let fold f h init =
  (* 6 *) let rec do_bucket b accu =
    (* 10718592 *) match b with
      Empty ->
      (* 4718592 *) accu
    | Cons( k , i,  rest) ->
      (* 6000000 *) do_bucket rest (f k i  accu) in
  let d = h.data in
  let accu = ref init in
  for i = 0 to h.data_mask do
    (* 4718592 *) accu := do_bucket (Array.unsafe_get d i) !accu
  done;
  !accu


let rec set_bucket arr = function 
  | Empty -> (* 15744 *) ()
  | Cons(k,i,rest) ->
    (* 16830 *) Array.unsafe_set arr i k;
    set_bucket arr rest 

let to_sorted_array h = 
  (* 33 *) if h.size = 0 then (* 6 *) [||]
  else 
    (* 27 *) let v = choose_exn h in 
    let arr = Array.make h.size v in
    let d = h.data in 
    for i = 0 to h.data_mask do 
      (* 15744 *) set_bucket  arr (Array.unsafe_get d i)
    done;
    arr 




let rec bucket_length acc (x : _ bucket) = 
  (* 21467574 *) match x with 
  | Empty -> (* 9449568 *) acc
  | Cons(_,_,rest) -> (* 12018006 *) bucket_length (acc + 1) rest  

let stats h =
  (* 12 *) let mbl =
    Array.fold_left (fun m (b : _ bucket) -> (* 4724784 *) max m (bucket_length 0 b)) 0 h.data in
  let histo = Array.make (mbl + 1) 0 in
  Array.iter
    (fun b ->
       (* 4724784 *) let l = bucket_length 0 b in
       histo.(l) <- histo.(l) + 1)
    h.data;
  { Hashtbl.num_bindings = h.size;
    num_buckets = h.data_mask + 1 ;
    max_bucket_length = mbl;
    bucket_histogram = histo }


end
module Ordered_hash_set_string : sig 
#1 "ordered_hash_set_string.mli"




include Ordered_hash_set_gen.S with type key = string
end = struct
#1 "ordered_hash_set_string.ml"
  
# 11 "ext/ordered_hash_set.cppo.ml"
  type key = string 
  type t = key Ordered_hash_set_gen.t
  let hash = Bs_hash_stubs.hash_string
  let equal_key = Ext_string.equal

# 24
open Ordered_hash_set_gen
exception Replace_failure = Replace_failure
let create = create
let clear = clear
let reset = reset
let copy = copy
let iter = iter
let fold = fold
let length = length
let stats = stats
let choose_exn = choose_exn
let to_sorted_array = to_sorted_array



let rec small_bucket_mem key lst =
  (* 13037994 *) match lst with 
  | Empty -> (* 3083325 *) false 
  | Cons(key1,_, rest) -> 
    (* 9954669 *) equal_key key key1 ||
    match rest with 
    | Empty -> (* 1934643 *) false 
    | Cons(key2 , _, rest) -> 
      (* 4489941 *) equal_key key  key2 ||
      match rest with 
      | Empty -> (* 1001862 *) false 
      | Cons(key3,_,  rest) -> 
        (* 1735125 *) equal_key key  key3 ||
        small_bucket_mem key rest 

let rec small_bucket_rank key lst =
  (* 6367491 *) match lst with 
  | Empty -> (* 0 *) -1
  | Cons(key1,i,rest) -> 
    (* 6367491 *) if equal_key key key1 then (* 3528888 *) i 
    else (* 2838603 *) match rest with 
      | Empty -> (* 0 *) -1 
      | Cons(key2,i2,  rest) -> 
        (* 2838603 *) if equal_key key  key2 then (* 1752675 *) i2 else
          (* 1085928 *) match rest with 
          | Empty -> (* 0 *) -1 
          | Cons(key3,i3, rest) -> 
            (* 1085928 *) if equal_key key  key3 then (* 718437 *) i3 else
              (* 367491 *) small_bucket_rank key rest 

let add h key =
  (* 6018360 *) let h_data_mask = h.data_mask in 
  let i = hash key land h_data_mask in 
  if not (small_bucket_mem key  h.data.(i)) then 
    (* 6016830 *) begin 
      Array.unsafe_set h.data i (Cons(key,h.size, Array.unsafe_get h.data i));
      h.size <- h.size + 1 ;
      if h.size > Array.length h.data lsl 1 then (* 72 *) resize hash h
    end

let old_key_not_exist = Replace_failure false 
let new_key_already_exist = Replace_failure true 

let rec small_bucket_rank_and_delete key lst =
  (* 3204 *) match lst with 
  | Empty -> (* 0 *) raise old_key_not_exist
  | Cons(key1,i,rest) -> 
    (* 3204 *) if equal_key key key1 then (* 1287 *) i, rest  
    else (* 1917 *) match rest with 
      | Empty -> (* 0 *) raise old_key_not_exist
      | Cons(key2,i2,  rest) -> 
        (* 1917 *) if equal_key key  key2 then (* 1191 *) i2, (Cons (key1,i,rest)) else
          (* 726 *) match rest with 
          | Empty -> (* 0 *) raise old_key_not_exist
          | Cons(key3,i3, rest) -> 
            (* 726 *) if equal_key key  key3 then (* 522 *) i3, (Cons (key1,i,Cons(key2,i2,rest))) else
              (* 204 *) let (rank, rest ) = small_bucket_rank_and_delete key rest in 
              rank, Cons (key1,i, 
                    Cons (key2,i2, 
                          Cons(key3,i3,rest))) 

let replace h old_key new_key =
  (* 3000 *) let h_data_mask = h.data_mask in 
  let i = hash old_key land h_data_mask in
  let h_data = h.data in 
  let bucket = Array.unsafe_get h_data  i in 
  let (rank,new_bucket) = small_bucket_rank_and_delete old_key bucket in 
  Array.unsafe_set h_data  i new_bucket ; 

  let j = hash new_key land h_data_mask in 
  let insert_bucket = Array.unsafe_get h_data j in 
  let mem = small_bucket_mem new_key insert_bucket in 
  if mem then (* 0 *) raise new_key_already_exist
  else 
    (* 3000 *) Array.unsafe_set h_data j (Cons (new_key,rank, insert_bucket))

let of_array arr =
  (* 24 *) let len = Array.length arr in 
  let h = create len in 
  for i = 0 to len - 1 do 
    (* 9027 *) add h (Array.unsafe_get arr i)
  done;
  h

(* clear the Hashset and re-initialize it to [lst] *)
let reset_to_list h lst =
  (* 0 *) let len = List.length lst in
  let () = Ordered_hash_set_gen.reset_with_size h (Ext_util.power_2_above 16 len) in
  List.iter (fun x -> (* 0 *) add h x ) lst 

let mem h key =
  (* 6000000 *) small_bucket_mem key (Array.unsafe_get h.data (hash  key land h.data_mask)) 

let rank h key = 
  (* 6000000 *) small_bucket_rank key (Array.unsafe_get h.data (hash  key land h.data_mask))  













end
module String_hash_set : sig 
#1 "string_hash_set.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


include Hash_set_gen.S with type key = string

end = struct
#1 "string_hash_set.ml"
# 1 "ext/hash_set.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)
# 31
type key = string 
let key_index (h :  _ Hash_set_gen.t ) (key : key) =
  (* 678 *) (Bs_hash_stubs.hash_string  key) land (Array.length h.data - 1)
let eq_key = Ext_string.equal 
type  t = key  Hash_set_gen.t 


# 62
let create = Hash_set_gen.create
let clear = Hash_set_gen.clear
let reset = Hash_set_gen.reset
let copy = Hash_set_gen.copy
let iter = Hash_set_gen.iter
let fold = Hash_set_gen.fold
let length = Hash_set_gen.length
let stats = Hash_set_gen.stats
let elements = Hash_set_gen.elements



let remove (h : _ Hash_set_gen.t) key =  
  (* 6 *) let i = key_index h key in
  let h_data = h.data in
  let old_h_size = h.size in 
  let new_bucket = Hash_set_gen.remove_bucket eq_key key h (Array.unsafe_get h_data i) in
  if old_h_size <> h.size then  
    (* 3 *) Array.unsafe_set h_data i new_bucket



let add (h : _ Hash_set_gen.t) key =
  (* 648 *) let i = key_index h key  in 
  let h_data = h.data in 
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 642 *) begin 
      Array.unsafe_set h_data i (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 0 *) Hash_set_gen.resize key_index h
    end

let of_array arr = 
  (* 0 *) let len = Array.length arr in 
  let tbl = create len in 
  for i = 0 to len - 1  do
    (* 0 *) add tbl (Array.unsafe_get arr i);
  done ;
  tbl 
  
    
let check_add (h : _ Hash_set_gen.t) key =
  (* 24 *) let i = key_index h key  in 
  let h_data = h.data in  
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 21 *) begin 
      Array.unsafe_set h_data i  (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 0 *) Hash_set_gen.resize key_index h;
      true 
    end
  else (* 3 *) false 


let mem (h :  _ Hash_set_gen.t) key =
  (* 0 *) Hash_set_gen.small_bucket_mem eq_key key (Array.unsafe_get h.data (key_index h key)) 

  

end
module Ounit_hash_set_tests
= struct
#1 "ounit_hash_set_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal

type id = { name : string ; stamp : int }

module Id_hash_set = Hash_set.Make(struct 
    type t = id 
    let equal x y = (* 53619 *) x.stamp = y.stamp && x.name = y.name 
    let hash x = (* 39588 *) Hashtbl.hash x.stamp
  end
  )

let const_tbl = [|"0"; "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9"; "10"; "100"; "99"; "98";
          "97"; "96"; "95"; "94"; "93"; "92"; "91"; "90"; "89"; "88"; "87"; "86"; "85";
          "84"; "83"; "82"; "81"; "80"; "79"; "78"; "77"; "76"; "75"; "74"; "73"; "72";
          "71"; "70"; "69"; "68"; "67"; "66"; "65"; "64"; "63"; "62"; "61"; "60"; "59";
          "58"; "57"; "56"; "55"; "54"; "53"; "52"; "51"; "50"; "49"; "48"; "47"; "46";
          "45"; "44"; "43"; "42"; "41"; "40"; "39"; "38"; "37"; "36"; "35"; "34"; "33";
          "32"; "31"; "30"; "29"; "28"; "27"; "26"; "25"; "24"; "23"; "22"; "21"; "20";
          "19"; "18"; "17"; "16"; "15"; "14"; "13"; "12"; "11"|]
let suites = 
  __FILE__
  >:::
  [
    __LOC__ >:: begin fun _ ->
      (* 3 *) let v = Hash_set_poly.create 31 in
      for i = 0 to 1000 do
        (* 3003 *) Hash_set_poly.add v i  
      done  ;
      OUnit.assert_equal (Hash_set_poly.length v) 1001
    end ;
    __LOC__ >:: begin fun _ ->
      (* 3 *) let v = Hash_set_poly.create 31 in
      for i = 0 to 1_0_000 do
        (* 30003 *) Hash_set_poly.add v 0
      done  ;
      OUnit.assert_equal (Hash_set_poly.length v) 1
    end ;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Hash_set_poly.create 30 in 
      for i = 0 to 2_000 do 
        (* 6003 *) Hash_set_poly.add v {name = "x" ; stamp = i}
      done ;
      for i = 0 to 2_000 do 
        (* 6003 *) Hash_set_poly.add v {name = "x" ; stamp = i}
      done  ; 
      for i = 0 to 2_000 do 
        (* 6003 *) assert (Hash_set_poly.mem v {name = "x"; stamp = i})
      done;  
      OUnit.assert_equal (Hash_set_poly.length v)  2_001;
      for i =  1990 to 3_000 do 
        (* 3033 *) Hash_set_poly.remove v {name = "x"; stamp = i}
      done ;
      OUnit.assert_equal (Hash_set_poly.length v) 1990;
      (* OUnit.assert_equal (Hash_set.stats v) *)
      (*   {Hashtbl.num_bindings = 1990; num_buckets = 1024; max_bucket_length = 7; *)
      (*    bucket_histogram = [|139; 303; 264; 178; 93; 32; 12; 3|]} *)
    end ;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Id_hash_set.create 30 in 
      for i = 0 to 2_000 do 
        (* 6003 *) Id_hash_set.add v {name = "x" ; stamp = i}
      done ;
      for i = 0 to 2_000 do 
        (* 6003 *) Id_hash_set.add v {name = "x" ; stamp = i}
      done  ; 
      for i = 0 to 2_000 do 
        (* 6003 *) assert (Id_hash_set.mem v {name = "x"; stamp = i})
      done;  
      OUnit.assert_equal (Id_hash_set.length v)  2_001;
      for i =  1990 to 3_000 do 
        (* 3033 *) Id_hash_set.remove v {name = "x"; stamp = i}
      done ;
      OUnit.assert_equal (Id_hash_set.length v) 1990;
      for i = 1000 to 3990 do 
        (* 8973 *) Id_hash_set.remove v { name = "x"; stamp = i }
      done;
      OUnit.assert_equal (Id_hash_set.length v) 1000;
      for i = 1000 to 1100 do 
        (* 303 *) Id_hash_set.add v { name = "x"; stamp = i};
      done;
      OUnit.assert_equal (Id_hash_set.length v ) 1101;
      for i = 0 to 1100 do 
        (* 3303 *) OUnit.assert_bool "exist" (Id_hash_set.mem v {name = "x"; stamp = i})
      done  
      (* OUnit.assert_equal (Hash_set.stats v) *)
      (*   {num_bindings = 1990; num_buckets = 1024; max_bucket_length = 8; *)
      (*    bucket_histogram = [|148; 275; 285; 182; 95; 21; 14; 2; 2|]} *)

    end 
    ;
    __LOC__ >:: begin fun _ ->
      (* 3 *) let v = Ordered_hash_set_string.create 3 in 
      for i =  0 to 10 do
        (* 33 *) Ordered_hash_set_string.add v (string_of_int i) 
      done; 
      for i = 100 downto 2 do
        (* 297 *) Ordered_hash_set_string.add v (string_of_int i)
      done;
      OUnit.assert_equal (Ordered_hash_set_string.to_sorted_array v )
        const_tbl
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let duplicate arr = 
        (* 6 *) let len = Array.length arr in 
        let rec aux tbl off = 
          (* 27 *) if off >= len  then (* 3 *) None
          else 
            (* 24 *) let curr = (Array.unsafe_get arr off) in
            if String_hash_set.check_add tbl curr then 
              (* 21 *) aux tbl (off + 1)
            else   (* 3 *) Some curr in 
        aux (String_hash_set.create len) 0 in 
      let v = [| "if"; "a"; "b"; "c" |] in 
      OUnit.assert_equal (duplicate v) None;
      OUnit.assert_equal (duplicate [|"if"; "a"; "b"; "b"; "c"|]) (Some "b")
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let of_array lst =
        (* 3 *) let len = Array.length lst in 
        let tbl = String_hash_set.create len in 
        Array.iter (String_hash_set.add tbl ) lst; tbl  in 
      let hash = of_array const_tbl  in 
      let len = String_hash_set.length hash in 
      String_hash_set.remove hash "x";
      OUnit.assert_equal len (String_hash_set.length hash);
      String_hash_set.remove hash "0";
      OUnit.assert_equal (len - 1 ) (String_hash_set.length hash)
    end
  ]

end
module Int_hash_set : sig 
#1 "int_hash_set.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


include Hash_set_gen.S with type key = int

end = struct
#1 "int_hash_set.ml"
# 1 "ext/hash_set.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)
# 25
type key = int
let key_index (h :  _ Hash_set_gen.t ) (key : key) =
  (* 0 *) (Bs_hash_stubs.hash_int  key) land (Array.length h.data - 1)
let eq_key = Ext_int.equal 
type  t = key  Hash_set_gen.t 


# 62
let create = Hash_set_gen.create
let clear = Hash_set_gen.clear
let reset = Hash_set_gen.reset
let copy = Hash_set_gen.copy
let iter = Hash_set_gen.iter
let fold = Hash_set_gen.fold
let length = Hash_set_gen.length
let stats = Hash_set_gen.stats
let elements = Hash_set_gen.elements



let remove (h : _ Hash_set_gen.t) key =  
  (* 0 *) let i = key_index h key in
  let h_data = h.data in
  let old_h_size = h.size in 
  let new_bucket = Hash_set_gen.remove_bucket eq_key key h (Array.unsafe_get h_data i) in
  if old_h_size <> h.size then  
    (* 0 *) Array.unsafe_set h_data i new_bucket



let add (h : _ Hash_set_gen.t) key =
  (* 0 *) let i = key_index h key  in 
  let h_data = h.data in 
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 0 *) begin 
      Array.unsafe_set h_data i (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 0 *) Hash_set_gen.resize key_index h
    end

let of_array arr = 
  (* 0 *) let len = Array.length arr in 
  let tbl = create len in 
  for i = 0 to len - 1  do
    (* 0 *) add tbl (Array.unsafe_get arr i);
  done ;
  tbl 
  
    
let check_add (h : _ Hash_set_gen.t) key =
  (* 0 *) let i = key_index h key  in 
  let h_data = h.data in  
  let old_bucket = (Array.unsafe_get h_data i) in
  if not (Hash_set_gen.small_bucket_mem eq_key key old_bucket) then 
    (* 0 *) begin 
      Array.unsafe_set h_data i  (key :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 0 *) Hash_set_gen.resize key_index h;
      true 
    end
  else (* 0 *) false 


let mem (h :  _ Hash_set_gen.t) key =
  (* 0 *) Hash_set_gen.small_bucket_mem eq_key key (Array.unsafe_get h.data (key_index h key)) 

  

end
module Ounit_hash_stubs_test
= struct
#1 "ounit_hash_stubs_test.ml"
let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal

let count = 2_000_000

let bench () = 
  (* 0 *) Ounit_tests_util.time "int hash set" begin fun _ -> 
    (* 0 *) let v = Int_hash_set.create 2_000_000 in 
    for i = 0 to  count do 
      (* 0 *) Int_hash_set.add  v i
    done ;
    for i = 0 to 3 do 
      (* 0 *) for i = 0 to count do 
        (* 0 *) assert (Int_hash_set.mem v i)
      done
    done
  end;
  Ounit_tests_util.time "int hash set" begin fun _ -> 
    (* 0 *) let v = Hash_set_poly.create 2_000_000 in 
    for i = 0 to  count do 
      (* 0 *) Hash_set_poly.add  v i
    done ;
    for i = 0 to 3 do 
      (* 0 *) for i = 0 to count do 
        (* 0 *) assert (Hash_set_poly.mem v i)
     done
    done
  end


type id (* = Ident.t *) = { stamp : int; name : string; mutable flags : int; }
let hash id = (* 12 *) Bs_hash_stubs.hash_stamp_and_name id.stamp id.name 
let suites = 
    __FILE__
    >:::
    [
      __LOC__ >:: begin fun _ -> 
        (* 3 *) Bs_hash_stubs.hash_int 0 =~ Hashtbl.hash 0
      end;
      __LOC__ >:: begin fun _ -> 
        (* 3 *) Bs_hash_stubs.hash_int max_int =~ Hashtbl.hash max_int
      end;
      __LOC__ >:: begin fun _ -> 
        (* 3 *) Bs_hash_stubs.hash_int max_int =~ Hashtbl.hash max_int
      end;
      __LOC__ >:: begin fun _ -> 
        (* 3 *) Bs_hash_stubs.hash_string "The quick brown fox jumps over the lazy dog"  =~ 
        Hashtbl.hash "The quick brown fox jumps over the lazy dog"
      end;
      __LOC__ >:: begin fun _ ->
        (* 3 *) Array.init 100 (fun i -> (* 300 *) String.make i 'a' )
        |> Array.iter (fun x -> 
          (* 300 *) Bs_hash_stubs.hash_string x =~ Hashtbl.hash x) 
      end;
      __LOC__ >:: begin fun _ ->
        (** only stamp matters here *)
        (* 3 *) hash {stamp = 1 ; name = "xx"; flags = 0} =~ Bs_hash_stubs.hash_small_int 1 ;
        hash {stamp = 11 ; name = "xx"; flags = 0} =~ Bs_hash_stubs.hash_small_int 11;
      end;
      __LOC__ >:: begin fun _ ->
        (* only string matters here *)
        (* 3 *) hash {stamp = 0 ; name = "Pervasives"; flags = 0} =~ Bs_hash_stubs.hash_string "Pervasives";
        hash {stamp = 0 ; name = "UU"; flags = 0} =~ Bs_hash_stubs.hash_string "UU";
      end;
      __LOC__ >:: begin fun _ -> 
        (* 3 *) let v = Array.init 20 (fun i -> (* 60 *) i) in 
        let u = Array.init 30 (fun i ->   (* 90 *) (0-i)  ) in  
        Bs_hash_stubs.int_unsafe_blit 
         v 0 u 10 20 ; 
        OUnit.assert_equal u (Array.init 30 (fun i -> (* 90 *) if i < 10 then (* 30 *) -i else (* 60 *) i - 10)) 
      end
    ]

end
module Hashtbl_gen
= struct
#1 "hashtbl_gen.ml"
(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)

(* Hash tables *)



module type S = sig 
  type key
  type 'a t
  val create: int -> 'a t
  val clear: 'a t -> unit
  val reset: 'a t -> unit
  val copy: 'a t -> 'a t
  val add: 'a t -> key -> 'a -> unit
  val modify_or_init: 'a t -> key -> ('a -> unit) -> (unit -> 'a) -> unit 
  val remove: 'a t -> key -> unit
  val find_exn: 'a t -> key -> 'a
  val find_all: 'a t -> key -> 'a list
  val find_opt: 'a t -> key  -> 'a option
  
  (** return the key found in the hashtbl.
    Use case: when you find the key existed in hashtbl, 
    you want to use the one stored in the hashtbl. 
    (they are semantically equivlanent, but may have other information different) 
   *)
  val find_key_opt: 'a t -> key -> key option 

  val find_default: 'a t -> key -> 'a -> 'a 

  val replace: 'a t -> key -> 'a -> unit
  val mem: 'a t -> key -> bool
  val iter: (key -> 'a -> unit) -> 'a t -> unit
  val fold: (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
  val length: 'a t -> int
  val stats: 'a t -> Hashtbl.statistics
  val of_list2: key list -> 'a list -> 'a t
end

(* We do dynamic hashing, and resize the table and rehash the elements
   when buckets become too long. *)

type ('a, 'b) t =
  { mutable size: int;                        (* number of entries *)
    mutable data: ('a, 'b) bucketlist array;  (* the buckets *)
    mutable seed: int;                        (* for randomization *)
    initial_size: int;                        (* initial array size *)
  }

and ('a, 'b) bucketlist =
  | Empty
  | Cons of 'a * 'b * ('a, 'b) bucketlist


let create  initial_size =
  (* 36 *) let s = Ext_util.power_2_above 16 initial_size in
  { initial_size = s; size = 0; seed = 0; data = Array.make s Empty }

let clear h =
  (* 0 *) h.size <- 0;
  let len = Array.length h.data in
  for i = 0 to len - 1 do
    (* 0 *) h.data.(i) <- Empty
  done

let reset h =
  (* 0 *) h.size <- 0;
  h.data <- Array.make h.initial_size Empty


let copy h = (* 0 *) { h with data = Array.copy h.data }

let length h = (* 33 *) h.size

let resize indexfun h =
  (* 33 *) let odata = h.data in
  let osize = Array.length odata in
  let nsize = osize * 2 in
  if nsize < Sys.max_array_length then (* 33 *) begin
    let ndata = Array.make nsize Empty in
    h.data <- ndata;          (* so that indexfun sees the new bucket count *)
    let rec insert_bucket = function
        Empty -> (* 4512 *) ()
      | Cons(key, data, rest) ->
        (* 9057 *) insert_bucket rest; (* preserve original order of elements *)
        let nidx = indexfun h key in
        ndata.(nidx) <- Cons(key, data, ndata.(nidx)) in
    for i = 0 to osize - 1 do
      (* 4512 *) insert_bucket (Array.unsafe_get odata i)
    done
  end



let iter f h =
  (* 6 *) let rec do_bucket = function
    | Empty ->
      (* 192 *) ()
    | Cons(k, d, rest) ->
      (* 27 *) f k d; do_bucket rest in
  let d = h.data in
  for i = 0 to Array.length d - 1 do
    (* 192 *) do_bucket (Array.unsafe_get d i)
  done

let fold f h init =
  (* 0 *) let rec do_bucket b accu =
    (* 0 *) match b with
      Empty ->
      (* 0 *) accu
    | Cons(k, d, rest) ->
      (* 0 *) do_bucket rest (f k d accu) in
  let d = h.data in
  let accu = ref init in
  for i = 0 to Array.length d - 1 do
    (* 0 *) accu := do_bucket d.(i) !accu
  done;
  !accu

let rec bucket_length accu = function
  | Empty -> (* 0 *) accu
  | Cons(_, _, rest) -> (* 0 *) bucket_length (accu + 1) rest

let stats h =
  (* 0 *) let mbl =
    Array.fold_left (fun m b -> (* 0 *) max m (bucket_length 0 b)) 0 h.data in
  let histo = Array.make (mbl + 1) 0 in
  Array.iter
    (fun b ->
       (* 0 *) let l = bucket_length 0 b in
       histo.(l) <- histo.(l) + 1)
    h.data;
  {Hashtbl.
    num_bindings = h.size;
    num_buckets = Array.length h.data;
    max_bucket_length = mbl;
    bucket_histogram = histo }



let rec small_bucket_mem eq key (lst : _ bucketlist) =
  (* 0 *) match lst with 
  | Empty -> (* 0 *) false 
  | Cons(k1,_,rest1) -> 
    (* 0 *) eq  key k1 ||
    match rest1 with
    | Empty -> (* 0 *) false 
    | Cons(k2,_,rest2) -> 
      (* 0 *) eq key k2  || 
      match rest2 with 
      | Empty -> (* 0 *) false 
      | Cons(k3,_,rest3) -> 
        (* 0 *) eq key k3  ||
        small_bucket_mem eq key rest3 


let rec small_bucket_opt eq key (lst : _ bucketlist) : _ option =
  (* 0 *) match lst with 
  | Empty -> (* 0 *) None 
  | Cons(k1,d1,rest1) -> 
    (* 0 *) if eq  key k1 then (* 0 *) Some d1 else 
      (* 0 *) match rest1 with
      | Empty -> (* 0 *) None 
      | Cons(k2,d2,rest2) -> 
        (* 0 *) if eq key k2 then (* 0 *) Some d2 else 
          (* 0 *) match rest2 with 
          | Empty -> (* 0 *) None 
          | Cons(k3,d3,rest3) -> 
            (* 0 *) if eq key k3  then (* 0 *) Some d3 else 
              (* 0 *) small_bucket_opt eq key rest3 


let rec small_bucket_key_opt eq key (lst : _ bucketlist) : _ option =
  (* 0 *) match lst with 
  | Empty -> (* 0 *) None 
  | Cons(k1,d1,rest1) -> 
    (* 0 *) if eq  key k1 then (* 0 *) Some k1 else 
      (* 0 *) match rest1 with
      | Empty -> (* 0 *) None 
      | Cons(k2,d2,rest2) -> 
        (* 0 *) if eq key k2 then (* 0 *) Some k2 else 
          (* 0 *) match rest2 with 
          | Empty -> (* 0 *) None 
          | Cons(k3,d3,rest3) -> 
            (* 0 *) if eq key k3  then (* 0 *) Some k3 else 
              (* 0 *) small_bucket_key_opt eq key rest3


let rec small_bucket_default eq key default (lst : _ bucketlist) =
  (* 0 *) match lst with 
  | Empty -> (* 0 *) default 
  | Cons(k1,d1,rest1) -> 
    (* 0 *) if eq  key k1 then  (* 0 *) d1 else 
      (* 0 *) match rest1 with
      | Empty -> (* 0 *) default 
      | Cons(k2,d2,rest2) -> 
        (* 0 *) if eq key k2 then  (* 0 *) d2 else 
          (* 0 *) match rest2 with 
          | Empty -> (* 0 *) default 
          | Cons(k3,d3,rest3) -> 
            (* 0 *) if eq key k3  then  (* 0 *) d3 else 
              (* 0 *) small_bucket_default eq key default rest3 

end
module String_hashtbl : sig 
#1 "string_hashtbl.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


include Hashtbl_gen.S with type key = string




end = struct
#1 "string_hashtbl.ml"
# 9 "ext/hashtbl.cppo.ml"
type key = string
type 'a t = (key, 'a)  Hashtbl_gen.t 
let key_index (h : _ t ) (key : key) =
  (* 21720 *) (Bs_hash_stubs.hash_string  key ) land (Array.length h.data - 1)
let eq_key = Ext_string.equal 

# 33
type ('a, 'b) bucketlist = ('a,'b) Hashtbl_gen.bucketlist
let create = Hashtbl_gen.create
let clear = Hashtbl_gen.clear
let reset = Hashtbl_gen.reset
let copy = Hashtbl_gen.copy
let iter = Hashtbl_gen.iter
let fold = Hashtbl_gen.fold
let length = Hashtbl_gen.length
let stats = Hashtbl_gen.stats



let add (h : _ t) key info =
  (* 6129 *) let i = key_index h key in
  let h_data = h.data in   
  Array.unsafe_set h_data i (Cons(key, info, (Array.unsafe_get h_data i)));
  h.size <- h.size + 1;
  if h.size > Array.length h_data lsl 1 then (* 18 *) Hashtbl_gen.resize key_index h

(* after upgrade to 4.04 we should provide an efficient [replace_or_init] *)
let modify_or_init (h : _ t) key modf default =
  (* 0 *) let rec find_bucket (bucketlist : _ bucketlist)  =
    (* 0 *) match bucketlist with
    | Cons(k,i,next) ->
      (* 0 *) if eq_key k key then (* 0 *) begin modf i; false end
      else (* 0 *) find_bucket next 
    | Empty -> (* 0 *) true in
  let i = key_index h key in 
  let h_data = h.data in 
  if find_bucket (Array.unsafe_get h_data i) then
    (* 0 *) begin 
      Array.unsafe_set h_data i  (Cons(key,default (), Array.unsafe_get h_data i));
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 0 *) Hashtbl_gen.resize key_index h 
    end


let rec remove_bucket key (h : _ t) (bucketlist : _ bucketlist) : _ bucketlist = 
  (* 0 *) match bucketlist with  
  | Empty ->
    (* 0 *) Empty
  | Cons(k, i, next) ->
    (* 0 *) if eq_key k key 
    then (* 0 *) begin h.size <- h.size - 1; next end
    else (* 0 *) Cons(k, i, remove_bucket key h next) 

let remove (h : _ t ) key =
  (* 0 *) let i = key_index h key in
  let h_data = h.data in 
  let old_h_szie = h.size in 
  let new_bucket = remove_bucket key h (Array.unsafe_get h_data i) in  
  if old_h_szie <> h.size then 
    (* 0 *) Array.unsafe_set h_data i  new_bucket

let rec find_rec key (bucketlist : _ bucketlist) = (* 0 *) match bucketlist with  
  | Empty ->
    (* 0 *) raise Not_found
  | Cons(k, d, rest) ->
    (* 0 *) if eq_key key k then (* 0 *) d else (* 0 *) find_rec key rest

let find_exn (h : _ t) key =
  (* 267 *) match Array.unsafe_get h.data (key_index h key) with
  | Empty -> (* 0 *) raise Not_found
  | Cons(k1, d1, rest1) ->
    (* 267 *) if eq_key key k1 then (* 261 *) d1 else
      (* 6 *) match rest1 with
      | Empty -> (* 0 *) raise Not_found
      | Cons(k2, d2, rest2) ->
        (* 6 *) if eq_key key k2 then (* 6 *) d2 else
          (* 0 *) match rest2 with
          | Empty -> (* 0 *) raise Not_found
          | Cons(k3, d3, rest3) ->
            (* 0 *) if eq_key key k3  then (* 0 *) d3 else (* 0 *) find_rec key rest3

let find_opt (h : _ t) key =
  (* 0 *) Hashtbl_gen.small_bucket_opt eq_key key (Array.unsafe_get h.data (key_index h key))

let find_key_opt (h : _ t) key =
  (* 0 *) Hashtbl_gen.small_bucket_key_opt eq_key key (Array.unsafe_get h.data (key_index h key))
  
let find_default (h : _ t) key default = 
  (* 0 *) Hashtbl_gen.small_bucket_default eq_key key default (Array.unsafe_get h.data (key_index h key))
let find_all (h : _ t) key =
  (* 0 *) let rec find_in_bucket (bucketlist : _ bucketlist) = (* 0 *) match bucketlist with 
    | Empty ->
      (* 0 *) []
    | Cons(k, d, rest) ->
      (* 0 *) if eq_key k key 
      then (* 0 *) d :: find_in_bucket rest
      else (* 0 *) find_in_bucket rest in
  find_in_bucket (Array.unsafe_get h.data (key_index h key))

let replace h key info =
  (* 6000 *) let rec replace_bucket (bucketlist : _ bucketlist) : _ bucketlist = (* 13386 *) match bucketlist with 
    | Empty ->
      (* 3000 *) raise_notrace Not_found
    | Cons(k, i, next) ->
      (* 10386 *) if eq_key k key
      then (* 3000 *) Cons(key, info, next)
      else (* 7386 *) Cons(k, i, replace_bucket next) in
  let i = key_index h key in
  let h_data = h.data in 
  let l = Array.unsafe_get h_data i in
  try
    Array.unsafe_set h_data i  (replace_bucket l)
  with Not_found ->
    (* 3000 *) begin 
      Array.unsafe_set h_data i (Cons(key, info, l));
      h.size <- h.size + 1;
      if h.size > Array.length h_data lsl 1 then (* 15 *) Hashtbl_gen.resize key_index h;
    end 

let mem (h : _ t) key =
  (* 267 *) let rec mem_in_bucket (bucketlist : _ bucketlist) = (* 273 *) match bucketlist with 
    | Empty ->
      (* 129 *) false
    | Cons(k, d, rest) ->
      (* 144 *) eq_key k key  || mem_in_bucket rest in
  mem_in_bucket (Array.unsafe_get h.data (key_index h key))


let of_list2 ks vs = 
  (* 0 *) let len = List.length ks in 
  let map = create len in 
  List.iter2 (fun k v -> (* 0 *) add map k v) ks vs ; 
  map


end
module Ounit_hashtbl_tests
= struct
#1 "ounit_hashtbl_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal


let suites = 
  __FILE__
  >:::[
    (* __LOC__ >:: begin fun _ ->  *)
    (*   let h = String_hashtbl.create 0 in  *)
    (*   let accu key = *)
    (*     String_hashtbl.replace_or_init h key   succ 1 in  *)
    (*   let count = 1000 in  *)
    (*   for i = 0 to count - 1 do      *)
    (*     Array.iter accu  [|"a";"b";"c";"d";"e";"f"|]     *)
    (*   done; *)
    (*   String_hashtbl.length h =~ 6; *)
    (*   String_hashtbl.iter (fun _ v -> v =~ count ) h *)
    (* end; *)

    "add semantics " >:: begin fun _ -> 
      (* 3 *) let h = String_hashtbl.create 0 in 
      let count = 1000 in 
      for j = 0 to 1 do  
        (* 6 *) for i = 0 to count - 1 do                 
          (* 6000 *) String_hashtbl.add h (string_of_int i) i 
        done
      done ;
      String_hashtbl.length h =~ 2 * count 
    end; 
    "replace semantics" >:: begin fun _ -> 
      (* 3 *) let h = String_hashtbl.create 0 in 
      let count = 1000 in 
      for j = 0 to 1 do  
        (* 6 *) for i = 0 to count - 1 do                 
          (* 6000 *) String_hashtbl.replace h (string_of_int i) i 
        done
      done ;
      String_hashtbl.length h =~  count 
    end; 
    
  ]

end
module Ext_ident : sig 
#1 "ext_ident.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








(** A wrapper around [Ident] module in compiler-libs*)

val is_js : Ident.t -> bool

val is_js_object : Ident.t -> bool

(** create identifiers for predefined [js] global variables *)
val create_js : string -> Ident.t

val create : string -> Ident.t

val create_js_module : string -> Ident.t 

val make_js_object : Ident.t -> unit

val reset : unit -> unit

val gen_js :  ?name:string -> unit -> Ident.t

val make_unused : unit -> Ident.t

val is_unused_ident : Ident.t -> bool 

(**
   if name is not converted, the reference should be equal
*)
val convert : bool -> string -> string
val property_no_need_convert : string -> bool 

val undefined : Ident.t 
val is_js_or_global : Ident.t -> bool
val nil : Ident.t


val compare : Ident.t -> Ident.t -> int
val equal : Ident.t -> Ident.t -> bool 

end = struct
#1 "ext_ident.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








let js_flag = 0b1000 (* check with ocaml compiler *)

let js_module_flag = 0b1_0000 (* javascript external modules *)
(* TODO:
    check name conflicts with javascript conventions
    {[
    Ext_ident.convert "^";;
    - : string = "$caret"
    ]}
 *)
let js_object_flag = 0b10_0000 (* javascript object flags *)

let is_js (i : Ident.t) = 
  (* 0 *) i.flags land js_flag <> 0 

let is_js_or_global (i : Ident.t) = 
  (* 0 *) i.flags land (8 lor 1) <> 0 

let is_js_module (i : Ident.t) =
  (* 0 *) i.flags land js_module_flag <> 0 

let is_js_object (i : Ident.t) = 
  (* 0 *) i.flags land js_object_flag <> 0 

let make_js_object (i : Ident.t) = 
  (* 0 *) i.flags <- i.flags lor js_object_flag 
      
(* It's a js function hard coded by js api, so when printing,
   it should preserve the name 
 *)
let create_js (name : string) : Ident.t  = 
  (* 6 *) { name = name; flags = js_flag ; stamp = 0}

let js_module_table : Ident.t String_hashtbl.t = String_hashtbl.create 31 

(* This is for a js exeternal module, we can change it when printing
   for example
   {[
   var React$1 = require('react');
   React$1.render(..)
   ]}

   Given a name, if duplicated, they should  have the same id
 *)
let create_js_module (name : string) : Ident.t = 
  (* 0 *) let name = 
    String.concat "" @@ List.map (String.capitalize ) @@ 
    Ext_string.split name '-' in
  (* TODO: if we do such transformation, we should avoid 
      collision for example:
      react-dom 
      react--dom
      check collision later
   *)
  match String_hashtbl.find_exn js_module_table name  with 
  | exception Not_found -> 
      (* 0 *) let v = Ident.create name in
      let ans = { v with flags = js_module_flag} in 
      String_hashtbl.add js_module_table name ans;
      ans
  | v -> (* 0 *) v 

let create = Ident.create

let gen_js ?(name="$js") () = (* 0 *) create name 

let reserved_words = 
  [|
    (* keywork *)
    "break";
    "case"; "catch"; "continue";
    "debugger";"default";"delete";"do";
    "else";
    "finally";"for";"function";
    "if"; "then"; "in";"instanceof";
    "new";
    "return";
    "switch";
    "this"; "throw"; "try"; "typeof";
    "var"; "void"; "while"; "with";

    (* reserved in ECMAScript 5 *)
    "class"; "enum"; "export"; "extends"; "import"; "super";

    "implements";"interface";
    "let";
    "package";"private";"protected";"public";
    "static";
    "yield";

    (* other *)
    "null";
    "true";
    "false";
    "NaN";


    "undefined";
    "this";

    (* also reserved in ECMAScript 3 *)
    "abstract"; "boolean"; "byte"; "char"; "const"; "double";
    "final"; "float"; "goto"; "int"; "long"; "native"; "short";
    "synchronized"; 
    (* "throws";  *)
    (* seems to be fine, like nodejs [assert.throws] *)
    "transient"; "volatile";

    (* also reserved in ECMAScript 6 *)
    "await";
   
   "event";
   "location";
   "window";
   "document";
   "eval";
   "navigator";
   (* "self"; *)
   
   "Array";
   "Date";
   "Math";
   "JSON";
   "Object";
   "RegExp";
   "String";
   "Boolean";
   "Number";

   "Map"; (* es6*)
   "Set";

   "Infinity";
   "isFinite";
   
   "ActiveXObject";
   "XMLHttpRequest";
   "XDomainRequest";
   
   "DOMException";
   "Error";
   "SyntaxError";
   "arguments";
   
   "decodeURI";
   "decodeURIComponent";
   "encodeURI";
   "encodeURIComponent";
   "escape";
   "unescape";

   "isNaN";
   "parseFloat";
   "parseInt";
   
   (** reserved for commonjs and NodeJS globals*)   
   "require";
   "exports";
   "module";
    "clearImmediate";
    "clearInterval";
    "clearTimeout";
    "console";
    "global";
    "process";
    "require";
    "setImmediate";
    "setInterval";
    "setTimeout";
    "__dirname";
    "__filename"
  |]

let reserved_map = 
  let len = Array.length reserved_words in 
  let set =  String_hash_set.create 1024 in (* large hash set for perfect hashing *)
  for i = 0 to len - 1 do 
    (* 345 *) String_hash_set.add set reserved_words.(i);
  done ;
  set 





(* TODO:
    check name conflicts with javascript conventions
    {[
    Ext_ident.convert "^";;
    - : string = "$caret"
    ]}
 *)
let convert keyword (name : string) = 
   (* 0 *) if keyword && String_hash_set.mem reserved_map name  then (* 0 *) "$$" ^ name 
   else 
     (* 0 *) let module E = struct exception Not_normal_letter of int end in
     let len = String.length name  in
     try
       for i  = 0 to len - 1 do 
         (* 0 *) match String.unsafe_get name i with 
         | 'a' .. 'z' | 'A' .. 'Z'
         | '0' .. '9' | '_' | '$' -> (* 0 *) ()
         | _ -> (* 0 *) raise (E.Not_normal_letter i)
       done;
       name
     with E.Not_normal_letter i ->
       (* 0 *) String.sub name 0 i ^ 
       (let buffer = Buffer.create len in 
        for j = i to  len - 1 do 
          (* 0 *) let c = String.unsafe_get name j in
          match c with 
          | '*' -> (* 0 *) Buffer.add_string buffer "$star"
          | '\'' -> (* 0 *) Buffer.add_string buffer "$prime"
          | '!' -> (* 0 *) Buffer.add_string buffer "$bang"
          | '>' -> (* 0 *) Buffer.add_string buffer "$great"
          | '<' -> (* 0 *) Buffer.add_string buffer "$less"
          | '=' -> (* 0 *) Buffer.add_string buffer "$eq"
          | '+' -> (* 0 *) Buffer.add_string buffer "$plus"
          | '-' -> (* 0 *) Buffer.add_string buffer "$neg"
          | '@' -> (* 0 *) Buffer.add_string buffer "$at"
          | '^' -> (* 0 *) Buffer.add_string buffer "$caret"
          | '/' -> (* 0 *) Buffer.add_string buffer "$slash"
          | '|' -> (* 0 *) Buffer.add_string buffer "$pipe"
          | '.' -> (* 0 *) Buffer.add_string buffer "$dot"
          | '%' -> (* 0 *) Buffer.add_string buffer "$percent"
          | '~' -> (* 0 *) Buffer.add_string buffer "$tilde"
          | '#' -> (* 0 *) Buffer.add_string buffer "$hash"
          | 'a'..'z' | 'A'..'Z'| '_'|'$' |'0'..'9'-> (* 0 *) Buffer.add_char buffer  c
          | _ -> (* 0 *) Buffer.add_string buffer "$unknown"
        done; Buffer.contents buffer)

let property_no_need_convert s = 
  (* 0 *) s == convert false s 

(* It is currently made a persistent ident to avoid fresh ids 
    which would result in different signature files
    - other solution: use lazy values
*)
let make_unused () = (* 0 *) create "_"

let is_unused_ident i = (* 0 *) Ident.name i = "_"

let reset () = 
  (* 0 *) String_hashtbl.clear js_module_table


let undefined = create_js "undefined"
let nil = create_js "null"

(* Has to be total order, [x < y] 
   and [x > y] should be consistent
   flags are not relevant here 
 *)
let compare (x : Ident.t ) ( y : Ident.t) = 
  (* 0 *) let u = x.stamp - y.stamp in
  if u = 0 then 
     (* 0 *) Ext_string.compare x.name y.name 
  else (* 0 *) u 

let equal ( x : Ident.t) ( y : Ident.t) = 
  (* 28494 *) if x.stamp <> 0 then (* 28494 *) x.stamp = y.stamp
  else (* 0 *) y.stamp = 0 && x.name = y.name
   

end
module Hash_set_ident_mask : sig 
#1 "hash_set_ident_mask.mli"


(** Based on [hash_set] specialized for mask operations  *)
type ident = Ident.t  


type t
val create: int ->  t


(* add one ident *)
val add_unmask :  t -> ident -> unit


(** [check_mask h key] if [key] exists mask it otherwise nothing
    return true if all keys are masked otherwise false
*)
val mask_check_all_hit : ident ->  t -> bool

(** [iter_and_unmask f h] iterating the collection and mask all idents,
    dont consul the collection in function [f]
    TODO: what happens if an exception raised in the callback,
    would the hashtbl still be in consistent state?
*)
val iter_and_unmask: (ident -> bool ->  unit) ->  t -> unit



  

end = struct
#1 "hash_set_ident_mask.ml"

(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)



type ident = Ident.t

type key = {ident : ident ; mutable mask : bool }

type t = {
  mutable size : int ; 
  mutable data : key list array;
  initial_size : int ; 
  mutable mask_size : int (* mark how many idents are marked *)
}



let key_index_by_ident (h : t) (key : Ident.t) =    
  (* 18057 *) (Bs_hash_stubs.hash_string_int  key.name key.stamp) land (Array.length h.data - 1)

let key_index (h :  t ) ({ident = key} : key) =
  (* 3042 *) key_index_by_ident h key 


let create  initial_size =
  (* 6 *) let s = Ext_util.power_2_above 8 initial_size in
  { initial_size = s; size = 0; data = Array.make s [] ; mask_size = 0}

let iter_and_unmask f h =
  (* 6 *) let rec do_bucket buckets = 
    (* 4566 *) match buckets with 
    | [ ] ->
      (* 1560 *) ()
    | k ::  rest ->    
      (* 3006 *) f k.ident k.mask ;
      if k.mask then 
        (* 3006 *) begin 
          k.mask <- false ;
          (* we can set [h.mask_size] to zero,
             however, it would result inconsistent state
             once [f] throw
          *)
          h.mask_size <- h.mask_size - 1
        end; 
      do_bucket rest 
  in
  let d = h.data in
  for i = 0 to Array.length d - 1 do
    (* 1560 *) do_bucket (Array.unsafe_get d i)
  done
  

let rec small_bucket_mem key lst =
  (* 3600 *) match lst with 
  | [] -> (* 1017 *) false 
  | {ident = key1 }::rest -> 
    (* 2583 *) Ext_ident.equal key   key1 ||
    match rest with 
    | [] -> (* 1206 *) false 
    | {ident = key2} :: rest -> 
      (* 1374 *) Ext_ident.equal key   key2 ||
      match rest with 
      | [] -> (* 783 *) false 
      | {ident = key3; _} :: rest -> 
        (* 591 *) Ext_ident.equal key   key3 ||
        small_bucket_mem key rest 

let resize indexfun h =
  (* 18 *) let odata = h.data in
  let osize = Array.length odata in
  let nsize = osize * 2 in
  if nsize < Sys.max_array_length then (* 18 *) begin
    let ndata = Array.make nsize [ ] in
    h.data <- ndata;          (* so that indexfun sees the new bucket count *)
    let rec insert_bucket = function
        [ ] -> (* 1512 *) ()
      | key :: rest ->
        (* 3042 *) let nidx = indexfun h key in
        ndata.(nidx) <- key :: ndata.(nidx);
        insert_bucket rest
    in
    for i = 0 to osize - 1 do
      (* 1512 *) insert_bucket (Array.unsafe_get odata i)
    done
  end

let add_unmask (h : t) (key : Ident.t) =
  (* 3009 *) let i = key_index_by_ident h key  in 
  let h_data = h.data in 
  let old_bucket = Array.unsafe_get h_data i in
  if not (small_bucket_mem key old_bucket) then 
    (* 3006 *) begin 
      Array.unsafe_set h_data i ({ident = key; mask = false} :: old_bucket);
      h.size <- h.size + 1 ;
      if h.size > Array.length h_data lsl 1 then (* 18 *) resize key_index h
    end




let rec small_bucket_mask  key lst =
  (* 13386 *) match lst with 
  | [] -> (* 0 *) false 
  | key1::rest -> 
    (* 13386 *) if Ext_ident.equal key   key1.ident  then 
      (* 6162 *) if key1.mask then (* 3072 *) false else (* 3090 *) (key1.mask <- true ; true) 
    else 
      (* 7224 *) match rest with 
      | [] -> (* 0 *) false
      | key2 :: rest -> 
        (* 7224 *) if Ext_ident.equal key key2.ident  then 
          (* 3888 *) if key2.mask then (* 1944 *) false else (* 1944 *) (key2.mask <- true ; true)
        else 
          (* 3336 *) match rest with 
          | [] -> (* 0 *) false
          | key3 :: rest -> 
            (* 3336 *) if Ext_ident.equal key key3.ident then 
              (* 1956 *) if key3.mask then (* 978 *) false else (* 978 *) (key3.mask <- true ; true)
            else 
              (* 1380 *) small_bucket_mask  key rest 

let mask_check_all_hit (key : Ident.t) (h : t)  =     
  (* 12006 *) if 
    small_bucket_mask key 
      (Array.unsafe_get h.data (key_index_by_ident h key )) then 
    (* 6012 *) begin 
      h.mask_size <- h.mask_size + 1 
    end;
  h.size = h.mask_size 




end
module Ounit_ident_mask_tests
= struct
#1 "ounit_ident_mask_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal
let suites = 
  __FILE__
  >:::
  [
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let set = Hash_set_ident_mask.create 0  in
      let a,b,c,d = 
        Ident.create "a", 
        Ident.create "b", 
        Ident.create "c",
        Ident.create "d" in 
      Hash_set_ident_mask.add_unmask set a ;     
      Hash_set_ident_mask.add_unmask set a ;     
      Hash_set_ident_mask.add_unmask set b ;     
      OUnit.assert_bool __LOC__ (not @@ Hash_set_ident_mask.mask_check_all_hit a set );
      OUnit.assert_bool __LOC__ (Hash_set_ident_mask.mask_check_all_hit b set );
      Hash_set_ident_mask.iter_and_unmask (fun id mask -> 
          (* 6 *) if id.Ident.name = "a" then
            (* 3 *) OUnit.assert_bool __LOC__ mask 
          else (* 3 *) if id.Ident.name = "b" then 
            (* 3 *) OUnit.assert_bool __LOC__ mask 
          else (* 0 *) ()        
        ) set ;
      OUnit.assert_bool __LOC__ (not @@ Hash_set_ident_mask.mask_check_all_hit a set );
      OUnit.assert_bool __LOC__ (Hash_set_ident_mask.mask_check_all_hit b set );
    end;
    __LOC__ >:: begin fun _ -> 
        (* 3 *) let len = 1000 in 
        let idents = Array.init len (fun i -> (* 3000 *) Ident.create (string_of_int i)) in 
        let set = Hash_set_ident_mask.create 0 in 
        Array.iter (fun i -> (* 3000 *) Hash_set_ident_mask.add_unmask set i) idents;
        for i = 0 to len - 2 do 
                (* 2997 *) OUnit.assert_bool __LOC__ (not @@ Hash_set_ident_mask.mask_check_all_hit idents.(i) set);
        done ;
         for i = 0 to len - 2 do 
                (* 2997 *) OUnit.assert_bool __LOC__ (not @@ Hash_set_ident_mask.mask_check_all_hit idents.(i) set);
        done ; 
         OUnit.assert_bool __LOC__ (Hash_set_ident_mask.mask_check_all_hit idents.(len - 1) set) ;
         Hash_set_ident_mask.iter_and_unmask (fun id mask -> (* 3000 *) ()) set;
        for i = 0 to len - 2 do 
                (* 2997 *) OUnit.assert_bool __LOC__ (not @@ Hash_set_ident_mask.mask_check_all_hit idents.(i) set);
        done ;
         for i = 0 to len - 2 do 
                (* 2997 *) OUnit.assert_bool __LOC__ (not @@ Hash_set_ident_mask.mask_check_all_hit idents.(i) set);
        done ; 
         OUnit.assert_bool __LOC__ (Hash_set_ident_mask.mask_check_all_hit idents.(len - 1) set) ;
         
    end
  ]
end
module Vec_gen
= struct
#1 "vec_gen.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


module type ResizeType = 
sig 
  type t 
  val null : t (* used to populate new allocated array checkout {!Obj.new_block} for more performance *)
end

module type S = 
sig 
  type elt 
  type t
  val length : t -> int 
  val compact : t -> unit
  val singleton : elt -> t 
  val empty : unit -> t 
  val make : int -> t 
  val init : int -> (int -> elt) -> t
  val is_empty : t -> bool
  val of_array : elt array -> t
  val of_sub_array : elt array -> int -> int -> t

  (** Exposed for some APIs which only take array as input, 
      when exposed   
  *)
  val unsafe_internal_array : t -> elt array
  val reserve : t -> int -> unit
  val push :  elt -> t -> unit
  val delete : t -> int -> unit 
  val pop : t -> unit
  val get_last_and_pop : t -> elt
  val delete_range : t -> int -> int -> unit 
  val get_and_delete_range : t -> int -> int -> t
  val clear : t -> unit 
  val reset : t -> unit 
  val to_list : t -> elt list 
  val of_list : elt list -> t
  val to_array : t -> elt array 
  val of_array : elt array -> t
  val copy : t -> t 
  val reverse_in_place : t -> unit
  val iter : (elt -> unit) -> t -> unit 
  val iteri : (int -> elt -> unit ) -> t -> unit 
  val iter_range : from:int -> to_:int -> (elt -> unit) -> t -> unit 
  val iteri_range : from:int -> to_:int -> (int -> elt -> unit) -> t -> unit
  val map : (elt -> elt) -> t ->  t
  val mapi : (int -> elt -> elt) -> t -> t
  val map_into_array : (elt -> 'f) -> t -> 'f array
  val map_into_list : (elt -> 'f) -> t -> 'f list 
  val fold_left : ('f -> elt -> 'f) -> 'f -> t -> 'f
  val fold_right : (elt -> 'g -> 'g) -> t -> 'g -> 'g
  val filter : (elt -> bool) -> t -> t
  val inplace_filter : (elt -> bool) -> t -> unit
  val inplace_filter_with : (elt -> bool) -> cb_no:(elt -> 'a -> 'a) -> 'a -> t -> 'a 
  val inplace_filter_from : int -> (elt -> bool) -> t -> unit 
  val equal : (elt -> elt -> bool) -> t -> t -> bool 
  val get : t -> int -> elt
  val unsafe_get : t -> int -> elt
  val last : t -> elt
  val capacity : t -> int
  val exists : (elt -> bool) -> t -> bool
  val sub : t -> int -> int  -> t 
end


end
module Int_vec : sig 
#1 "int_vec.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

include Vec_gen.S with type elt = int

end = struct
#1 "int_vec.ml"
# 1 "ext/vec.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

# 34
type elt = int 
let null = 0 (* can be optimized *)
let unsafe_blit = Bs_hash_stubs.int_unsafe_blit

# 41
external unsafe_sub : 'a array -> int -> int -> 'a array = "caml_array_sub"

type  t = {
  mutable arr : elt array ;
  mutable len : int ;  
}

let length d = (* 270 *) d.len

let compact d =
  (* 6 *) let d_arr = d.arr in 
  if d.len <> Array.length d_arr then 
    (* 6 *) begin
      let newarr = unsafe_sub d_arr 0 d.len in 
      d.arr <- newarr
    end
let singleton v = 
  (* 0 *) {
    len = 1 ; 
    arr = [|v|]
  }

let empty () =
  (* 363 *) {
    len = 0;
    arr = [||];
  }

let is_empty d =
  (* 150 *) d.len = 0

let reset d = 
  (* 0 *) d.len <- 0; 
  d.arr <- [||]


(* For [to_*] operations, we should be careful to call {!Array.*} function 
   in case we operate on the whole array
*)
let to_list d =
  (* 0 *) let rec loop (d_arr : elt array) idx accum =
    (* 0 *) if idx < 0 then (* 0 *) accum else (* 0 *) loop d_arr (idx - 1) (Array.unsafe_get d_arr idx :: accum)
  in
  loop d.arr (d.len - 1) []


let of_list lst =
  (* 69 *) let arr = Array.of_list lst in 
  { arr ; len = Array.length arr}


let to_array d = 
  (* 0 *) unsafe_sub d.arr 0 d.len

let of_array src =
  (* 84 *) {
    len = Array.length src;
    arr = Array.copy src;
    (* okay to call {!Array.copy}*)
  }
let of_sub_array arr off len = 
  (* 0 *) { 
    len = len ; 
    arr = Array.sub arr off len  
  }  
let unsafe_internal_array v = (* 18 *) v.arr  
(* we can not call {!Array.copy} *)
let copy src =
  (* 3 *) let len = src.len in
  {
    len ;
    arr = unsafe_sub src.arr 0 len ;
  }

(* FIXME *)
let reverse_in_place src = 
  (* 3 *) Ext_array.reverse_range src.arr 0 src.len 




(* {!Array.sub} is not enough for error checking, it 
   may contain some garbage
 *)
let sub (src : t) start len =
  (* 9 *) let src_len = src.len in 
  if len < 0 || start > src_len - len then (* 6 *) invalid_arg "Vec.sub"
  else 
  (* 3 *) { len ; 
    arr = unsafe_sub src.arr start len }

let iter f d = 
  (* 318 *) let arr = d.arr in 
  for i = 0 to d.len - 1 do
    (* 645 *) f (Array.unsafe_get arr i)
  done

let iteri f d =
  (* 0 *) let arr = d.arr in
  for i = 0 to d.len - 1 do
    (* 0 *) f i (Array.unsafe_get arr i)
  done

let iter_range ~from ~to_ f d =
  (* 0 *) if from < 0 || to_ >= d.len then (* 0 *) invalid_arg "Resize_array.iter_range"
  else 
    (* 0 *) let d_arr = d.arr in 
    for i = from to to_ do 
      (* 0 *) f  (Array.unsafe_get d_arr i)
    done

let iteri_range ~from ~to_ f d =
  (* 0 *) if from < 0 || to_ >= d.len then (* 0 *) invalid_arg "Resize_array.iteri_range"
  else 
    (* 0 *) let d_arr = d.arr in 
    for i = from to to_ do 
      (* 0 *) f i (Array.unsafe_get d_arr i)
    done

let map_into_array f src =
  (* 24 *) let src_len = src.len in 
  let src_arr = src.arr in 
  if src_len = 0 then (* 0 *) [||]
  else 
    (* 24 *) let first_one = f (Array.unsafe_get src_arr 0) in 
    let arr = Array.make  src_len  first_one in
    for i = 1 to src_len - 1 do
      (* 3 *) Array.unsafe_set arr i (f (Array.unsafe_get src_arr i))
    done;
    arr 
let map_into_list f src = 
  (* 3 *) let src_len = src.len in 
  let src_arr = src.arr in 
  if src_len = 0 then (* 0 *) []
  else 
    (* 3 *) let acc = ref [] in         
    for i =  src_len - 1 downto 0 do
      (* 12 *) acc := f (Array.unsafe_get src_arr i) :: !acc
    done;
    !acc

let mapi f src =
  (* 0 *) let len = src.len in 
  if len = 0 then (* 0 *) { len ; arr = [| |] }
  else 
    (* 0 *) let src_arr = src.arr in 
    let arr = Array.make len (Array.unsafe_get src_arr 0) in
    for i = 1 to len - 1 do
      (* 0 *) Array.unsafe_set arr i (f i (Array.unsafe_get src_arr i))
    done;
    {
      len ;
      arr ;
    }

let fold_left f x a =
  (* 0 *) let rec loop a_len (a_arr : elt array) idx x =
    (* 0 *) if idx >= a_len then (* 0 *) x else 
      (* 0 *) loop a_len a_arr (idx + 1) (f x (Array.unsafe_get a_arr idx))
  in
  loop a.len a.arr 0 x

let fold_right f a x =
  (* 0 *) let rec loop (a_arr : elt array) idx x =
    (* 0 *) if idx < 0 then (* 0 *) x
    else (* 0 *) loop a_arr (idx - 1) (f (Array.unsafe_get a_arr idx) x)
  in
  loop a.arr (a.len - 1) x

(**  
   [filter] and [inplace_filter]
*)
let filter f d =
  (* 3 *) let new_d = copy d in 
  let new_d_arr = new_d.arr in 
  let d_arr = d.arr in
  let p = ref 0 in
  for i = 0 to d.len  - 1 do
    (* 18 *) let x = Array.unsafe_get d_arr i in
    (* TODO: can be optimized for segments blit *)
    if f x  then
      (* 6 *) begin
        Array.unsafe_set new_d_arr !p x;
        incr p;
      end;
  done;
  new_d.len <- !p;
  new_d 

let equal eq x y : bool = 
  (* 66 *) if x.len <> y.len then (* 0 *) false 
  else 
    (* 66 *) let rec aux x_arr y_arr i =
      (* 4881 *) if i < 0 then (* 66 *) true else  
      (* 4815 *) if eq (Array.unsafe_get x_arr i) (Array.unsafe_get y_arr i) then 
        (* 4815 *) aux x_arr y_arr (i - 1)
      else (* 0 *) false in 
    aux x.arr y.arr (x.len - 1)

let get d i = 
  (* 0 *) if i < 0 || i >= d.len then (* 0 *) invalid_arg "Resize_array.get"
  else (* 0 *) Array.unsafe_get d.arr i
let unsafe_get d i = (* 318 *) Array.unsafe_get d.arr i 
let last d = 
  (* 3 *) if d.len <= 0 then (* 0 *) invalid_arg   "Resize_array.last"
  else (* 3 *) Array.unsafe_get d.arr (d.len - 1)

let capacity d = (* 21 *) Array.length d.arr

(* Attention can not use {!Array.exists} since the bound is not the same *)  
let exists p d = 
  (* 6 *) let a = d.arr in 
  let n = d.len in   
  let rec loop i =
    (* 6003 *) if i = n then (* 3 *) false
    else (* 6000 *) if p (Array.unsafe_get a i) then (* 3 *) true
    else (* 5997 *) loop (succ i) in
  loop 0

let map f src =
  (* 3 *) let src_len = src.len in 
  if src_len = 0 then (* 0 *) { len = 0 ; arr = [||]}
  (* TODO: we may share the empty array 
     but sharing mutable state is very challenging, 
     the tricky part is to avoid mutating the immutable array,
     here it looks fine -- 
     invariant: whenever [.arr] mutated, make sure  it is not an empty array
     Actually no: since starting from an empty array 
     {[
       push v (* the address of v should not be changed *)
     ]}
  *)
  else 
    (* 3 *) let src_arr = src.arr in 
    let first = f (Array.unsafe_get src_arr 0 ) in 
    let arr = Array.make  src_len first in
    for i = 1 to src_len - 1 do
      (* 2997 *) Array.unsafe_set arr i (f (Array.unsafe_get src_arr i))
    done;
    {
      len = src_len;
      arr = arr;
    }

let init len f =
  (* 3 *) if len < 0 then (* 0 *) invalid_arg  "Resize_array.init"
  else (* 3 *) if len = 0 then (* 0 *) { len = 0 ; arr = [||] }
  else 
    (* 3 *) let first = f 0 in 
    let arr = Array.make len first in
    for i = 1 to len - 1 do
      (* 27 *) Array.unsafe_set arr i (f i)
    done;
    {

      len ;
      arr 
    }



  let make initsize : t =
    (* 12 *) if initsize < 0 then (* 0 *) invalid_arg  "Resize_array.make" ;
    {

      len = 0;
      arr = Array.make  initsize null ;
    }



  let reserve (d : t ) s = 
    (* 6 *) let d_len = d.len in 
    let d_arr = d.arr in 
    if s < d_len || s < Array.length d_arr then (* 0 *) ()
    else 
      (* 6 *) let new_capacity = min Sys.max_array_length s in 
      let new_d_arr = Array.make new_capacity null in 
       unsafe_blit d_arr 0 new_d_arr 0 d_len;
      d.arr <- new_d_arr 

  let push v (d : t) =
    (* 3726 *) let d_len = d.len in
    let d_arr = d.arr in 
    let d_arr_len = Array.length d_arr in
    if d_arr_len = 0 then
      (* 318 *) begin 
        d.len <- 1 ;
        d.arr <- [| v |]
      end
    else  
      (* 3408 *) begin 
        if d_len = d_arr_len then 
          (* 408 *) begin
            if d_len >= Sys.max_array_length then 
              (* 0 *) failwith "exceeds max_array_length";
            let new_capacity = min Sys.max_array_length d_len * 2 
            (* [d_len] can not be zero, so [*2] will enlarge   *)
            in
            let new_d_arr = Array.make new_capacity null in 
            d.arr <- new_d_arr;
             unsafe_blit d_arr 0 new_d_arr 0 d_len ;
          end;
        d.len <- d_len + 1;
        Array.unsafe_set d.arr d_len v
      end

(** delete element at offset [idx], will raise exception when have invalid input *)
  let delete (d : t) idx =
    (* 273 *) let d_len = d.len in 
    if idx < 0 || idx >= d_len then (* 3 *) invalid_arg "Resize_array.delete" ;
    let arr = d.arr in 
     unsafe_blit arr (idx + 1) arr idx  (d_len - idx - 1);
    let idx = d_len - 1 in 
    d.len <- idx
    
# 362
(** pop the last element, a specialized version of [delete] *)
  let pop (d : t) = 
    (* 18 *) let idx  = d.len - 1  in
    if idx < 0 then (* 0 *) invalid_arg "Resize_array.pop";
    d.len <- idx
  
# 373
(** pop and return the last element *)  
  let get_last_and_pop (d : t) = 
    (* 0 *) let idx  = d.len - 1  in
    if idx < 0 then (* 0 *) invalid_arg "Resize_array.get_last_and_pop";
    let last = Array.unsafe_get d.arr idx in 
    d.len <- idx 
    
# 384
    ;
    last 

(** delete elements start from [idx] with length [len] *)
  let delete_range (d : t) idx len =
    (* 0 *) let d_len = d.len in 
    if len < 0 || idx < 0 || idx + len > d_len then (* 0 *) invalid_arg  "Resize_array.delete_range"  ;
    let arr = d.arr in 
     unsafe_blit arr (idx + len) arr idx (d_len  - idx - len);
    d.len <- d_len - len

# 402
(** delete elements from [idx] with length [len] return the deleted elements as a new vec*)
  let get_and_delete_range (d : t) idx len : t = 
    (* 135 *) let d_len = d.len in 
    if len < 0 || idx < 0 || idx + len > d_len then (* 0 *) invalid_arg  "Resize_array.get_and_delete_range"  ;
    let arr = d.arr in 
    let value =  unsafe_sub arr idx len in
     unsafe_blit arr (idx + len) arr idx (d_len  - idx - len);
    d.len <- d_len - len; 
    
# 416
    {len = len ; arr = value}


  (** Below are simple wrapper around normal Array operations *)  

  let clear (d : t ) =
    
# 428
    (* 0 *) d.len <- 0



  let inplace_filter f (d : t) : unit = 
    (* 84 *) let d_arr = d.arr in     
    let d_len = d.len in
    let p = ref 0 in
    for i = 0 to d_len - 1 do 
      (* 219 *) let x = Array.unsafe_get d_arr i in 
      if f x then 
        (* 81 *) begin 
          let curr_p = !p in 
          (if curr_p <> i then 
             (* 21 *) Array.unsafe_set d_arr curr_p x) ;
          incr p
        end
    done ;
    let last = !p  in 
    
# 448
    d.len <-  last 
    (* INT , there is not need to reset it, since it will cause GC behavior *)

  
# 454
  let inplace_filter_from start f (d : t) : unit = 
    (* 6 *) if start < 0 then (* 0 *) invalid_arg "Vec.inplace_filter_from"; 
    let d_arr = d.arr in     
    let d_len = d.len in
    let p = ref start in    
    for i = start to d_len - 1 do 
      (* 42 *) let x = Array.unsafe_get d_arr i in 
      if f x then 
        (* 21 *) begin 
          let curr_p = !p in 
          (if curr_p <> i then 
             (* 18 *) Array.unsafe_set d_arr curr_p x) ;
          incr p
        end
    done ;
    let last = !p  in 
    
# 471
    d.len <-  last 


# 477
(** inplace filter the elements and accumulate the non-filtered elements *)
  let inplace_filter_with  f ~cb_no acc (d : t)  = 
    (* 3 *) let d_arr = d.arr in     
    let p = ref 0 in
    let d_len = d.len in
    let acc = ref acc in 
    for i = 0 to d_len - 1 do 
      (* 3000 *) let x = Array.unsafe_get d_arr i in 
      if f x then 
        (* 1500 *) begin 
          let curr_p = !p in 
          (if curr_p <> i then 
             (* 1497 *) Array.unsafe_set d_arr curr_p x) ;
          incr p
        end
      else 
        (* 1500 *) acc := cb_no  x  !acc
    done ;
    let last = !p  in 
    
# 497
    d.len <-  last 
    (* INT , there is not need to reset it, since it will cause GC behavior *)
    
# 502
    ; !acc 




end
module Int_vec_util : sig 
#1 "int_vec_util.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


val mem : int -> Int_vec.t -> bool
end = struct
#1 "int_vec_util.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


let rec unsafe_mem_aux arr  i (key : int) bound = 
    (* 36 *) if i <= bound then 
        (* 27 *) if Array.unsafe_get arr i = (key : int) then 
            (* 9 *) true 
         else (* 18 *) unsafe_mem_aux arr (i + 1) key bound    
    else (* 9 *) false 
    


let mem key (x : Int_vec.t) =
    (* 18 *) let internal_array = Int_vec.unsafe_internal_array x in 
    let len = Int_vec.length x in 
    unsafe_mem_aux internal_array 0 key (len - 1)
    
end
module Ounit_int_vec_tests
= struct
#1 "ounit_int_vec_tests.ml"
let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal
let suites = 
    __FILE__
    >:::
    [
        __LOC__ >:: begin fun _ -> 
            (* 3 *) OUnit.assert_bool __LOC__
             (Int_vec_util.mem 3 (Int_vec.of_list [1;2;3]))
             ;
            OUnit.assert_bool __LOC__ 
             (not @@ Int_vec_util.mem 0 (Int_vec.of_list [1;2]) ); 
            
            let v = Int_vec.make 100 in 
            OUnit.assert_bool __LOC__ 
                (not @@ Int_vec_util.mem 0 v) ;
            Int_vec.push 0 v ;
            OUnit.assert_bool __LOC__ 
                (Int_vec_util.mem 0 v )
        end;

        __LOC__ >:: begin fun _ -> 
            (* 3 *) let u = Int_vec.make 100 in 
            Int_vec.push 1 u ;
            OUnit.assert_bool __LOC__
            (not @@ Int_vec_util.mem 0 u );
            Int_vec.push 0 u ; 
            OUnit.assert_bool __LOC__
            (Int_vec_util.mem 0 u)
        end
    ]
end
module Ext_utf8 : sig 
#1 "ext_utf8.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

type byte =
  | Single of int
  | Cont of int
  | Leading of int * int
  | Invalid


val classify : char -> byte 

val follow : 
    string -> 
    int -> 
    int -> 
    int ->
    int * int 


(** 
  return [-1] if failed 
*)
val next :  string -> remaining:int -> int -> int 


exception Invalid_utf8 of string 
 
 
val decode_utf8_string : string -> int list
end = struct
#1 "ext_utf8.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

type byte =
  | Single of int
  | Cont of int
  | Leading of int * int
  | Invalid

(** [classify chr] returns the {!byte} corresponding to [chr] *)
let classify chr =
  (* 213 *) let c = int_of_char chr in
  (* Classify byte according to leftmost 0 bit *)
  if c land 0b1000_0000 = 0 then (* 138 *) Single c else
    (* c 0b0____*)
  (* 75 *) if c land 0b0100_0000 = 0 then (* 51 *) Cont (c land 0b0011_1111) else
    (* c 0b10___*)
  (* 24 *) if c land 0b0010_0000 = 0 then (* 0 *) Leading (1, c land 0b0001_1111) else
    (* c 0b110__*)
  (* 24 *) if c land 0b0001_0000 = 0 then (* 21 *) Leading (2, c land 0b0000_1111) else
    (* c 0b1110_ *)
  (* 3 *) if c land 0b0000_1000 = 0 then (* 3 *) Leading (3, c land 0b0000_0111) else
    (* c 0b1111_0___*)
  (* 0 *) if c land 0b0000_0100 = 0 then (* 0 *) Leading (4, c land 0b0000_0011) else
    (* c 0b1111_10__*)
  (* 0 *) if c land 0b0000_0010 = 0 then (* 0 *) Leading (5, c land 0b0000_0001)
  (* c 0b1111_110__ *)
  else (* 0 *) Invalid

exception Invalid_utf8 of string 

(* when the first char is [Leading],
  TODO: need more error checking 
  when out of bond
 *)
let rec follow s n (c : int) offset = 
  (* 75 *) if n = 0 then (* 24 *) (c, offset)
  else 
    (* 51 *) begin match classify s.[offset+1] with
      | Cont cc -> (* 51 *) follow s (n-1) ((c lsl 6) lor (cc land 0x3f)) (offset+1)
      | _ -> (* 0 *) raise (Invalid_utf8 "Continuation byte expected")
    end


let rec next s ~remaining  offset = 
  (* 0 *) if remaining = 0 then (* 0 *) offset 
  else 
    (* 0 *) begin match classify s.[offset+1] with
      | Cont cc -> (* 0 *) next s ~remaining:(remaining-1) (offset+1)
      | _ ->  (* 0 *) -1 
      | exception _ ->  (* 0 *) -1 (* it can happen when out of bound *)
    end




let decode_utf8_string s =
  (* 33 *) let lst = ref [] in
  let add elem = (* 162 *) lst := elem :: !lst in
  let rec  decode_utf8_cont s i s_len =
    (* 195 *) if i = s_len  then (* 33 *) ()
    else 
      (* 162 *) begin 
        match classify s.[i] with
        | Single c -> 
          (* 138 *) add c; decode_utf8_cont s (i+1) s_len
        | Cont _ -> (* 0 *) raise (Invalid_utf8 "Unexpected continuation byte")
        | Leading (n, c) ->
          (* 24 *) let (c', i') = follow s n c i in add c';
          decode_utf8_cont s (i' + 1) s_len
        | Invalid -> (* 0 *) raise (Invalid_utf8 "Invalid byte")
      end
  in decode_utf8_cont s 0 (String.length s); 
  List.rev !lst


(** To decode {j||j} we need verify in the ast so that we have better error 
    location, then we do the decode later
*)  

let verify s loc = 
  (* 0 *) assert false
end
module Ext_js_regex : sig 
#1 "ext_js_regex.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

(* This is a module that checks if js regex is valid or not *)

val js_regex_checker : string -> bool
end = struct
#1 "ext_js_regex.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


let check_from_end al =
  (* 21 *) let rec aux l seen =
    (* 30 *) match l with
    | [] -> (* 0 *) false
    | (e::r) ->
      (* 30 *) if e < 0 || e > 255 then (* 0 *) false
      else (* 30 *) (let c = Char.chr e in
            if c = '/' then (* 12 *) true
            else (* 18 *) (if List.exists (fun x -> (* 6 *) x = c) seen then (* 3 *) false (* flag should not be repeated *)
                  else (* 15 *) (if c = 'i' || c = 'g' || c = 'm' || c = 'y' || c ='u' then (* 9 *) aux r (c::seen) 
                        else (* 6 *) false)))
  in aux al []

let js_regex_checker s =
  (* 27 *) match Ext_utf8.decode_utf8_string s with 
  | [] -> (* 3 *) false 
  | 47 (* [Char.code '/' = 47 ]*)::tail -> 
    (* 21 *) check_from_end (List.rev tail)       
  | _ :: _ -> (* 3 *) false 
  | exception Ext_utf8.Invalid_utf8 _ -> (* 0 *) false 

end
module Ounit_js_regex_checker_tests
= struct
#1 "ounit_js_regex_checker_tests.ml"
let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

open Ext_js_regex

let suites =
    __FILE__
    >:::
    [
        "test_empty_string" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "" in
        OUnit.assert_equal b false
        end;
        "test_normal_regex" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "/abc/" in
        OUnit.assert_equal b true
        end;
        "test_wrong_regex_last" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "/abc" in 
        OUnit.assert_equal b false
        end;
        "test_regex_with_flag" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "/ss/ig" in
        OUnit.assert_equal b true
        end;
        "test_regex_with_invalid_flag" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "/ss/j" in
        OUnit.assert_equal b false
        end;
        "test_regex_invalid_regex" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "abc/i" in 
        OUnit.assert_equal b false
        end;
        "test_regex_empty_pattern" >:: begin fun _  ->
        (* 3 *) let b = js_regex_checker "//" in 
        OUnit.assert_equal b true
        end;
        "test_regex_with_utf8" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "/😃/" in
        OUnit.assert_equal b true
        end;
        "test_regex_repeated_flags" >:: begin fun _ ->
        (* 3 *) let b = js_regex_checker "/abc/gg" in
        OUnit.assert_equal b false
        end;
    ]
end
module Map_gen
= struct
#1 "map_gen.ml"
(***********************************************************************)
(*                                                                     *)
(*                                OCaml                                *)
(*                                                                     *)
(*            Xavier Leroy, projet Cristal, INRIA Rocquencourt         *)
(*                                                                     *)
(*  Copyright 1996 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the GNU Library General Public License, with    *)
(*  the special exception on linking described in file ../LICENSE.     *)
(*                                                                     *)
(***********************************************************************)
(** adapted from stdlib *)

type ('key,'a) t =
  | Empty
  | Node of ('key,'a) t * 'key * 'a * ('key,'a) t * int

type ('key,'a) enumeration =
  | End
  | More of 'key * 'a * ('key,'a) t * ('key, 'a) enumeration

let rec cardinal_aux acc  = function
  | Empty -> (* 6024 *) acc 
  | Node (l,_,_,r, _) -> 
    (* 6012 *) cardinal_aux  (cardinal_aux (acc + 1)  r ) l 

let cardinal s = (* 12 *) cardinal_aux 0 s 

let rec bindings_aux accu = function
  | Empty -> (* 0 *) accu
  | Node(l, v, d, r, _) -> (* 0 *) bindings_aux ((v, d) :: bindings_aux accu r) l

let bindings s =
  (* 0 *) bindings_aux [] s

let rec keys_aux accu = function
    Empty -> (* 15 *) accu
  | Node(l, v, _, r, _) -> (* 12 *) keys_aux (v :: keys_aux accu r) l

let keys s = (* 3 *) keys_aux [] s



let rec cons_enum m e =
  (* 0 *) match m with
    Empty -> (* 0 *) e
  | Node(l, v, d, r, _) -> (* 0 *) cons_enum l (More(v, d, r, e))


let height = function
  | Empty -> (* 9000 *) 0
  | Node(_,_,_,_,h) -> (* 26640 *) h

let create l x d r =
  (* 11880 *) let hl = height l and hr = height r in
  Node(l, x, d, r, (if hl >= hr then (* 5940 *) hl + 1 else (* 5940 *) hr + 1))

let singleton x d = (* 0 *) Node(Empty, x, d, Empty, 1)

let bal l x d r =
  (* 83796 *) let hl = match l with Empty -> (* 15009 *) 0 | Node(_,_,_,_,h) -> (* 68787 *) h in
  let hr = match r with Empty -> (* 6 *) 0 | Node(_,_,_,_,h) -> (* 83790 *) h in
  if hl > hr + 2 then (* 0 *) begin
    match l with
      Empty -> (* 0 *) invalid_arg "Map.bal"
    | Node(ll, lv, ld, lr, _) ->
      (* 0 *) if height ll >= height lr then
        (* 0 *) create ll lv ld (create lr x d r)
      else (* 0 *) begin
        match lr with
          Empty -> (* 0 *) invalid_arg "Map.bal"
        | Node(lrl, lrv, lrd, lrr, _)->
          (* 0 *) create (create ll lv ld lrl) lrv lrd (create lrr x d r)
      end
  end else (* 83796 *) if hr > hl + 2 then (* 5940 *) begin
    match r with
      Empty -> (* 0 *) invalid_arg "Map.bal"
    | Node(rl, rv, rd, rr, _) ->
      (* 5940 *) if height rr >= height rl then
        (* 5940 *) create (create l x d rl) rv rd rr
      else (* 0 *) begin
        match rl with
          Empty -> (* 0 *) invalid_arg "Map.bal"
        | Node(rll, rlv, rld, rlr, _) ->
          (* 0 *) create (create l x d rll) rlv rld (create rlr rv rd rr)
      end
  end else
    (* 77856 *) Node(l, x, d, r, (if hl >= hr then (* 18246 *) hl + 1 else (* 59610 *) hr + 1))

let empty = Empty

let is_empty = function Empty -> (* 3 *) true | _ -> (* 0 *) false

let rec min_binding_exn = function
    Empty -> (* 0 *) raise Not_found
  | Node(Empty, x, d, r, _) -> (* 0 *) (x, d)
  | Node(l, x, d, r, _) -> (* 0 *) min_binding_exn l

let choose = min_binding_exn

let rec max_binding_exn = function
    Empty -> (* 0 *) raise Not_found
  | Node(l, x, d, Empty, _) -> (* 0 *) (x, d)
  | Node(l, x, d, r, _) -> (* 0 *) max_binding_exn r

let rec remove_min_binding = function
    Empty -> (* 0 *) invalid_arg "Map.remove_min_elt"
  | Node(Empty, x, d, r, _) -> (* 0 *) r
  | Node(l, x, d, r, _) -> (* 0 *) bal (remove_min_binding l) x d r

let merge t1 t2 =
  (* 0 *) match (t1, t2) with
    (Empty, t) -> (* 0 *) t
  | (t, Empty) -> (* 0 *) t
  | (_, _) ->
    (* 0 *) let (x, d) = min_binding_exn t2 in
    bal t1 x d (remove_min_binding t2)


let rec iter f = function
    Empty -> (* 3003 *) ()
  | Node(l, v, d, r, _) ->
    (* 3000 *) iter f l; f v d; iter f r

let rec map f = function
    Empty ->
    (* 0 *) Empty
  | Node(l, v, d, r, h) ->
    (* 0 *) let l' = map f l in
    let d' = f d in
    let r' = map f r in
    Node(l', v, d', r', h)

let rec mapi f = function
    Empty ->
    (* 0 *) Empty
  | Node(l, v, d, r, h) ->
    (* 0 *) let l' = mapi f l in
    let d' = f v d in
    let r' = mapi f r in
    Node(l', v, d', r', h)

let rec fold f m accu =
  (* 0 *) match m with
    Empty -> (* 0 *) accu
  | Node(l, v, d, r, _) ->
    (* 0 *) fold f r (f v d (fold f l accu))

let rec for_all p = function
    Empty -> (* 0 *) true
  | Node(l, v, d, r, _) -> (* 0 *) p v d && for_all p l && for_all p r

let rec exists p = function
    Empty -> (* 0 *) false
  | Node(l, v, d, r, _) -> (* 0 *) p v d || exists p l || exists p r

(* Beware: those two functions assume that the added k is *strictly*
   smaller (or bigger) than all the present keys in the tree; it
   does not test for equality with the current min (or max) key.

   Indeed, they are only used during the "join" operation which
   respects this precondition.
*)

let rec add_min_binding k v = function
  | Empty -> (* 0 *) singleton k v
  | Node (l, x, d, r, h) ->
    (* 0 *) bal (add_min_binding k v l) x d r

let rec add_max_binding k v = function
  | Empty -> (* 0 *) singleton k v
  | Node (l, x, d, r, h) ->
    (* 0 *) bal l x d (add_max_binding k v r)

(* Same as create and bal, but no assumptions are made on the
   relative heights of l and r. *)

let rec join l v d r =
  (* 0 *) match (l, r) with
    (Empty, _) -> (* 0 *) add_min_binding v d r
  | (_, Empty) -> (* 0 *) add_max_binding v d l
  | (Node(ll, lv, ld, lr, lh), Node(rl, rv, rd, rr, rh)) ->
    (* 0 *) if lh > rh + 2 then (* 0 *) bal ll lv ld (join lr v d r) else
    (* 0 *) if rh > lh + 2 then (* 0 *) bal (join l v d rl) rv rd rr else
      (* 0 *) create l v d r

(* Merge two trees l and r into one.
   All elements of l must precede the elements of r.
   No assumption on the heights of l and r. *)

let concat t1 t2 =
  (* 0 *) match (t1, t2) with
    (Empty, t) -> (* 0 *) t
  | (t, Empty) -> (* 0 *) t
  | (_, _) ->
    (* 0 *) let (x, d) = min_binding_exn t2 in
    join t1 x d (remove_min_binding t2)

let concat_or_join t1 v d t2 =
  (* 0 *) match d with
  | Some d -> (* 0 *) join t1 v d t2
  | None -> (* 0 *) concat t1 t2

let rec filter p = function
    Empty -> (* 0 *) Empty
  | Node(l, v, d, r, _) ->
    (* call [p] in the expected left-to-right order *)
    (* 0 *) let l' = filter p l in
    let pvd = p v d in
    let r' = filter p r in
    if pvd then (* 0 *) join l' v d r' else (* 0 *) concat l' r'

let rec partition p = function
    Empty -> (* 0 *) (Empty, Empty)
  | Node(l, v, d, r, _) ->
    (* call [p] in the expected left-to-right order *)
    (* 0 *) let (lt, lf) = partition p l in
    let pvd = p v d in
    let (rt, rf) = partition p r in
    if pvd
    then (* 0 *) (join lt v d rt, concat lf rf)
    else (* 0 *) (concat lt rt, join lf v d rf)

let compare compare_key cmp_val m1 m2 =
  (* 0 *) let rec compare_aux e1  e2 =
    (* 0 *) match (e1, e2) with
      (End, End) -> (* 0 *) 0
    | (End, _)  -> (* 0 *) -1
    | (_, End) -> (* 0 *) 1
    | (More(v1, d1, r1, e1), More(v2, d2, r2, e2)) ->
      (* 0 *) let c = compare_key v1 v2 in
      if c <> 0 then (* 0 *) c else
        (* 0 *) let c = cmp_val d1 d2 in
        if c <> 0 then (* 0 *) c else
          (* 0 *) compare_aux (cons_enum r1 e1) (cons_enum r2 e2)
  in compare_aux (cons_enum m1 End) (cons_enum m2 End)

let equal compare_key cmp m1 m2 =
  (* 0 *) let rec equal_aux e1 e2 =
    (* 0 *) match (e1, e2) with
      (End, End) -> (* 0 *) true
    | (End, _)  -> (* 0 *) false
    | (_, End) -> (* 0 *) false
    | (More(v1, d1, r1, e1), More(v2, d2, r2, e2)) ->
      (* 0 *) compare_key v1 v2 = 0 && cmp d1 d2 &&
      equal_aux (cons_enum r1 e1) (cons_enum r2 e2)
  in equal_aux (cons_enum m1 End) (cons_enum m2 End)



    
module type S =
  sig
    type key
    type +'a t
    val empty: 'a t
    val is_empty: 'a t -> bool
    val mem: key -> 'a t -> bool

    val add: key -> 'a -> 'a t -> 'a t
    (** [add x y m] 
        If [x] was already bound in [m], its previous binding disappears. *)
    val adjust: key -> (unit -> 'a)  -> ('a ->  'a) -> 'a t -> 'a t 
    (** [adjust k v f map] if not exist [add k v], otherwise 
        [add k v (f old)]
    *)
    val singleton: key -> 'a -> 'a t

    val remove: key -> 'a t -> 'a t
    (** [remove x m] returns a map containing the same bindings as
       [m], except for [x] which is unbound in the returned map. *)

    val merge:
         (key -> 'a option -> 'b option -> 'c option) -> 'a t -> 'b t -> 'c t
    (** [merge f m1 m2] computes a map whose keys is a subset of keys of [m1]
        and of [m2]. The presence of each such binding, and the corresponding
        value, is determined with the function [f].
        @since 3.12.0
     *)

     val disjoint_merge : 'a t -> 'a t -> 'a t
     (* merge two maps, will raise if they have the same key *)
    val compare: ('a -> 'a -> int) -> 'a t -> 'a t -> int
    (** Total ordering between maps.  The first argument is a total ordering
        used to compare data associated with equal keys in the two maps. *)

    val equal: ('a -> 'a -> bool) -> 'a t -> 'a t -> bool

    val iter: (key -> 'a -> unit) -> 'a t -> unit
    (** [iter f m] applies [f] to all bindings in map [m].
        The bindings are passed to [f] in increasing order. *)

    val fold: (key -> 'a -> 'b -> 'b) -> 'a t -> 'b -> 'b
    (** [fold f m a] computes [(f kN dN ... (f k1 d1 a)...)],
       where [k1 ... kN] are the keys of all bindings in [m]
       (in increasing order) *)

    val for_all: (key -> 'a -> bool) -> 'a t -> bool
    (** [for_all p m] checks if all the bindings of the map.
        order unspecified
     *)

    val exists: (key -> 'a -> bool) -> 'a t -> bool
    (** [exists p m] checks if at least one binding of the map
        satisfy the predicate [p]. 
        order unspecified
     *)

    val filter: (key -> 'a -> bool) -> 'a t -> 'a t
    (** [filter p m] returns the map with all the bindings in [m]
        that satisfy predicate [p].
        order unspecified
     *)

    val partition: (key -> 'a -> bool) -> 'a t -> 'a t * 'a t
    (** [partition p m] returns a pair of maps [(m1, m2)], where
        [m1] contains all the bindings of [s] that satisfy the
        predicate [p], and [m2] is the map with all the bindings of
        [s] that do not satisfy [p].
     *)

    val cardinal: 'a t -> int
    (** Return the number of bindings of a map. *)

    val bindings: 'a t -> (key * 'a) list
    (** Return the list of all bindings of the given map.
       The returned list is sorted in increasing order with respect
       to the ordering *)
    val keys : 'a t -> key list 
    (* Increasing order *)

    val min_binding_exn: 'a t -> (key * 'a)
    (** raise [Not_found] if the map is empty. *)

    val max_binding_exn: 'a t -> (key * 'a)
    (** Same as {!Map.S.min_binding} *)

    val choose: 'a t -> (key * 'a)
    (** Return one binding of the given map, or raise [Not_found] if
       the map is empty. Which binding is chosen is unspecified,
       but equal bindings will be chosen for equal maps.
     *)

    val split: key -> 'a t -> 'a t * 'a option * 'a t
    (** [split x m] returns a triple [(l, data, r)], where
          [l] is the map with all the bindings of [m] whose key
        is strictly less than [x];
          [r] is the map with all the bindings of [m] whose key
        is strictly greater than [x];
          [data] is [None] if [m] contains no binding for [x],
          or [Some v] if [m] binds [v] to [x].
        @since 3.12.0
     *)

    val find_exn: key -> 'a t -> 'a
    (** [find x m] returns the current binding of [x] in [m],
       or raises [Not_found] if no such binding exists. *)
    val find_opt: key -> 'a t -> 'a option
    val find_default: key  -> 'a t -> 'a  -> 'a 
    val map: ('a -> 'b) -> 'a t -> 'b t
    (** [map f m] returns a map with same domain as [m], where the
       associated value [a] of all bindings of [m] has been
       replaced by the result of the application of [f] to [a].
       The bindings are passed to [f] in increasing order
       with respect to the ordering over the type of the keys. *)

    val mapi: (key -> 'a -> 'b) -> 'a t -> 'b t
    (** Same as {!Map.S.map}, but the function receives as arguments both the
       key and the associated value for each binding of the map. *)

    val of_list : (key * 'a) list -> 'a t 
    val of_array : (key * 'a ) array -> 'a t 
    val add_list : (key * 'b) list -> 'b t -> 'b t

  end

end
module String_map : sig 
#1 "string_map.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


include Map_gen.S with type key = string

end = struct
#1 "string_map.ml"

# 2 "ext/map.cppo.ml"
(* we don't create [map_poly], since some operations require raise an exception which carries [key] *)


  
# 10
  type key = string 
  let compare_key = Ext_string.compare

# 22
type 'a t = (key,'a) Map_gen.t
exception Duplicate_key of key 

let empty = Map_gen.empty 
let is_empty = Map_gen.is_empty
let iter = Map_gen.iter
let fold = Map_gen.fold
let for_all = Map_gen.for_all 
let exists = Map_gen.exists 
let singleton = Map_gen.singleton 
let cardinal = Map_gen.cardinal
let bindings = Map_gen.bindings
let keys = Map_gen.keys
let choose = Map_gen.choose 
let partition = Map_gen.partition 
let filter = Map_gen.filter 
let map = Map_gen.map 
let mapi = Map_gen.mapi
let bal = Map_gen.bal 
let height = Map_gen.height 
let max_binding_exn = Map_gen.max_binding_exn
let min_binding_exn = Map_gen.min_binding_exn


let rec add x data (tree : _ Map_gen.t as 'a) : 'a = (* 12 *) match tree with 
  | Empty ->
    (* 12 *) Node(Empty, x, data, Empty, 1)
  | Node(l, v, d, r, h) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then
      (* 0 *) Node(l, x, data, r, h)
    else (* 0 *) if c < 0 then
      (* 0 *) bal (add x data l) v d r
    else
      (* 0 *) bal l v d (add x data r)


let rec adjust x data replace (tree : _ Map_gen.t as 'a) : 'a = 
  (* 0 *) match tree with 
  | Empty ->
    (* 0 *) Node(Empty, x, data (), Empty, 1)
  | Node(l, v, d, r, h) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then
      (* 0 *) Node(l, x, replace  d , r, h)
    else (* 0 *) if c < 0 then
      (* 0 *) bal (adjust x data replace l) v d r
    else
      (* 0 *) bal l v d (adjust x data replace r)


let rec find_exn x (tree : _ Map_gen.t )  = (* 6 *) match tree with 
  | Empty ->
    (* 0 *) raise Not_found
  | Node(l, v, d, r, _) ->
    (* 6 *) let c = compare_key x v in
    if c = 0 then (* 6 *) d
    else (* 0 *) find_exn x (if c < 0 then (* 0 *) l else (* 0 *) r)

let rec find_opt x (tree : _ Map_gen.t )  = (* 0 *) match tree with 
  | Empty -> (* 0 *) None 
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then (* 0 *) Some d
    else (* 0 *) find_opt x (if c < 0 then (* 0 *) l else (* 0 *) r)

let rec find_default x (tree : _ Map_gen.t ) default     = (* 0 *) match tree with 
  | Empty -> (* 0 *) default  
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then  (* 0 *) d
    else (* 0 *) find_default x   (if c < 0 then (* 0 *) l else (* 0 *) r) default

let rec mem x (tree : _ Map_gen.t )   = (* 0 *) match tree with 
  | Empty ->
    (* 0 *) false
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    c = 0 || mem x (if c < 0 then (* 0 *) l else (* 0 *) r)

let rec remove x (tree : _ Map_gen.t as 'a) : 'a = (* 0 *) match tree with 
  | Empty ->
    (* 0 *) Empty
  | Node(l, v, d, r, h) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then
      (* 0 *) Map_gen.merge l r
    else (* 0 *) if c < 0 then
      (* 0 *) bal (remove x l) v d r
    else
      (* 0 *) bal l v d (remove x r)


let rec split x (tree : _ Map_gen.t as 'a) : 'a * _ option * 'a  = (* 0 *) match tree with 
  | Empty ->
    (* 0 *) (Empty, None, Empty)
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then (* 0 *) (l, Some d, r)
    else (* 0 *) if c < 0 then
      (* 0 *) let (ll, pres, rl) = split x l in (ll, pres, Map_gen.join rl v d r)
    else
      (* 0 *) let (lr, pres, rr) = split x r in (Map_gen.join l v d lr, pres, rr)

let rec merge f (s1 : _ Map_gen.t) (s2  : _ Map_gen.t) : _ Map_gen.t =
  (* 0 *) match (s1, s2) with
  | (Empty, Empty) -> (* 0 *) Empty
  | (Node (l1, v1, d1, r1, h1), _) when (* 0 *) h1 >= height s2 ->
    (* 0 *) let (l2, d2, r2) = split v1 s2 in
    Map_gen.concat_or_join (merge f l1 l2) v1 (f v1 (Some d1) d2) (merge f r1 r2)
  | (_, Node (l2, v2, d2, r2, h2)) ->
    (* 0 *) let (l1, d1, r1) = split v2 s1 in
    Map_gen.concat_or_join (merge f l1 l2) v2 (f v2 d1 (Some d2)) (merge f r1 r2)
  | _ ->
    (* 0 *) assert false

let rec disjoint_merge  (s1 : _ Map_gen.t) (s2  : _ Map_gen.t) : _ Map_gen.t =
  (* 0 *) match (s1, s2) with
  | (Empty, Empty) -> (* 0 *) Empty
  | (Node (l1, v1, d1, r1, h1), _) when (* 0 *) h1 >= height s2 ->
    (* 0 *) begin match split v1 s2 with 
    | l2, None, r2 -> 
      (* 0 *) Map_gen.join (disjoint_merge  l1 l2) v1 d1 (disjoint_merge r1 r2)
    | _, Some _, _ ->
      (* 0 *) raise (Duplicate_key  v1)
    end        
  | (_, Node (l2, v2, d2, r2, h2)) ->
    (* 0 *) begin match  split v2 s1 with 
    | (l1, None, r1) -> 
      (* 0 *) Map_gen.join (disjoint_merge  l1 l2) v2 d2 (disjoint_merge  r1 r2)
    | (_, Some _, _) -> 
      (* 0 *) raise (Duplicate_key v2)
    end
  | _ ->
    (* 0 *) assert false



let compare cmp m1 m2 = (* 0 *) Map_gen.compare compare_key cmp m1 m2

let equal cmp m1 m2 = (* 0 *) Map_gen.equal compare_key cmp m1 m2 

let add_list (xs : _ list ) init = 
  (* 0 *) List.fold_left (fun acc (k,v) -> (* 0 *) add k v acc) init xs 

let of_list xs = (* 0 *) add_list xs empty

let of_array xs = 
  (* 0 *) Array.fold_left (fun acc (k,v) -> (* 0 *) add k v acc) empty xs

end
module Ext_json_types
= struct
#1 "ext_json_types.ml"
(* Copyright (C) 2015-2017 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

type loc = Lexing.position
type json_str = 
  { str : string ; loc : loc}

type json_flo  =
  { str : string ; loc : loc}
type json_array =
  { content : t array ; 
    loc_start : loc ; 
    loc_end : loc ; 
  }

and json_map = 
  { map : t String_map.t ; loc :  loc }
and t = 
  | True of loc 
  | False of loc 
  | Null of loc 
  | Flo of json_flo
  | Str of json_str
  | Arr  of json_array
  | Obj of json_map
   

end
module Ext_position : sig 
#1 "ext_position.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


type t = Lexing.position = {
    pos_fname : string ;
    pos_lnum : int ;
    pos_bol : int ;
    pos_cnum : int
}


val print : Format.formatter -> t -> unit 
end = struct
#1 "ext_position.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


type t = Lexing.position = {
    pos_fname : string ;
    pos_lnum : int ;
    pos_bol : int ;
    pos_cnum : int
}


let print fmt (pos : t) = 
  (* 0 *) Format.fprintf fmt "(%d,%d)" pos.pos_lnum (pos.pos_cnum - pos.pos_bol)






end
module Ext_json : sig 
#1 "ext_json.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


type path = string list 
type status = 
  | No_path
  | Found of Ext_json_types.t 
  | Wrong_type of path 


type callback = 
  [
    `Str of (string -> unit) 
  | `Str_loc of (string -> Lexing.position -> unit)
  | `Flo of (string -> unit )
  | `Bool of (bool -> unit )
  | `Obj of (Ext_json_types.t String_map.t -> unit)
  | `Arr of (Ext_json_types.t array -> unit )
  | `Arr_loc of 
    (Ext_json_types.t array -> Lexing.position -> Lexing.position -> unit)
  | `Null of (unit -> unit)
  | `Not_found of (unit -> unit)
  | `Id of (Ext_json_types.t -> unit )
  ]

val test:
  ?fail:(unit -> unit) ->
  string -> callback 
  -> Ext_json_types.t String_map.t
   -> Ext_json_types.t String_map.t

val query : path -> Ext_json_types.t ->  status

val loc_of : Ext_json_types.t -> Ext_position.t

end = struct
#1 "ext_json.ml"


type callback = 
  [
    `Str of (string -> unit) 
  | `Str_loc of (string -> Lexing.position -> unit)
  | `Flo of (string -> unit )
  | `Bool of (bool -> unit )
  | `Obj of (Ext_json_types.t String_map.t -> unit)
  | `Arr of (Ext_json_types.t array -> unit )
  | `Arr_loc of (Ext_json_types.t array -> Lexing.position -> Lexing.position -> unit)
  | `Null of (unit -> unit)
  | `Not_found of (unit -> unit)
  | `Id of (Ext_json_types.t -> unit )
  ]

  
type path = string list 

type status = 
  | No_path
  | Found  of Ext_json_types.t 
  | Wrong_type of path 

let test   ?(fail=(fun () -> ())) key 
    (cb : callback) (m  : Ext_json_types.t String_map.t)
     =
     (* 6 *) begin match String_map.find_exn key m, cb with 
       | exception Not_found  ->
        (* 0 *) begin match cb with `Not_found f ->  (* 0 *) f ()
        | _ -> (* 0 *) fail ()
        end      
       | True _, `Bool cb -> (* 0 *) cb true
       | False _, `Bool cb  -> (* 0 *) cb false 
       | Flo {str = s} , `Flo cb  -> (* 6 *) cb s 
       | Obj {map = b} , `Obj cb -> (* 0 *) cb b 
       | Arr {content}, `Arr cb -> (* 0 *) cb content 
       | Arr {content; loc_start ; loc_end}, `Arr_loc cb -> 
         (* 0 *) cb content  loc_start loc_end 
       | Null _, `Null cb  -> (* 0 *) cb ()
       | Str {str = s }, `Str cb  -> (* 0 *) cb s 
       | Str {str = s ; loc }, `Str_loc cb -> (* 0 *) cb s loc 
       |  any  , `Id  cb -> (* 0 *) cb any
       | _, _ -> (* 0 *) fail () 
     end;
     m
let query path (json : Ext_json_types.t ) =
  (* 0 *) let rec aux acc paths json =
    (* 0 *) match path with 
    | [] ->  (* 0 *) Found json
    | p :: rest -> 
      (* 0 *) begin match json with 
        | Obj {map = m} -> 
          (* 0 *) begin match String_map.find_exn p m with 
            | m'  -> (* 0 *) aux (p::acc) rest m'
            | exception Not_found ->  (* 0 *) No_path
          end
        | _ -> (* 0 *) Wrong_type acc 
      end
  in aux [] path json


let loc_of (x : Ext_json_types.t) =
  (* 0 *) match x with
  | True p | False p | Null p -> (* 0 *) p 
  | Str p -> (* 0 *) p.loc 
  | Arr p -> (* 0 *) p.loc_start
  | Obj p -> (* 0 *) p.loc
  | Flo p -> (* 0 *) p.loc
 

end
module Ext_json_parse : sig 
#1 "ext_json_parse.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

type error_info

exception Error of error_info

val pp_error : Format.formatter -> error_info -> unit 

val parse_json : Lexing.lexbuf -> Ext_json_types.t 
val parse_json_from_string : string -> Ext_json_types.t 

val parse_json_from_chan : in_channel -> Ext_json_types.t 

val parse_json_from_file  : string -> Ext_json_types.t


end = struct
#1 "ext_json_parse.ml"
# 1 "ext/ext_json_parse.mll"
 
type error =
  | Illegal_character of char
  | Unterminated_string
  | Unterminated_comment
  | Illegal_escape of string
  | Unexpected_token 
  | Expect_comma_or_rbracket
  | Expect_comma_or_rbrace
  | Expect_colon
  | Expect_string_or_rbrace 
  | Expect_eof 
  (* | Trailing_comma_in_obj *)
  (* | Trailing_comma_in_array *)
exception Error of error * Lexing.position * Lexing.position;;

let fprintf  = Format.fprintf
let report_error ppf = function
  | Illegal_character c ->
      (* 0 *) fprintf ppf "Illegal character (%s)" (Char.escaped c)
  | Illegal_escape s ->
      (* 0 *) fprintf ppf "Illegal backslash escape in string or character (%s)" s
  | Unterminated_string -> 
      (* 0 *) fprintf ppf "Unterminated_string"
  | Expect_comma_or_rbracket ->
    (* 0 *) fprintf ppf "Expect_comma_or_rbracket"
  | Expect_comma_or_rbrace -> 
    (* 0 *) fprintf ppf "Expect_comma_or_rbrace"
  | Expect_colon -> 
    (* 0 *) fprintf ppf "Expect_colon"
  | Expect_string_or_rbrace  -> 
    (* 0 *) fprintf ppf "Expect_string_or_rbrace"
  | Expect_eof  -> 
    (* 0 *) fprintf ppf "Expect_eof"
  | Unexpected_token 
    ->
    (* 0 *) fprintf ppf "Unexpected_token"
  (* | Trailing_comma_in_obj  *)
  (*   -> fprintf ppf "Trailing_comma_in_obj" *)
  (* | Trailing_comma_in_array  *)
  (*   -> fprintf ppf "Trailing_comma_in_array" *)
  | Unterminated_comment 
    -> (* 0 *) fprintf ppf "Unterminated_comment"
         

type  error_info  = 
  { error : error ;
    loc_start : Lexing.position; 
    loc_end :Lexing.position;
  }

let pp_error fmt {error; loc_start ; loc_end } = 
  (* 0 *) Format.fprintf fmt "@[%a:@ %a@ -@ %a)@]" 
    report_error error
    Ext_position.print loc_start
    Ext_position.print loc_end

exception Error of error_info



let () = 
  Printexc.register_printer
    (function x -> 
     (* 6 *) match x with 
     | Error error_info -> 
       (* 0 *) Some (Format.asprintf "%a" pp_error error_info)

     | _ -> (* 6 *) None
    )





type token = 
  | Comma
  | Eof
  | False
  | Lbrace
  | Lbracket
  | Null
  | Colon
  | Number of string
  | Rbrace
  | Rbracket
  | String of string
  | True   
  
let error  (lexbuf : Lexing.lexbuf) e = 
  (* 15 *) raise (Error { error =  e; 
                 loc_start =  lexbuf.lex_start_p; 
                 loc_end = lexbuf.lex_curr_p})


let lexeme_len (x : Lexing.lexbuf) =
  (* 0 *) x.lex_curr_pos - x.lex_start_pos

let update_loc ({ lex_curr_p; _ } as lexbuf : Lexing.lexbuf) diff =
  (* 0 *) lexbuf.lex_curr_p <-
    {
      lex_curr_p with
      pos_lnum = lex_curr_p.pos_lnum + 1;
      pos_bol = lex_curr_p.pos_cnum - diff;
    }

let char_for_backslash = function
  | 'n' -> (* 0 *) '\010'
  | 'r' -> (* 0 *) '\013'
  | 'b' -> (* 0 *) '\008'
  | 't' -> (* 0 *) '\009'
  | c -> (* 0 *) c

let dec_code c1 c2 c3 =
  (* 0 *) 100 * (Char.code c1 - 48) + 10 * (Char.code c2 - 48) + (Char.code c3 - 48)

let hex_code c1 c2 =
  (* 0 *) let d1 = Char.code c1 in
  let val1 =
    if d1 >= 97 then (* 0 *) d1 - 87
    else (* 0 *) if d1 >= 65 then (* 0 *) d1 - 55
    else (* 0 *) d1 - 48 in
  let d2 = Char.code c2 in
  let val2 =
    if d2 >= 97 then (* 0 *) d2 - 87
    else (* 0 *) if d2 >= 65 then (* 0 *) d2 - 55
    else (* 0 *) d2 - 48 in
  val1 * 16 + val2

let lf = '\010'

# 134 "ext/ext_json_parse.ml"
let __ocaml_lex_tables = {
  Lexing.lex_base = 
   "\000\000\239\255\240\255\241\255\000\000\025\000\011\000\244\255\
    \245\255\246\255\247\255\248\255\249\255\000\000\000\000\000\000\
    \041\000\001\000\254\255\005\000\005\000\253\255\001\000\002\000\
    \252\255\000\000\000\000\003\000\251\255\001\000\003\000\250\255\
    \079\000\089\000\099\000\121\000\131\000\141\000\153\000\163\000\
    \001\000\253\255\254\255\023\000\255\255\006\000\246\255\189\000\
    \248\255\215\000\255\255\249\255\249\000\181\000\252\255\009\000\
    \063\000\075\000\234\000\251\255\032\001\250\255";
  Lexing.lex_backtrk = 
   "\255\255\255\255\255\255\255\255\013\000\013\000\016\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\016\000\016\000\016\000\
    \016\000\016\000\255\255\000\000\012\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\013\000\255\255\013\000\255\255\013\000\255\255\
    \255\255\255\255\255\255\001\000\255\255\255\255\255\255\008\000\
    \255\255\255\255\255\255\255\255\006\000\006\000\255\255\006\000\
    \001\000\002\000\255\255\255\255\255\255\255\255";
  Lexing.lex_default = 
   "\001\000\000\000\000\000\000\000\255\255\255\255\255\255\000\000\
    \000\000\000\000\000\000\000\000\000\000\255\255\255\255\255\255\
    \255\255\255\255\000\000\255\255\020\000\000\000\255\255\255\255\
    \000\000\255\255\255\255\255\255\000\000\255\255\255\255\000\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \042\000\000\000\000\000\255\255\000\000\047\000\000\000\047\000\
    \000\000\051\000\000\000\000\000\255\255\255\255\000\000\255\255\
    \255\255\255\255\255\255\000\000\255\255\000\000";
  Lexing.lex_trans = 
   "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\019\000\018\000\018\000\019\000\017\000\019\000\255\255\
    \048\000\019\000\255\255\057\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \019\000\000\000\003\000\000\000\000\000\019\000\000\000\000\000\
    \050\000\000\000\000\000\043\000\008\000\006\000\033\000\016\000\
    \004\000\005\000\005\000\005\000\005\000\005\000\005\000\005\000\
    \005\000\005\000\007\000\004\000\005\000\005\000\005\000\005\000\
    \005\000\005\000\005\000\005\000\005\000\032\000\044\000\033\000\
    \056\000\005\000\005\000\005\000\005\000\005\000\005\000\005\000\
    \005\000\005\000\005\000\021\000\057\000\000\000\000\000\000\000\
    \020\000\000\000\000\000\012\000\000\000\011\000\032\000\056\000\
    \000\000\025\000\049\000\000\000\000\000\032\000\014\000\024\000\
    \028\000\000\000\000\000\057\000\026\000\030\000\013\000\031\000\
    \000\000\000\000\022\000\027\000\015\000\029\000\023\000\000\000\
    \000\000\000\000\039\000\010\000\039\000\009\000\032\000\038\000\
    \038\000\038\000\038\000\038\000\038\000\038\000\038\000\038\000\
    \038\000\034\000\034\000\034\000\034\000\034\000\034\000\034\000\
    \034\000\034\000\034\000\034\000\034\000\034\000\034\000\034\000\
    \034\000\034\000\034\000\034\000\034\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\037\000\000\000\037\000\000\000\
    \035\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\036\000\036\000\255\255\
    \035\000\038\000\038\000\038\000\038\000\038\000\038\000\038\000\
    \038\000\038\000\038\000\038\000\038\000\038\000\038\000\038\000\
    \038\000\038\000\038\000\038\000\038\000\000\000\000\000\255\255\
    \000\000\056\000\000\000\000\000\055\000\058\000\058\000\058\000\
    \058\000\058\000\058\000\058\000\058\000\058\000\058\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\054\000\
    \000\000\054\000\000\000\000\000\000\000\000\000\054\000\000\000\
    \002\000\041\000\000\000\000\000\000\000\255\255\046\000\053\000\
    \053\000\053\000\053\000\053\000\053\000\053\000\053\000\053\000\
    \053\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\255\255\059\000\059\000\059\000\059\000\059\000\059\000\
    \059\000\059\000\059\000\059\000\000\000\000\000\000\000\000\000\
    \000\000\060\000\060\000\060\000\060\000\060\000\060\000\060\000\
    \060\000\060\000\060\000\054\000\000\000\000\000\000\000\000\000\
    \000\000\054\000\060\000\060\000\060\000\060\000\060\000\060\000\
    \000\000\000\000\000\000\000\000\000\000\054\000\000\000\000\000\
    \000\000\054\000\000\000\054\000\000\000\000\000\000\000\052\000\
    \061\000\061\000\061\000\061\000\061\000\061\000\061\000\061\000\
    \061\000\061\000\060\000\060\000\060\000\060\000\060\000\060\000\
    \000\000\061\000\061\000\061\000\061\000\061\000\061\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\061\000\061\000\061\000\061\000\061\000\061\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\255\255\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\255\255\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000";
  Lexing.lex_check = 
   "\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\000\000\000\000\017\000\000\000\000\000\019\000\020\000\
    \045\000\019\000\020\000\055\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \000\000\255\255\000\000\255\255\255\255\019\000\255\255\255\255\
    \045\000\255\255\255\255\040\000\000\000\000\000\004\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\006\000\006\000\006\000\006\000\006\000\
    \006\000\006\000\006\000\006\000\006\000\004\000\043\000\005\000\
    \056\000\005\000\005\000\005\000\005\000\005\000\005\000\005\000\
    \005\000\005\000\005\000\016\000\057\000\255\255\255\255\255\255\
    \016\000\255\255\255\255\000\000\255\255\000\000\005\000\056\000\
    \255\255\014\000\045\000\255\255\255\255\004\000\000\000\023\000\
    \027\000\255\255\255\255\057\000\025\000\029\000\000\000\030\000\
    \255\255\255\255\015\000\026\000\000\000\013\000\022\000\255\255\
    \255\255\255\255\032\000\000\000\032\000\000\000\005\000\032\000\
    \032\000\032\000\032\000\032\000\032\000\032\000\032\000\032\000\
    \032\000\033\000\033\000\033\000\033\000\033\000\033\000\033\000\
    \033\000\033\000\033\000\034\000\034\000\034\000\034\000\034\000\
    \034\000\034\000\034\000\034\000\034\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\035\000\255\255\035\000\255\255\
    \034\000\035\000\035\000\035\000\035\000\035\000\035\000\035\000\
    \035\000\035\000\035\000\036\000\036\000\036\000\036\000\036\000\
    \036\000\036\000\036\000\036\000\036\000\037\000\037\000\037\000\
    \037\000\037\000\037\000\037\000\037\000\037\000\037\000\047\000\
    \034\000\038\000\038\000\038\000\038\000\038\000\038\000\038\000\
    \038\000\038\000\038\000\039\000\039\000\039\000\039\000\039\000\
    \039\000\039\000\039\000\039\000\039\000\255\255\255\255\047\000\
    \255\255\049\000\255\255\255\255\049\000\053\000\053\000\053\000\
    \053\000\053\000\053\000\053\000\053\000\053\000\053\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\049\000\
    \255\255\049\000\255\255\255\255\255\255\255\255\049\000\255\255\
    \000\000\040\000\255\255\255\255\255\255\020\000\045\000\049\000\
    \049\000\049\000\049\000\049\000\049\000\049\000\049\000\049\000\
    \049\000\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\047\000\058\000\058\000\058\000\058\000\058\000\058\000\
    \058\000\058\000\058\000\058\000\255\255\255\255\255\255\255\255\
    \255\255\052\000\052\000\052\000\052\000\052\000\052\000\052\000\
    \052\000\052\000\052\000\049\000\255\255\255\255\255\255\255\255\
    \255\255\049\000\052\000\052\000\052\000\052\000\052\000\052\000\
    \255\255\255\255\255\255\255\255\255\255\049\000\255\255\255\255\
    \255\255\049\000\255\255\049\000\255\255\255\255\255\255\049\000\
    \060\000\060\000\060\000\060\000\060\000\060\000\060\000\060\000\
    \060\000\060\000\052\000\052\000\052\000\052\000\052\000\052\000\
    \255\255\060\000\060\000\060\000\060\000\060\000\060\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\060\000\060\000\060\000\060\000\060\000\060\000\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\047\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\049\000\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255";
  Lexing.lex_base_code = 
   "";
  Lexing.lex_backtrk_code = 
   "";
  Lexing.lex_default_code = 
   "";
  Lexing.lex_trans_code = 
   "";
  Lexing.lex_check_code = 
   "";
  Lexing.lex_code = 
   "";
}

let rec lex_json buf lexbuf =
    (* 258 *) __ocaml_lex_lex_json_rec buf lexbuf 0
and __ocaml_lex_lex_json_rec buf lexbuf __ocaml_lex_state =
  (* 258 *) match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 152 "ext/ext_json_parse.mll"
          (* 93 *) ( lex_json buf lexbuf)
# 324 "ext/ext_json_parse.ml"

  | 1 ->
# 153 "ext/ext_json_parse.mll"
                   (* 0 *) ( 
    update_loc lexbuf 0;
    lex_json buf  lexbuf
  )
# 332 "ext/ext_json_parse.ml"

  | 2 ->
# 157 "ext/ext_json_parse.mll"
                (* 0 *) ( comment buf lexbuf)
# 337 "ext/ext_json_parse.ml"

  | 3 ->
# 158 "ext/ext_json_parse.mll"
         (* 0 *) ( True)
# 342 "ext/ext_json_parse.ml"

  | 4 ->
# 159 "ext/ext_json_parse.mll"
          (* 0 *) (False)
# 347 "ext/ext_json_parse.ml"

  | 5 ->
# 160 "ext/ext_json_parse.mll"
         (* 0 *) (Null)
# 352 "ext/ext_json_parse.ml"

  | 6 ->
# 161 "ext/ext_json_parse.mll"
       (* 15 *) (Lbracket)
# 357 "ext/ext_json_parse.ml"

  | 7 ->
# 162 "ext/ext_json_parse.mll"
       (* 9 *) (Rbracket)
# 362 "ext/ext_json_parse.ml"

  | 8 ->
# 163 "ext/ext_json_parse.mll"
       (* 18 *) (Lbrace)
# 367 "ext/ext_json_parse.ml"

  | 9 ->
# 164 "ext/ext_json_parse.mll"
       (* 9 *) (Rbrace)
# 372 "ext/ext_json_parse.ml"

  | 10 ->
# 165 "ext/ext_json_parse.mll"
       (* 39 *) (Comma)
# 377 "ext/ext_json_parse.ml"

  | 11 ->
# 166 "ext/ext_json_parse.mll"
        (* 12 *) (Colon)
# 382 "ext/ext_json_parse.ml"

  | 12 ->
# 167 "ext/ext_json_parse.mll"
                      (* 0 *) (lex_json buf lexbuf)
# 387 "ext/ext_json_parse.ml"

  | 13 ->
# 169 "ext/ext_json_parse.mll"
         (* 33 *) ( Number (Lexing.lexeme lexbuf))
# 392 "ext/ext_json_parse.ml"

  | 14 ->
# 171 "ext/ext_json_parse.mll"
      (* 12 *) (
  let pos = Lexing.lexeme_start_p lexbuf in
  scan_string buf pos lexbuf;
  let content = (Buffer.contents  buf) in 
  Buffer.clear buf ;
  String content 
)
# 403 "ext/ext_json_parse.ml"

  | 15 ->
# 178 "ext/ext_json_parse.mll"
       (* 18 *) (Eof )
# 408 "ext/ext_json_parse.ml"

  | 16 ->
(* 0 *) let
# 179 "ext/ext_json_parse.mll"
       c
# 414 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf lexbuf.Lexing.lex_start_pos in
# 179 "ext/ext_json_parse.mll"
          ( error lexbuf (Illegal_character c ))
# 418 "ext/ext_json_parse.ml"

  | __ocaml_lex_state -> (* 0 *) lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_lex_json_rec buf lexbuf __ocaml_lex_state

and comment buf lexbuf =
    (* 0 *) __ocaml_lex_comment_rec buf lexbuf 40
and __ocaml_lex_comment_rec buf lexbuf __ocaml_lex_state =
  (* 0 *) match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 181 "ext/ext_json_parse.mll"
              (* 0 *) (lex_json buf lexbuf)
# 430 "ext/ext_json_parse.ml"

  | 1 ->
# 182 "ext/ext_json_parse.mll"
     (* 0 *) (comment buf lexbuf)
# 435 "ext/ext_json_parse.ml"

  | 2 ->
# 183 "ext/ext_json_parse.mll"
       (* 0 *) (error lexbuf Unterminated_comment)
# 440 "ext/ext_json_parse.ml"

  | __ocaml_lex_state -> (* 0 *) lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_comment_rec buf lexbuf __ocaml_lex_state

and scan_string buf start lexbuf =
    (* 24 *) __ocaml_lex_scan_string_rec buf start lexbuf 45
and __ocaml_lex_scan_string_rec buf start lexbuf __ocaml_lex_state =
  (* 24 *) match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 187 "ext/ext_json_parse.mll"
      (* 12 *) ( () )
# 452 "ext/ext_json_parse.ml"

  | 1 ->
# 189 "ext/ext_json_parse.mll"
  (* 0 *) (
        let len = lexeme_len lexbuf - 2 in
        update_loc lexbuf len;

        scan_string buf start lexbuf
      )
# 462 "ext/ext_json_parse.ml"

  | 2 ->
# 196 "ext/ext_json_parse.mll"
      (* 0 *) (
        let len = lexeme_len lexbuf - 3 in
        update_loc lexbuf len;
        scan_string buf start lexbuf
      )
# 471 "ext/ext_json_parse.ml"

  | 3 ->
(* 0 *) let
# 201 "ext/ext_json_parse.mll"
                                               c
# 477 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 1) in
# 202 "ext/ext_json_parse.mll"
      (
        Buffer.add_char buf (char_for_backslash c);
        scan_string buf start lexbuf
      )
# 484 "ext/ext_json_parse.ml"

  | 4 ->
(* 0 *) let
# 206 "ext/ext_json_parse.mll"
                 c1
# 490 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 1)
and
# 206 "ext/ext_json_parse.mll"
                               c2
# 495 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 2)
and
# 206 "ext/ext_json_parse.mll"
                                             c3
# 500 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 3)
and
# 206 "ext/ext_json_parse.mll"
                                                    s
# 505 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos (lexbuf.Lexing.lex_start_pos + 4) in
# 207 "ext/ext_json_parse.mll"
      (
        let v = dec_code c1 c2 c3 in
        if v > 255 then
          (* 0 *) error lexbuf (Illegal_escape s) ;
        Buffer.add_char buf (Char.chr v);

        scan_string buf start lexbuf
      )
# 516 "ext/ext_json_parse.ml"

  | 5 ->
(* 0 *) let
# 215 "ext/ext_json_parse.mll"
                        c1
# 522 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 2)
and
# 215 "ext/ext_json_parse.mll"
                                         c2
# 527 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 3) in
# 216 "ext/ext_json_parse.mll"
      (
        let v = hex_code c1 c2 in
        Buffer.add_char buf (Char.chr v);

        scan_string buf start lexbuf
      )
# 536 "ext/ext_json_parse.ml"

  | 6 ->
(* 0 *) let
# 222 "ext/ext_json_parse.mll"
             c
# 542 "ext/ext_json_parse.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 1) in
# 223 "ext/ext_json_parse.mll"
      (
        Buffer.add_char buf '\\';
        Buffer.add_char buf c;

        scan_string buf start lexbuf
      )
# 551 "ext/ext_json_parse.ml"

  | 7 ->
# 230 "ext/ext_json_parse.mll"
      (* 0 *) (
        update_loc lexbuf 0;
        Buffer.add_char buf lf;

        scan_string buf start lexbuf
      )
# 561 "ext/ext_json_parse.ml"

  | 8 ->
# 237 "ext/ext_json_parse.mll"
      (* 12 *) (
        let ofs = lexbuf.lex_start_pos in
        let len = lexbuf.lex_curr_pos - ofs in
        Buffer.add_substring buf lexbuf.lex_buffer ofs len;

        scan_string buf start lexbuf
      )
# 572 "ext/ext_json_parse.ml"

  | 9 ->
# 245 "ext/ext_json_parse.mll"
      (* 0 *) (
        error lexbuf Unterminated_string
      )
# 579 "ext/ext_json_parse.ml"

  | __ocaml_lex_state -> (* 0 *) lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_scan_string_rec buf start lexbuf __ocaml_lex_state

;;

# 249 "ext/ext_json_parse.mll"
 






let rec parse_json lexbuf =
  (* 33 *) let buf = Buffer.create 64 in 
  let look_ahead = ref None in
  let token () : token = 
    (* 189 *) match !look_ahead with 
    | None ->  
      (* 165 *) lex_json buf lexbuf 
    | Some x -> 
      (* 24 *) look_ahead := None ;
      x 
  in
  let push e = (* 24 *) look_ahead := Some e in 
  let rec json (lexbuf : Lexing.lexbuf) : Ext_json_types.t = 
    (* 69 *) match token () with 
    | True -> (* 0 *) True lexbuf.lex_start_p
    | False -> (* 0 *) False lexbuf.lex_start_p
    | Null -> (* 0 *) Null lexbuf.lex_start_p
    | Number s ->  (* 30 *) Flo {str = s; loc = lexbuf.lex_start_p}  
    | String s -> (* 0 *) Str { str = s; loc =    lexbuf.lex_start_p}
    | Lbracket -> (* 15 *) parse_array  lexbuf.lex_start_p lexbuf.lex_curr_p [] lexbuf
    | Lbrace -> (* 18 *) parse_map lexbuf.lex_start_p String_map.empty lexbuf
    |  _ -> (* 6 *) error lexbuf Unexpected_token
(** Note if we remove [trailing_comma] support 
    we should report errors (actually more work), for example 
    {[
    match token () with 
    | Rbracket ->
      if trailing_comma then
        error lexbuf Trailing_comma_in_array
      else
    ]} 
    {[
    match token () with 
    | Rbrace -> 
      if trailing_comma then
        error lexbuf Trailing_comma_in_obj
      else

    ]}   
 *)
  and parse_array   loc_start loc_finish acc lexbuf 
    : Ext_json_types.t =
    (* 30 *) match token () with 
    | Rbracket ->
        (* 6 *) Arr {loc_start ; content = Ext_array.reverse_of_list acc ; 
              loc_end = lexbuf.lex_curr_p }
    | x -> 
      (* 24 *) push x ;
      let new_one = json lexbuf in 
      begin match token ()  with 
      | Comma -> 
          (* 15 *) parse_array  loc_start loc_finish (new_one :: acc) lexbuf 
      | Rbracket 
        -> (* 3 *) Arr {content = (Ext_array.reverse_of_list (new_one::acc));
                     loc_start ; 
                     loc_end = lexbuf.lex_curr_p }
      | _ -> 
        (* 0 *) error lexbuf Expect_comma_or_rbracket
      end
  and parse_map loc_start  acc lexbuf : Ext_json_types.t = 
    (* 30 *) match token () with 
    | Rbrace -> 
        (* 9 *) Obj { map = acc ; loc = loc_start}
    | String key -> 
      (* 12 *) begin match token () with 
      | Colon ->
        (* 12 *) let value = json lexbuf in
        begin match token () with 
        | Rbrace -> (* 0 *) Obj {map = String_map.add key value acc ; loc = loc_start}
        | Comma -> 
          (* 12 *) parse_map loc_start  (String_map.add key value acc) lexbuf 
        | _ -> (* 0 *) error lexbuf Expect_comma_or_rbrace
        end
      | _ -> (* 0 *) error lexbuf Expect_colon
      end
    | _ -> (* 9 *) error lexbuf Expect_string_or_rbrace
  in 
  let v = json lexbuf in 
  match token () with 
  | Eof -> (* 18 *) v 
  | _ -> (* 0 *) error lexbuf Expect_eof

let parse_json_from_string s = 
  (* 33 *) parse_json (Lexing.from_string s )

let parse_json_from_chan in_chan = 
  (* 0 *) let lexbuf = Lexing.from_channel in_chan in 
  parse_json lexbuf 

let parse_json_from_file s = 
  (* 0 *) let in_chan = open_in s in 
  let lexbuf = Lexing.from_channel in_chan in 
  match parse_json lexbuf with 
  | exception e -> (* 0 *) close_in in_chan ; raise e
  | v  -> (* 0 *) close_in in_chan;  v





# 694 "ext/ext_json_parse.ml"

end
module Ounit_json_tests
= struct
#1 "ounit_json_tests.ml"

let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

open Ext_json_parse
let (|?)  m (key, cb) =
    (* 6 *) m  |> Ext_json.test key cb 

exception Parse_error 
let suites = 
  __FILE__ 
  >:::
  [
    "empty_json" >:: begin fun _ -> 
      (* 3 *) let v =parse_json_from_string "{}" in
      match v with 
      | Obj {map = v} -> (* 3 *) OUnit.assert_equal (String_map.is_empty v ) true
      | _ -> (* 0 *) OUnit.assert_failure "should be empty"
    end
    ;
    "empty_arr" >:: begin fun _ -> 
      (* 3 *) let v =parse_json_from_string "[]" in
      match v with 
      | Arr {content = [||]} -> (* 3 *) ()
      | _ -> (* 0 *) OUnit.assert_failure "should be empty"
    end
    ;
    "empty trails" >:: begin fun _ -> 
      (* 3 *) (OUnit.assert_raises Parse_error @@ fun _ -> 
       (* 3 *) try parse_json_from_string {| [,]|} with _ -> (* 3 *) raise Parse_error);
      OUnit.assert_raises Parse_error @@ fun _ -> 
        (* 3 *) try parse_json_from_string {| {,}|} with _ -> (* 3 *) raise Parse_error
    end;
    "two trails" >:: begin fun _ -> 
      (* 3 *) (OUnit.assert_raises Parse_error @@ fun _ -> 
       (* 3 *) try parse_json_from_string {| [1,2,,]|} with _ -> (* 3 *) raise Parse_error);
      (OUnit.assert_raises Parse_error @@ fun _ -> 
       (* 3 *) try parse_json_from_string {| { "x": 3, ,}|} with _ -> (* 3 *) raise Parse_error)
    end;

    "two trails fail" >:: begin fun _ -> 
      (* 3 *) (OUnit.assert_raises Parse_error @@ fun _ -> 
       (* 3 *) try parse_json_from_string {| { "x": 3, 2 ,}|} with _ -> (* 3 *) raise Parse_error)
    end;

    "trail comma obj" >:: begin fun _ -> 
      (* 3 *) let v =  parse_json_from_string {| { "x" : 3 , }|} in 
      let v1 =  parse_json_from_string {| { "x" : 3 , }|} in 
      let test (v : Ext_json_types.t)  = 
        (* 6 *) match v with 
        | Obj {map = v} -> 
          (* 6 *) v
          |? ("x" , `Flo (fun x -> (* 6 *) OUnit.assert_equal x "3"))
          |> ignore 
        | _ -> (* 0 *) OUnit.assert_failure "trail comma" in 
      test v ;
      test v1 
    end
    ;
    "trail comma arr" >:: begin fun _ -> 
      (* 3 *) let v = parse_json_from_string {| [ 1, 3, ]|} in
      let v1 = parse_json_from_string {| [ 1, 3 ]|} in
      let test (v : Ext_json_types.t) = 
        (* 6 *) match v with 
        | Arr { content = [| Flo {str = "1"} ; Flo { str = "3"} |] } -> (* 6 *) ()
        | _ -> (* 0 *) OUnit.assert_failure "trailing comma array" in 
      test v ;
      test v1
    end
  ]

end
module Ext_list : sig 
#1 "ext_list.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








(** Extension to the standard library [List] module *)
    
(** TODO some function are no efficiently implemented. *) 

val filter_map : ('a -> 'b option) -> 'a list -> 'b list 

val excludes : ('a -> bool) -> 'a list -> bool * 'a list
val exclude_with_fact : ('a -> bool) -> 'a list -> 'a option * 'a list
val exclude_with_fact2 : 
  ('a -> bool) -> ('a -> bool) -> 'a list -> 'a option * 'a option * 'a list
val same_length : 'a list -> 'b list -> bool

val init : int -> (int -> 'a) -> 'a list

val take : int -> 'a list -> 'a list * 'a list
val try_take : int -> 'a list -> 'a list * int * 'a list 

val exclude_tail : 'a list -> 'a * 'a list

val length_compare : 'a list -> int -> [`Gt | `Eq | `Lt ]

(**

  {[length xs = length ys + n ]}
  input n should be positive 
  TODO: input checking
*)

val length_larger_than_n : 
  int -> 'a list -> 'a list -> bool

val filter_map2 : ('a -> 'b -> 'c option) -> 'a list -> 'b list -> 'c list

val filter_map2i : (int -> 'a -> 'b -> 'c option) -> 'a list -> 'b list -> 'c list

val filter_mapi : (int -> 'a -> 'b option) -> 'a list -> 'b list

val flat_map2 : ('a -> 'b -> 'c list) -> 'a list -> 'b list -> 'c list

val flat_map_acc : ('a -> 'b list) -> 'b list -> 'a list ->  'b list
val flat_map : ('a -> 'b list) -> 'a list -> 'b list


(** for the last element the first element will be passed [true] *)

val fold_right2_last : (bool -> 'a -> 'b -> 'c -> 'c) -> 'a list -> 'b list -> 'c -> 'c

val map_last : (bool -> 'a -> 'b) -> 'a list -> 'b list

val stable_group : ('a -> 'a -> bool) -> 'a list -> 'a list list

val drop : int -> 'a list -> 'a list 

val for_all_ret : ('a -> bool) -> 'a list -> 'a option

val for_all_opt : ('a -> 'b option) -> 'a list -> 'b option
(** [for_all_opt f l] returns [None] if all return [None],  
    otherwise returns the first one. 
 *)

val fold : ('a -> 'b -> 'b) -> 'a list -> 'b -> 'b
(** same as [List.fold_left]. 
    Provide an api so that list can be easily swapped by other containers  
 *)

val rev_map_append : ('a -> 'b) -> 'a list -> 'b list -> 'b list

val rev_map_acc : 'a list -> ('b -> 'a) -> 'b list -> 'a list

val map_acc : 'a list -> ('b -> 'a) -> 'b list -> 'a list

val rev_iter : ('a -> unit) -> 'a list -> unit

val for_all2_no_exn : ('a -> 'b -> bool) -> 'a list -> 'b list -> bool

val find_opt : ('a -> 'b option) -> 'a list -> 'b option

(** [f] is applied follow the list order *)
val split_map : ('a -> 'b * 'c) -> 'a list -> 'b list * 'c list       


val reduce_from_right : ('a -> 'a -> 'a) -> 'a list -> 'a

(** [fn] is applied from left to right *)
val reduce_from_left : ('a -> 'a -> 'a) -> 'a list -> 'a


type 'a t = 'a list ref

val create_ref_empty : unit -> 'a t

val ref_top : 'a t -> 'a 

val ref_empty : 'a t -> bool

val ref_push : 'a -> 'a t -> unit

val ref_pop : 'a t -> 'a

val rev_except_last : 'a list -> 'a list * 'a

val sort_via_array :
  ('a -> 'a -> int) -> 'a list -> 'a list

val last : 'a list -> 'a


(** When [key] is not found unbox the default, 
  if it is found return that, otherwise [assert false ]
 *)
val assoc_by_string : 
  'a  option -> string -> (string * 'a) list -> 'a 

val assoc_by_int : 
  'a  option -> int -> (int * 'a) list -> 'a   
end = struct
#1 "ext_list.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








let rec filter_map (f: 'a -> 'b option) xs = 
  (* 0 *) match xs with 
  | [] -> (* 0 *) []
  | y :: ys -> 
    (* 0 *) begin match f y with 
      | None -> (* 0 *) filter_map f ys
      | Some z -> (* 0 *) z :: filter_map f ys
    end

let excludes (p : 'a -> bool ) l : bool * 'a list=
  (* 0 *) let excluded = ref false in 
  let rec aux accu = function
    | [] -> (* 0 *) List.rev accu
    | x :: l -> 
      (* 0 *) if p x then 
        (* 0 *) begin 
          excluded := true ;
          aux accu l
        end
      else (* 0 *) aux (x :: accu) l in
  let v = aux [] l in 
  if !excluded then (* 0 *) true, v else (* 0 *) false,l

let exclude_with_fact p l =
  (* 0 *) let excluded = ref None in 
  let rec aux accu = function
    | [] -> (* 0 *) List.rev accu
    | x :: l -> 
      (* 0 *) if p x then 
        (* 0 *) begin 
          excluded := Some x ;
          aux accu l
        end
      else (* 0 *) aux (x :: accu) l in
  let v = aux [] l in 
  !excluded , if !excluded <> None then (* 0 *) v else (* 0 *) l 


(** Make sure [p2 x] and [p1 x] will not hold at the same time *)
let exclude_with_fact2 p1 p2 l =
  (* 0 *) let excluded1 = ref None in 
  let excluded2 = ref None in 
  let rec aux accu = function
    | [] -> (* 0 *) List.rev accu
    | x :: l -> 
      (* 0 *) if p1 x then 
        (* 0 *) begin 
          excluded1 := Some x ;
          aux accu l
        end
      else (* 0 *) if p2 x then 
        (* 0 *) begin 
          excluded2 := Some x ; 
          aux accu l 
        end
      else (* 0 *) aux (x :: accu) l in
  let v = aux [] l in 
  !excluded1, !excluded2 , if !excluded1 <> None && !excluded2 <> None then (* 0 *) v else (* 0 *) l 



let rec same_length xs ys = 
  (* 0 *) match xs, ys with 
  | [], [] -> (* 0 *) true
  | _::xs, _::ys -> (* 0 *) same_length xs ys 
  | _, _ -> (* 0 *) false 

let  filter_mapi (f: int -> 'a -> 'b option) xs = 
  (* 0 *) let rec aux i xs = 
    (* 0 *) match xs with 
    | [] -> (* 0 *) []
    | y :: ys -> 
      (* 0 *) begin match f i y with 
        | None -> (* 0 *) aux (i + 1) ys
        | Some z -> (* 0 *) z :: aux (i + 1) ys
      end in
  aux 0 xs 

let rec filter_map2 (f: 'a -> 'b -> 'c option) xs ys = 
  (* 0 *) match xs,ys with 
  | [],[] -> (* 0 *) []
  | u::us, v :: vs -> 
    (* 0 *) begin match f u v with 
      | None -> (* 0 *) filter_map2 f us vs (* idea: rec f us vs instead? *)
      | Some z -> (* 0 *) z :: filter_map2 f us vs
    end
  | _ -> (* 0 *) invalid_arg "Ext_list.filter_map2"

let filter_map2i (f: int ->  'a -> 'b -> 'c option) xs ys = 
  (* 0 *) let rec aux i xs ys = 
    (* 0 *) match xs,ys with 
    | [],[] -> (* 0 *) []
    | u::us, v :: vs -> 
      (* 0 *) begin match f i u v with 
        | None -> (* 0 *) aux (i + 1) us vs (* idea: rec f us vs instead? *)
        | Some z -> (* 0 *) z :: aux (i + 1) us vs
      end
    | _ -> (* 0 *) invalid_arg "Ext_list.filter_map2i" in
  aux 0 xs ys

let rec rev_map_append  f l1 l2 =
  (* 0 *) match l1 with
  | [] -> (* 0 *) l2
  | a :: l -> (* 0 *) rev_map_append f l (f a :: l2)

let flat_map2 f lx ly = 
  (* 0 *) let rec aux acc lx ly = 
    (* 0 *) match lx, ly with 
    | [], [] 
      -> (* 0 *) List.rev acc
    | x::xs, y::ys 
      ->  (* 0 *) aux (List.rev_append (f x y) acc) xs ys
    | _, _ -> (* 0 *) invalid_arg "Ext_list.flat_map2" in
  aux [] lx ly

let rec flat_map_aux f acc append lx =
  (* 27 *) match lx with
  | [] -> (* 9 *) List.rev_append acc append
  | y::ys -> (* 18 *) flat_map_aux f (List.rev_append ( f y)  acc ) append ys 

let flat_map f lx =
  (* 3 *) flat_map_aux f [] [] lx

let flat_map_acc f append lx = (* 6 *) flat_map_aux f [] append lx  

let rec map2_last f l1 l2 =
  (* 0 *) match (l1, l2) with
  | ([], []) -> (* 0 *) []
  | [u], [v] -> (* 0 *) [f true u v ]
  | (a1::l1, a2::l2) -> (* 0 *) let r = f false  a1 a2 in r :: map2_last f l1 l2
  | (_, _) -> (* 0 *) invalid_arg "List.map2_last"

let rec map_last f l1 =
  (* 0 *) match l1 with
  | [] -> (* 0 *) []
  | [u]-> (* 0 *) [f true u ]
  | a1::l1 -> (* 0 *) let r = f false  a1 in r :: map_last f l1


let rec fold_right2_last f l1 l2 accu  = 
  (* 0 *) match (l1, l2) with
  | ([], []) -> (* 0 *) accu
  | [last1], [last2] -> (* 0 *) f true  last1 last2 accu
  | (a1::l1, a2::l2) -> (* 0 *) f false a1 a2 (fold_right2_last f l1 l2 accu)
  | (_, _) -> (* 0 *) invalid_arg "List.fold_right2"


let init n f = 
  (* 0 *) Array.to_list (Array.init n f)

let take n l = 
  (* 6 *) let arr = Array.of_list l in 
  let arr_length =  Array.length arr in
  if arr_length  < n then (* 0 *) invalid_arg "Ext_list.take"
  else (* 6 *) (Array.to_list (Array.sub arr 0 n ), 
        Array.to_list (Array.sub arr n (arr_length - n)))

let try_take n l = 
  (* 0 *) let arr = Array.of_list l in 
  let arr_length =  Array.length arr in
  if arr_length  <= n then 
    (* 0 *) l,  arr_length, []
  else (* 0 *) Array.to_list (Array.sub arr 0 n ), n, (Array.to_list (Array.sub arr n (arr_length - n)))


let rec length_compare l n = 
  (* 57 *) if n < 0 then (* 6 *) `Gt 
  else 
  (* 51 *) begin match l with 
    | _ ::xs -> (* 33 *) length_compare xs (n - 1)
    | [] ->  
      (* 18 *) if n = 0 then (* 15 *) `Eq 
      else (* 3 *) `Lt 
  end
(**

  {[length xs = length ys + n ]}
*)
let rec length_larger_than_n n xs ys =
  (* 18 *) match xs, ys with 
  | _, [] -> (* 9 *) length_compare xs n = `Eq   
  | _::xs, _::ys -> 
    (* 9 *) length_larger_than_n n xs ys
  | [], _ -> (* 0 *) false 
  


let exclude_tail (x : 'a list) = 
  (* 0 *) let rec aux acc x = 
    (* 0 *) match x with 
    | [] -> (* 0 *) invalid_arg "Ext_list.exclude_tail"
    | [ x ] ->  (* 0 *) x, List.rev acc
    | y0::ys -> (* 0 *) aux (y0::acc) ys in
  aux [] x

(* For small list, only need partial equality 
   {[
     group (=) [1;2;3;4;3]
     ;;
     - : int list list = [[3; 3]; [4]; [2]; [1]]
                         # group (=) [];;
     - : 'a list list = []
   ]}
*)
let rec group (cmp : 'a -> 'a -> bool) (lst : 'a list) : 'a list list =
  (* 0 *) match lst with 
  | [] -> (* 0 *) []
  | x::xs -> 
    (* 0 *) aux cmp x (group cmp xs )

and aux cmp (x : 'a)  (xss : 'a list list) : 'a list list = 
  (* 0 *) match xss with 
  | [] -> (* 0 *) [[x]]
  | y::ys -> 
    (* 0 *) if cmp x (List.hd y) (* cannot be null*) then
      (* 0 *) (x::y) :: ys 
    else
      (* 0 *) y :: aux cmp x ys                                 

let stable_group cmp lst =  (* 0 *) group cmp lst |> List.rev 

let rec drop n h = 
  (* 0 *) if n < 0 then (* 0 *) invalid_arg "Ext_list.drop"
  else (* 0 *) if n = 0 then (* 0 *) h 
  else (* 0 *) if h = [] then (* 0 *) invalid_arg "Ext_list.drop"
  else 
    (* 0 *) drop (n - 1) (List.tl h)

let rec for_all_ret  p = function
  | [] -> (* 0 *) None
  | a::l -> 
    (* 0 *) if p a 
    then (* 0 *) for_all_ret p l
    else (* 0 *) Some a 

let rec for_all_opt  p = function
  | [] -> (* 0 *) None
  | a::l -> 
    (* 0 *) match p a with
    | None -> (* 0 *) for_all_opt p l
    | v -> (* 0 *) v 

let fold f l init = 
  (* 0 *) List.fold_left (fun acc i -> (* 0 *) f  i init) init l 

let rev_map_acc  acc f l = 
  (* 0 *) let rec rmap_f accu = function
    | [] -> (* 0 *) accu
    | a::l -> (* 0 *) rmap_f (f a :: accu) l
  in
  rmap_f acc l

let rec map_acc acc f l =   
  (* 12 *) match l with 
  | [] -> (* 3 *) acc 
  | h::hs -> (* 9 *) f h :: map_acc  acc  f hs 



let rec rev_iter f xs =
  (* 0 *) match xs with    
  | [] -> (* 0 *) ()
  | y :: ys -> 
    (* 0 *) rev_iter f ys ;
    f y      

let rec for_all2_no_exn p l1 l2 = 
  (* 0 *) match (l1, l2) with
  | ([], []) -> (* 0 *) true
  | (a1::l1, a2::l2) -> (* 0 *) p a1 a2 && for_all2_no_exn p l1 l2
  | (_, _) -> (* 0 *) false


let rec find_no_exn p = function
  | [] -> (* 0 *) None
  | x :: l -> (* 0 *) if p x then (* 0 *) Some x else (* 0 *) find_no_exn p l


let rec find_opt p = function
  | [] -> (* 0 *) None
  | x :: l -> 
    (* 0 *) match  p x with 
    | Some _ as v  ->  (* 0 *) v
    | None -> (* 0 *) find_opt p l


let split_map 
    ( f : 'a -> ('b * 'c)) (xs : 'a list ) : 'b list  * 'c list = 
  (* 0 *) let rec aux bs cs xs =
    (* 0 *) match xs with 
    | [] -> (* 0 *) List.rev bs, List.rev cs 
    | u::us -> 
      (* 0 *) let b,c =  f u in aux (b::bs) (c ::cs) us in 

  aux [] [] xs 


(*
   {[
     reduce_from_right (-) [1;2;3];;
     - : int = 2
               # reduce_from_right (-) [1;2;3; 4];;
     - : int = -2
                # reduce_from_right (-) [1];;
     - : int = 1
               # reduce_from_right (-) [1;2;3; 4; 5];;
     - : int = 3
   ]} 
*)
let reduce_from_right fn lst = 
  (* 0 *) begin match List.rev lst with
    | last :: rest -> 
      (* 0 *) List.fold_left  (fun x y -> (* 0 *) fn y x) last rest 
    | _ -> (* 0 *) invalid_arg "Ext_list.reduce" 
  end
let reduce_from_left fn lst = 
  (* 0 *) match lst with 
  | first :: rest ->  (* 0 *) List.fold_left fn first rest 
  | _ -> (* 0 *) invalid_arg "Ext_list.reduce_from_left"


type 'a t = 'a list ref

let create_ref_empty () = (* 0 *) ref []

let ref_top x = 
  (* 0 *) match !x with 
  | y::_ -> (* 0 *) y 
  | _ -> (* 0 *) invalid_arg "Ext_list.ref_top"

let ref_empty x = 
  (* 0 *) match !x with [] -> (* 0 *) true | _ -> (* 0 *) false 

let ref_push x refs = 
  (* 0 *) refs := x :: !refs

let ref_pop refs = 
  (* 0 *) match !refs with 
  | [] -> (* 0 *) invalid_arg "Ext_list.ref_pop"
  | x::rest -> 
    (* 0 *) refs := rest ; 
    x     

let rev_except_last xs =
  (* 0 *) let rec aux acc xs =
    (* 0 *) match xs with
    | [ ] -> (* 0 *) invalid_arg "Ext_list.rev_except_last"
    | [ x ] -> (* 0 *) acc ,x
    | x :: xs -> (* 0 *) aux (x::acc) xs in
  aux [] xs   

let sort_via_array cmp lst =
  (* 0 *) let arr = Array.of_list lst  in
  Array.sort cmp arr;
  Array.to_list arr

let rec last xs =
  (* 0 *) match xs with 
  | [x] -> (* 0 *) x 
  | _ :: tl -> (* 0 *) last tl 
  | [] -> (* 0 *) invalid_arg "Ext_list.last"


let rec assoc_by_string def (k : string) lst = 
  (* 0 *) match lst with 
  | [] -> 
    (* 0 *) begin match def with 
    | None -> (* 0 *) assert false 
    | Some x -> (* 0 *) x end
  | (k1,v1)::rest -> 
    (* 0 *) if Ext_string.equal k1 k then (* 0 *) v1 else 
    (* 0 *) assoc_by_string def k rest 

let rec assoc_by_int def (k : int) lst = 
  (* 21 *) match lst with 
  | [] -> 
    (* 3 *) begin match def with
    | None -> (* 3 *) assert false 
    | Some x -> (* 0 *) x end
  | (k1,v1)::rest -> 
    (* 18 *) if k1 = k then (* 3 *) v1 else 
    (* 15 *) assoc_by_int def k rest     

(** `modulo [1;2;3;4] [1;2;3]` => [1;2;3], Some [4] `
  modulo [1;2;3] [1;2;3;4] => [1;2;3] None 
  modulo [1;2;3] [1;2;3] => [1;2;3] Some []
 *)


end
module Ounit_list_test
= struct
#1 "ounit_list_test.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal
let suites = 
  __FILE__
  >:::
  [
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_equal
        (Ext_list.flat_map (fun x -> (* 6 *) [x;x]) [1;2]) [1;1;2;2] 
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_equal
        (Ext_list.flat_map_acc (fun x -> (* 6 *) [x;x]) [3;4] [1;2]) [1;1;2;2;3;4] 
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_equal (
        Ext_list.flat_map_acc (fun x -> (* 6 *) if x mod 2 = 0 then (* 3 *) [true] else (* 3 *) [])
          [false;false] [1;2]
      )  [true;false;false]
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_equal (
        Ext_list.map_acc ["1";"2";"3"] (fun x -> (* 9 *) string_of_int x) [0;1;2] 

      )
        ["0";"1";"2"; "1";"2";"3"]
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let (a,b) = Ext_list.take 3 [1;2;3;4;5;6] in 
      OUnit.assert_equal (a,b)
        ([1;2;3],[4;5;6]);
      OUnit.assert_equal (Ext_list.take 1 [1])
      ([1],[])  
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_equal (Ext_list.assoc_by_int None 1 [2,"x"; 3,"y"; 1, "z"]) "z"
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_raise_any
        (fun _ -> (* 3 *) Ext_list.assoc_by_int None 11 [2,"x"; 3,"y"; 1, "z"])
    end ;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_equal
       (Ext_list.length_compare [0;0;0] 3) `Eq ;
      OUnit.assert_equal
       (Ext_list.length_compare [0;0;0] 1) `Gt ;   
     OUnit.assert_equal
       (Ext_list.length_compare [0;0;0] 4) `Lt ;   
     OUnit.assert_equal
       (Ext_list.length_compare [] (-1)) `Gt ;   
      OUnit.assert_equal
       (Ext_list.length_compare [] (0)) `Eq ;          
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ 
      (Ext_list.length_larger_than_n 1 [1;2] [1]);
      OUnit.assert_bool __LOC__ 
      (Ext_list.length_larger_than_n 0 [1;2] [1;2]);
            OUnit.assert_bool __LOC__ 
      (Ext_list.length_larger_than_n 2 [1;2] [])

    end

  ]
end
module Int_map : sig 
#1 "int_map.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








include Map_gen.S with type key = int

end = struct
#1 "int_map.ml"

# 2 "ext/map.cppo.ml"
(* we don't create [map_poly], since some operations require raise an exception which carries [key] *)


  
# 13
  type key = int
  let compare_key = Ext_int.compare

# 22
type 'a t = (key,'a) Map_gen.t
exception Duplicate_key of key 

let empty = Map_gen.empty 
let is_empty = Map_gen.is_empty
let iter = Map_gen.iter
let fold = Map_gen.fold
let for_all = Map_gen.for_all 
let exists = Map_gen.exists 
let singleton = Map_gen.singleton 
let cardinal = Map_gen.cardinal
let bindings = Map_gen.bindings
let keys = Map_gen.keys
let choose = Map_gen.choose 
let partition = Map_gen.partition 
let filter = Map_gen.filter 
let map = Map_gen.map 
let mapi = Map_gen.mapi
let bal = Map_gen.bal 
let height = Map_gen.height 
let max_binding_exn = Map_gen.max_binding_exn
let min_binding_exn = Map_gen.min_binding_exn


let rec add x data (tree : _ Map_gen.t as 'a) : 'a = (* 32958 *) match tree with 
  | Empty ->
    (* 3024 *) Node(Empty, x, data, Empty, 1)
  | Node(l, v, d, r, h) ->
    (* 29934 *) let c = compare_key x v in
    if c = 0 then
      (* 0 *) Node(l, x, data, r, h)
    else (* 29934 *) if c < 0 then
      (* 6 *) bal (add x data l) v d r
    else
      (* 29928 *) bal l v d (add x data r)


let rec adjust x data replace (tree : _ Map_gen.t as 'a) : 'a = 
  (* 59862 *) match tree with 
  | Empty ->
    (* 3000 *) Node(Empty, x, data (), Empty, 1)
  | Node(l, v, d, r, h) ->
    (* 56862 *) let c = compare_key x v in
    if c = 0 then
      (* 3000 *) Node(l, x, replace  d , r, h)
    else (* 53862 *) if c < 0 then
      (* 12087 *) bal (adjust x data replace l) v d r
    else
      (* 41775 *) bal l v d (adjust x data replace r)


let rec find_exn x (tree : _ Map_gen.t )  = (* 0 *) match tree with 
  | Empty ->
    (* 0 *) raise Not_found
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then (* 0 *) d
    else (* 0 *) find_exn x (if c < 0 then (* 0 *) l else (* 0 *) r)

let rec find_opt x (tree : _ Map_gen.t )  = (* 0 *) match tree with 
  | Empty -> (* 0 *) None 
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then (* 0 *) Some d
    else (* 0 *) find_opt x (if c < 0 then (* 0 *) l else (* 0 *) r)

let rec find_default x (tree : _ Map_gen.t ) default     = (* 0 *) match tree with 
  | Empty -> (* 0 *) default  
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then  (* 0 *) d
    else (* 0 *) find_default x   (if c < 0 then (* 0 *) l else (* 0 *) r) default

let rec mem x (tree : _ Map_gen.t )   = (* 0 *) match tree with 
  | Empty ->
    (* 0 *) false
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    c = 0 || mem x (if c < 0 then (* 0 *) l else (* 0 *) r)

let rec remove x (tree : _ Map_gen.t as 'a) : 'a = (* 0 *) match tree with 
  | Empty ->
    (* 0 *) Empty
  | Node(l, v, d, r, h) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then
      (* 0 *) Map_gen.merge l r
    else (* 0 *) if c < 0 then
      (* 0 *) bal (remove x l) v d r
    else
      (* 0 *) bal l v d (remove x r)


let rec split x (tree : _ Map_gen.t as 'a) : 'a * _ option * 'a  = (* 0 *) match tree with 
  | Empty ->
    (* 0 *) (Empty, None, Empty)
  | Node(l, v, d, r, _) ->
    (* 0 *) let c = compare_key x v in
    if c = 0 then (* 0 *) (l, Some d, r)
    else (* 0 *) if c < 0 then
      (* 0 *) let (ll, pres, rl) = split x l in (ll, pres, Map_gen.join rl v d r)
    else
      (* 0 *) let (lr, pres, rr) = split x r in (Map_gen.join l v d lr, pres, rr)

let rec merge f (s1 : _ Map_gen.t) (s2  : _ Map_gen.t) : _ Map_gen.t =
  (* 0 *) match (s1, s2) with
  | (Empty, Empty) -> (* 0 *) Empty
  | (Node (l1, v1, d1, r1, h1), _) when (* 0 *) h1 >= height s2 ->
    (* 0 *) let (l2, d2, r2) = split v1 s2 in
    Map_gen.concat_or_join (merge f l1 l2) v1 (f v1 (Some d1) d2) (merge f r1 r2)
  | (_, Node (l2, v2, d2, r2, h2)) ->
    (* 0 *) let (l1, d1, r1) = split v2 s1 in
    Map_gen.concat_or_join (merge f l1 l2) v2 (f v2 d1 (Some d2)) (merge f r1 r2)
  | _ ->
    (* 0 *) assert false

let rec disjoint_merge  (s1 : _ Map_gen.t) (s2  : _ Map_gen.t) : _ Map_gen.t =
  (* 0 *) match (s1, s2) with
  | (Empty, Empty) -> (* 0 *) Empty
  | (Node (l1, v1, d1, r1, h1), _) when (* 0 *) h1 >= height s2 ->
    (* 0 *) begin match split v1 s2 with 
    | l2, None, r2 -> 
      (* 0 *) Map_gen.join (disjoint_merge  l1 l2) v1 d1 (disjoint_merge r1 r2)
    | _, Some _, _ ->
      (* 0 *) raise (Duplicate_key  v1)
    end        
  | (_, Node (l2, v2, d2, r2, h2)) ->
    (* 0 *) begin match  split v2 s1 with 
    | (l1, None, r1) -> 
      (* 0 *) Map_gen.join (disjoint_merge  l1 l2) v2 d2 (disjoint_merge  r1 r2)
    | (_, Some _, _) -> 
      (* 0 *) raise (Duplicate_key v2)
    end
  | _ ->
    (* 0 *) assert false



let compare cmp m1 m2 = (* 0 *) Map_gen.compare compare_key cmp m1 m2

let equal cmp m1 m2 = (* 0 *) Map_gen.equal compare_key cmp m1 m2 

let add_list (xs : _ list ) init = 
  (* 6 *) List.fold_left (fun acc (k,v) -> (* 24 *) add k v acc) init xs 

let of_list xs = (* 6 *) add_list xs empty

let of_array xs = 
  (* 3 *) Array.fold_left (fun acc (k,v) -> (* 3000 *) add k v acc) empty xs

end
module Ounit_map_tests
= struct
#1 "ounit_map_tests.ml"
let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal 

let suites = 
  __MODULE__ >:::
  [
    __LOC__ >:: begin fun _ -> 
      (* 3 *) [1,"1"; 2,"2"; 12,"12"; 3, "3"]
      |> Int_map.of_list 
      |> Int_map.keys 
      |> OUnit.assert_equal [1;2;3;12]
    end
    ;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_equal (Int_map.cardinal Int_map.empty) 0 ;
      OUnit.assert_equal ([1,"1"; 2,"2"; 12,"12"; 3, "3"]
      |> Int_map.of_list|>Int_map.cardinal )  4
      
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) Int_map.cardinal (Int_map.of_array (Array.init 1000 (fun i -> (* 3000 *) (i,i))))
      =~ 1000
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let count = 1000 in 
      let a = Array.init count (fun x -> (* 3000 *) x ) in 
      let v = Int_map.empty in
      let u = 
        begin 
          let v = Array.fold_left (fun acc key -> (* 3000 *) Int_map.adjust key (fun _ -> (* 3000 *) 1) (succ) acc ) v a   in 
          Array.fold_left (fun acc key -> (* 3000 *) Int_map.adjust key (fun _ -> (* 0 *) 1) (succ) acc ) v a  
          end
        in  
       Int_map.iter (fun _ v -> (* 3000 *) v =~ 2 ) u   ;
       Int_map.cardinal u =~ count
    end
  ]

end
module Ounit_ordered_hash_set_tests
= struct
#1 "ounit_ordered_hash_set_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal


let suites = 
  __FILE__
  >::: [
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let a = [|"a";"b";"c"|] in 
      Ordered_hash_set_string.(to_sorted_array (of_array a))
      =~ a 
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let a = Array.init 1000 (fun i -> (* 3000 *) string_of_int i) in 
      Ordered_hash_set_string.(to_sorted_array (of_array a))
      =~ a
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let a = [|"a";"b";"c"; "a"; "d"|] in 
      Ordered_hash_set_string.(to_sorted_array (of_array a))
      =~ [| "a" ; "b"; "c"; "d" |]
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) let b = Array.init 500 (fun i -> (* 1500 *) string_of_int i) in
      let a = Array.append b b in 
      Ordered_hash_set_string.(to_sorted_array (of_array a))
      =~ b
    end;

    __LOC__ >:: begin fun _ ->
      (* 3 *) let h = Ordered_hash_set_string.create 1 in
      Ordered_hash_set_string.(to_sorted_array h)
      =~ [||];
      Ordered_hash_set_string.add h "1";
      print_endline ("\n"^__LOC__ ^ "\n" ^ Ext_util.stats_to_string (Ordered_hash_set_string.stats h));
      Ordered_hash_set_string.(to_sorted_array h)
      =~ [|"1"|];

    end;

    __LOC__ >:: begin fun _ ->
      (* 3 *) let h = Ordered_hash_set_string.create 1 in
      let count = 3000 in
      for i = 0 to count - 1 do
        (* 9000 *) Ordered_hash_set_string.add  h (string_of_int i) ;
      done ;
      print_endline ("\n"^__LOC__ ^ "\n" ^ Ext_util.stats_to_string (Ordered_hash_set_string.stats h));
      Ordered_hash_set_string.(to_sorted_array h)
      =~ (Array.init count (fun i -> (* 9000 *) string_of_int i ))
    end;

    __LOC__ >:: begin fun _ ->
      (* 3 *) let h = Ordered_hash_set_string.create 1 in
      let count = 1000_000 in
      for i = 0 to count - 1 do
        (* 3000000 *) Ordered_hash_set_string.add  h (string_of_int i) ;
      done ;
      for i = 0 to count - 1 do
        (* 3000000 *) OUnit.assert_bool "exists" (Ordered_hash_set_string.mem h (string_of_int i))
      done;
      for i = 0 to count - 1 do 
        (* 3000000 *) OUnit.assert_equal (Ordered_hash_set_string.rank h (string_of_int i)) i 
      done;  
      OUnit.assert_equal 
        (Ordered_hash_set_string.fold(fun key rank acc -> (* 3000000 *) assert (string_of_int rank = key); (acc + 1) ) h 0)
        count
      ;         
      Ordered_hash_set_string.iter (fun key rank -> (* 3000000 *) assert (string_of_int rank = key))  h ; 
      OUnit.assert_equal (Ordered_hash_set_string.length h) count;
      print_endline ("\n"^__LOC__ ^ "\n" ^ Ext_util.stats_to_string (Ordered_hash_set_string.stats h));
      Ordered_hash_set_string.clear h ; 
      OUnit.assert_equal (Ordered_hash_set_string.length h) 0;
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) let count = 1000_000 in
      let h = Ordered_hash_set_string.create ( count) in      
      for i = 0 to count - 1 do
        (* 3000000 *) Ordered_hash_set_string.add  h (string_of_int i) ;
      done ;
      for i = 0 to count - 1 do
        (* 3000000 *) OUnit.assert_bool "exists" (Ordered_hash_set_string.mem h (string_of_int i))
      done;
      for i = 0 to count - 1 do 
        (* 3000000 *) OUnit.assert_equal (Ordered_hash_set_string.rank h (string_of_int i)) i 
      done;  
      OUnit.assert_equal 
        (Ordered_hash_set_string.fold(fun key rank acc -> (* 3000000 *) assert (string_of_int rank = key); (acc + 1) ) h 0)
        count
      ;         
      Ordered_hash_set_string.iter (fun key rank -> (* 3000000 *) assert (string_of_int rank = key))  h ; 
      OUnit.assert_equal (Ordered_hash_set_string.length h) count;
      print_endline ("\n"^__LOC__ ^ "\n" ^ Ext_util.stats_to_string (Ordered_hash_set_string.stats h));
      Ordered_hash_set_string.clear h ; 
      OUnit.assert_equal (Ordered_hash_set_string.length h) 0;
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ordered_hash_set_string.to_sorted_array (Ordered_hash_set_string.of_array [||]) =~ [||];
      Ordered_hash_set_string.to_sorted_array (Ordered_hash_set_string.of_array [|"1"|]) =~ [|"1"|]
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_raises Not_found (fun _ -> (* 3 *) Ordered_hash_set_string.choose_exn (Ordered_hash_set_string.of_array [||]))
    end;


    __LOC__ >:: begin fun _ ->
      (* 3 *) let count = 1000 in 
      let v = Ordered_hash_set_string.of_array (Array.init count (fun i -> (* 3000 *) string_of_int i) ) in
      for i = 0 to count - 1 do 
        (* 3000 *) Ordered_hash_set_string.replace v (string_of_int i) (string_of_int i ^ Ext_string.single_colon)
      done ;
      OUnit.assert_equal (Ordered_hash_set_string.length v) count;
      OUnit.assert_equal 
        (Ordered_hash_set_string.to_sorted_array v )
        (Array.init count (fun i -> (* 3000 *) string_of_int i ^ Ext_string.single_colon))
      
    end
  ]

end
module Ext_pervasives : sig 
#1 "ext_pervasives.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








(** Extension to standard library [Pervavives] module, safe to open 
  *)

external reraise: exn -> 'a = "%reraise"

val finally : 'a -> ('a -> 'c) -> ('a -> 'b) -> 'b

val with_file_as_chan : string -> (out_channel -> 'a) -> 'a

val with_file_as_pp : string -> (Format.formatter -> 'a) -> 'a

val is_pos_pow : Int32.t -> int

val failwithf : loc:string -> ('a, unit, string, 'b) format4 -> 'a

val invalid_argf : ('a, unit, string, 'b) format4 -> 'a

val bad_argf : ('a, unit, string, 'b) format4 -> 'a



val dump : 'a -> string 
val pp_any : Format.formatter -> 'a -> unit 
external id : 'a -> 'a = "%identity"

(** Copied from {!Btype.hash_variant}:
    need sync up and add test case
 *)
val hash_variant : string -> int

end = struct
#1 "ext_pervasives.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)






external reraise: exn -> 'a = "%reraise"

let finally v action f   = 
  (* 0 *) match f v with
  | exception e -> 
      (* 0 *) action v ;
      reraise e 
  | e ->  (* 0 *) action v ; e 

let with_file_as_chan filename f = 
  (* 0 *) finally (open_out_bin filename) close_out f 

let with_file_as_pp filename f = 
  (* 0 *) finally (open_out_bin filename) close_out
    (fun chan -> 
      (* 0 *) let fmt = Format.formatter_of_out_channel chan in
      let v = f  fmt in
      Format.pp_print_flush fmt ();
      v
    ) 


let  is_pos_pow n = 
  (* 0 *) let module M = struct exception E end in 
  let rec aux c (n : Int32.t) = 
    (* 0 *) if n <= 0l then (* 0 *) -2 
    else (* 0 *) if n = 1l then (* 0 *) c 
    else (* 0 *) if Int32.logand n 1l =  0l then   
      (* 0 *) aux (c + 1) (Int32.shift_right n 1 )
    else (* 0 *) raise M.E in 
  try aux 0 n  with M.E -> (* 0 *) -1

let failwithf ~loc fmt = (* 0 *) Format.ksprintf (fun s -> (* 0 *) failwith (loc ^ s))
    fmt
    
let invalid_argf fmt = (* 0 *) Format.ksprintf invalid_arg fmt

let bad_argf fmt = (* 0 *) Format.ksprintf (fun x -> (* 0 *) raise (Arg.Bad x ) ) fmt


let rec dump r =
  (* 0 *) if Obj.is_int r then
    (* 0 *) string_of_int (Obj.magic r : int)
  else (* Block. *)
    (* 0 *) let rec get_fields acc = function
      | 0 -> (* 0 *) acc
      | n -> (* 0 *) let n = n-1 in get_fields (Obj.field r n :: acc) n
    in
    let rec is_list r =
      (* 0 *) if Obj.is_int r then
        (* 0 *) r = Obj.repr 0 (* [] *)
      else
        (* 0 *) let s = Obj.size r and t = Obj.tag r in
        t = 0 && s = 2 && is_list (Obj.field r 1) (* h :: t *)
    in
    let rec get_list r =
      (* 0 *) if Obj.is_int r then
        (* 0 *) []
      else
        (* 0 *) let h = Obj.field r 0 and t = get_list (Obj.field r 1) in
        h :: t
    in
    let opaque name =
      (* XXX In future, print the address of value 'r'.  Not possible
       * in pure OCaml at the moment.  *)
      (* 0 *) "<" ^ name ^ ">"
    in
    let s = Obj.size r and t = Obj.tag r in
    (* From the tag, determine the type of block. *)
    match t with
    | _ when (* 0 *) is_list r ->
      (* 0 *) let fields = get_list r in
      "[" ^ String.concat "; " (List.map dump fields) ^ "]"
    | 0 ->
      (* 0 *) let fields = get_fields [] s in
      "(" ^ String.concat ", " (List.map dump fields) ^ ")"
    | x when (* 0 *) x = Obj.lazy_tag ->
      (* Note that [lazy_tag .. forward_tag] are < no_scan_tag.  Not
         * clear if very large constructed values could have the same
         * tag. XXX *)
      (* 0 *) opaque "lazy"
    | x when (* 0 *) x = Obj.closure_tag ->
      (* 0 *) opaque "closure"
    | x when (* 0 *) x = Obj.object_tag ->
      (* 0 *) let fields = get_fields [] s in
      let _clasz, id, slots =
        match fields with
        | h::h'::t -> (* 0 *) h, h', t
        | _ -> (* 0 *) assert false
      in
      (* No information on decoding the class (first field).  So just print
         * out the ID and the slots. *)
      "Object #" ^ dump id ^ " (" ^ String.concat ", " (List.map dump slots) ^ ")"
    | x when (* 0 *) x = Obj.infix_tag ->
      (* 0 *) opaque "infix"
    | x when (* 0 *) x = Obj.forward_tag ->
      (* 0 *) opaque "forward"
    | x when (* 0 *) x < Obj.no_scan_tag ->
      (* 0 *) let fields = get_fields [] s in
      "Tag" ^ string_of_int t ^
      " (" ^ String.concat ", " (List.map dump fields) ^ ")"
    | x when (* 0 *) x = Obj.string_tag ->
      (* 0 *) "\"" ^ String.escaped (Obj.magic r : string) ^ "\""
    | x when (* 0 *) x = Obj.double_tag ->
      (* 0 *) string_of_float (Obj.magic r : float)
    | x when (* 0 *) x = Obj.abstract_tag ->
      (* 0 *) opaque "abstract"
    | x when (* 0 *) x = Obj.custom_tag ->
      (* 0 *) opaque "custom"
    | x when (* 0 *) x = Obj.custom_tag ->
      (* 0 *) opaque "final"
    | x when (* 0 *) x = Obj.double_array_tag ->
      (* 0 *) "[|"^
      String.concat ";"
        (Array.to_list (Array.map string_of_float (Obj.magic r : float array))) ^
      "|]"
    | _ ->
      (* 0 *) opaque (Printf.sprintf "unknown: tag %d size %d" t s)

let dump v = (* 0 *) dump (Obj.repr v)

let pp_any fmt v = 
  (* 0 *) Format.fprintf fmt "@[%s@]"
  (dump v )
external id : 'a -> 'a = "%identity"


let hash_variant s =
  (* 0 *) let accu = ref 0 in
  for i = 0 to String.length s - 1 do
    (* 0 *) accu := 223 * !accu + Char.code s.[i]
  done;
  (* reduce to 31 bits *)
  accu := !accu land (1 lsl 31 - 1);
  (* make it signed for 64 bits architectures *)
  if !accu > 0x3FFFFFFF then (* 0 *) !accu - (1 lsl 31) else (* 0 *) !accu


end
module Ext_filename : sig 
#1 "ext_filename.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)





(* TODO:
   Change the module name, this code is not really an extension of the standard 
    library but rather specific to JS Module name convention. 
*)

type t = 
  [ `File of string 
  | `Dir of string ]

val combine : string -> string -> string 
val path_as_directory : string -> string

(** An extension module to calculate relative path follow node/npm style. 
    TODO : this short name will have to change upon renaming the file.
 *)

(** Js_output is node style, which means 
    separator is only '/'

    if the path contains 'node_modules', 
    [node_relative_path] will discard its prefix and 
    just treat it as a library instead
 *)

val node_relative_path : bool -> t -> [`File of string] -> string

val chop_extension : ?loc:string -> string -> string






val cwd : string Lazy.t

(* It is lazy so that it will not hit errors when in script mode *)
val package_dir : string Lazy.t



val module_name_of_file : string -> string

val chop_extension_if_any : string -> string

val absolute_path : string -> string

val module_name_of_file_if_any : string -> string

(**
   1. add some simplifications when concatenating
   2. when the second one is absolute, drop the first one
*)
val combine : string -> string -> string

val normalize_absolute_path : string -> string

(** 
TODO: could be highly optimized
if [from] and [to] resolve to the same path, a zero-length string is returned 
Given that two paths are directory

A typical use case is 
{[
Filename.concat 
  (rel_normalized_absolute_path cwd (Filename.dirname a))
  (Filename.basename a)
]}
*)
val rel_normalized_absolute_path : string -> string -> string 



(**
{[
get_extension "a.txt" = ".txt"
get_extension "a" = ""
]}
*)
val get_extension : string -> string

val simple_convert_node_path_to_os_path : string -> string
end = struct
#1 "ext_filename.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)








(** Used when produce node compatible paths *)
let node_sep = "/"
let node_parent = ".."
let node_current = "."

type t = 
  [ `File of string 
  | `Dir of string ]

let cwd = lazy (Sys.getcwd ())

let (//) = Filename.concat 

let combine path1 path2 =
  (* 0 *) if path1 = "" then
    (* 0 *) path2
  else (* 0 *) if path2 = "" then (* 0 *) path1
  else 
  (* 0 *) if Filename.is_relative path2 then
    (* 0 *) path1// path2 
  else
    (* 0 *) path2

(* Note that [.//] is the same as [./] *)
let path_as_directory x =
  (* 0 *) if x = "" then (* 0 *) x
  else
  (* 0 *) if Ext_string.ends_with x  Filename.dir_sep then
    (* 0 *) x 
  else 
    (* 0 *) x ^ Filename.dir_sep

let absolute_path s = 
  (* 0 *) let process s = 
    (* 0 *) let s = 
      if Filename.is_relative s then
        (* 0 *) Lazy.force cwd // s 
      else (* 0 *) s in
    (* Now simplify . and .. components *)
    let rec aux s =
      (* 0 *) let base,dir  = Filename.basename s, Filename.dirname s  in
      if dir = s then (* 0 *) dir
      else (* 0 *) if base = Filename.current_dir_name then (* 0 *) aux dir
      else (* 0 *) if base = Filename.parent_dir_name then (* 0 *) Filename.dirname (aux dir)
      else (* 0 *) aux dir // base
    in aux s  in 
  process s 


let chop_extension ?(loc="") name =
  (* 0 *) try Filename.chop_extension name 
  with Invalid_argument _ -> 
    (* 0 *) Ext_pervasives.invalid_argf 
      "Filename.chop_extension ( %s : %s )"  loc name

let chop_extension_if_any fname =
  (* 0 *) try Filename.chop_extension fname with Invalid_argument _ -> (* 0 *) fname





let os_path_separator_char = String.unsafe_get Filename.dir_sep 0 


(** example
    {[
      "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/external/pervasives.cmj"
        "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/ocaml_array.ml"
    ]}

    The other way
    {[

      "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/ocaml_array.ml"
        "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib/external/pervasives.cmj"
    ]}
    {[
      "/bb/mbigc/mbig2899/bgit/bucklescript/jscomp/stdlib//ocaml_array.ml"
    ]}
    {[
      /a/b
      /c/d
    ]}
*)
let relative_path file_or_dir_1 file_or_dir_2 = 
  (* 0 *) let sep_char = os_path_separator_char in
  let relevant_dir1 = 
    (match file_or_dir_1 with 
     | `Dir x -> (* 0 *) x 
     | `File file1 ->  (* 0 *) Filename.dirname file1) in
  let relevant_dir2 = 
    (match file_or_dir_2 with 
     |`Dir x -> (* 0 *) x 
     |`File file2 -> (* 0 *) Filename.dirname file2 ) in
  let dir1 = Ext_string.split relevant_dir1 sep_char   in
  let dir2 = Ext_string.split relevant_dir2 sep_char  in
  let rec go (dir1 : string list) (dir2 : string list) = 
    (* 0 *) match dir1, dir2 with 
    | x::xs , y :: ys when (* 0 *) x = y
      -> (* 0 *) go xs ys 
    | _, _
      -> 
      (* 0 *) List.map (fun _ -> (* 0 *) node_parent) dir2 @ dir1 
  in
  match go dir1 dir2 with
  | (x :: _ ) as ys when (* 0 *) x = node_parent -> 
    (* 0 *) String.concat node_sep ys
  | ys -> 
    (* 0 *) String.concat node_sep  @@ node_current :: ys


(** path2: a/b 
    path1: a 
    result:  ./b 
    TODO: [Filename.concat] with care

    [file1] is currently compilation file 
    [file2] is the dependency
    
    TODO: this is a hackish function: FIXME
*)
let node_relative_path node_modules_shorten (file1 : t) 
    (`File file2 as dep_file : [`File of string]) = 
  (* 0 *) let v = Ext_string.find  file2 ~sub:Literals.node_modules in 
  let len = String.length file2 in 
  if node_modules_shorten && v >= 0 then
    
    (* 0 *) let rec skip  i =       
      (* 0 *) if i >= len then
        (* 0 *) Ext_pervasives.failwithf ~loc:__LOC__ "invalid path: %s"  file2
      else 
        (* https://en.wikipedia.org/wiki/Path_(computing))
           most path separator are a single char 
        *)
        (* 0 *) let curr_char = String.unsafe_get file2 i  in 
        if curr_char = os_path_separator_char || curr_char = '.' then 
          (* 0 *) skip (i + 1) 
        else (* 0 *) i
        (*
          TODO: we need do more than this suppose user 
          input can be
           {[
             "xxxghsoghos/ghsoghso/node_modules/../buckle-stdlib/list.js"
           ]}
           This seems weird though
        *)
    in 
    Ext_string.tail_from file2
      (skip (v + Literals.node_modules_length)) 
  else 
    (* 0 *) relative_path 
      (  match dep_file with 
         | `File x -> (* 0 *) `File (absolute_path x)
         | `Dir x -> (* 0 *) `Dir (absolute_path x))

      (match file1 with 
       | `File x -> (* 0 *) `File (absolute_path x)
       | `Dir x -> (* 0 *) `Dir(absolute_path x))
    ^ node_sep ^
    (* chop_extension_if_any *) (Filename.basename file2)



(* Input must be absolute directory *)
let rec find_root_filename ~cwd filename   = 
  (* 0 *) if Sys.file_exists (cwd // filename) then (* 0 *) cwd
  else 
    (* 0 *) let cwd' = Filename.dirname cwd in 
    if String.length cwd' < String.length cwd then  
      (* 0 *) find_root_filename ~cwd:cwd'  filename 
    else 
      (* 0 *) Ext_pervasives.failwithf 
        ~loc:__LOC__
        "%s not found from %s" filename cwd


let find_package_json_dir cwd  = 
  (* 0 *) find_root_filename ~cwd  Literals.bsconfig_json

let package_dir = lazy (find_package_json_dir (Lazy.force cwd))



let module_name_of_file file =
  (* 0 *) String.capitalize 
    (Filename.chop_extension @@ Filename.basename file)  

let module_name_of_file_if_any file = 
  (* 0 *) String.capitalize 
    (chop_extension_if_any @@ Filename.basename file)  


(** For win32 or case insensitve OS 
    [".cmj"] is the same as [".CMJ"]
*)
(* let has_exact_suffix_then_chop fname suf =  *)

let combine p1 p2 = 
  (* 0 *) if p1 = "" || p1 = Filename.current_dir_name then (* 0 *) p2 else 
  (* 0 *) if p2 = "" || p2 = Filename.current_dir_name then (* 0 *) p1 
  else 
  (* 0 *) if Filename.is_relative p2 then 
    (* 0 *) Filename.concat p1 p2 
  else (* 0 *) p2 



(**
   {[
     split_aux "//ghosg//ghsogh/";;
     - : string * string list = ("/", ["ghosg"; "ghsogh"])
   ]}
   Note that 
   {[
     Filename.dirname "/a/" = "/"
       Filename.dirname "/a/b/" = Filename.dirname "/a/b" = "/a"
   ]}
   Special case:
   {[
     basename "//" = "/"
       basename "///"  = "/"
   ]}
   {[
     basename "" =  "."
       basename "" = "."
       dirname "" = "."
       dirname "" =  "."
   ]}  
*)
let split_aux p =
  (* 198 *) let rec go p acc =
    (* 900 *) let dir = Filename.dirname p in
    if dir = p then (* 198 *) dir, acc
    else
      (* 702 *) let new_path = Filename.basename p in 
      if Ext_string.equal new_path Filename.dir_sep then 
        (* 9 *) go dir acc 
        (* We could do more path simplification here
           leave to [rel_normalized_absolute_path]
        *)
      else 
        (* 693 *) go dir (new_path :: acc)

  in go p []



(** 
   TODO: optimization
   if [from] and [to] resolve to the same path, a zero-length string is returned 
*)
let rel_normalized_absolute_path from to_ =
  (* 81 *) let root1, paths1 = split_aux from in 
  let root2, paths2 = split_aux to_ in 
  if root1 <> root2 then (* 0 *) root2
  else
    (* 81 *) let rec go xss yss =
      (* 225 *) match xss, yss with 
      | x::xs, y::ys -> 
        (* 147 *) if Ext_string.equal x  y then (* 144 *) go xs ys 
        else 
          (* 3 *) let start = 
            List.fold_left (fun acc _ -> (* 9 *) acc // Ext_string.parent_dir_lit )
              Ext_string.parent_dir_lit  xs in 
          List.fold_left (fun acc v -> (* 6 *) acc // v) start yss
      | [], [] -> (* 0 *) Ext_string.empty
      | [], y::ys -> (* 24 *) List.fold_left (fun acc x -> (* 24 *) acc // x) y ys
      | x::xs, [] ->
        (* 54 *) List.fold_left (fun acc _ -> (* 90 *) acc // Ext_string.parent_dir_lit )
          Ext_string.parent_dir_lit xs in
    go paths1 paths2

(*TODO: could be hgighly optimized later 
  {[
    normalize_absolute_path "/gsho/./..";;

    normalize_absolute_path "/a/b/../c../d/e/f";;

    normalize_absolute_path "/gsho/./..";;

    normalize_absolute_path "/gsho/./../..";;

    normalize_absolute_path "/a/b/c/d";;

    normalize_absolute_path "/a/b/c/d/";;

    normalize_absolute_path "/a/";;

    normalize_absolute_path "/a";;
  ]}
*)
(** See tests in {!Ounit_path_tests} *)
let normalize_absolute_path x =
  (* 36 *) let drop_if_exist xs =
    (* 33 *) match xs with 
    | [] -> (* 3 *) []
    | _ :: xs -> (* 30 *) xs in 
  let rec normalize_list acc paths =
    (* 231 *) match paths with 
    | [] -> (* 36 *) acc 
    | x :: xs -> 
      (* 195 *) if Ext_string.equal x Ext_string.current_dir_lit then 
        (* 48 *) normalize_list acc xs 
      else (* 147 *) if Ext_string.equal x Ext_string.parent_dir_lit then 
        (* 33 *) normalize_list (drop_if_exist acc ) xs 
      else   
        (* 114 *) normalize_list (x::acc) xs 
  in
  let root, paths = split_aux x in
  let rev_paths =  normalize_list [] paths in 
  let rec go acc rev_paths =
    (* 84 *) match rev_paths with 
    | [] -> (* 30 *) Filename.concat root acc 
    | last::rest ->  (* 54 *) go (Filename.concat last acc ) rest  in 
  match rev_paths with 
  | [] -> (* 6 *) root 
  | last :: rest -> (* 30 *) go last rest 


let get_extension x =
  (* 0 *) let pos = Ext_string.rindex_neg x '.' in 
  if pos < 0 then (* 0 *) ""
  else (* 0 *) Ext_string.tail_from x pos 


let simple_convert_node_path_to_os_path =
  if Sys.unix then (* 3 *) fun x -> (* 0 *) x 
  else (* 0 *) if Sys.win32 || Sys.cygwin then 
    (* 0 *) Ext_string.replace_slash_backward 
  else (* 0 *) failwith ("Unknown OS : " ^ Sys.os_type)

end
module Ounit_path_tests
= struct
#1 "ounit_path_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))


let normalize = Ext_filename.normalize_absolute_path
let (=~) x y = 
  (* 87 *) OUnit.assert_equal ~cmp:(fun x y ->   (* 87 *) Ext_string.equal x y ) x y

let suites = 
  __FILE__ 
  >:::
  [
    "linux path tests" >:: begin fun _ -> 
      (* 3 *) let norm = 
        Array.map normalize
          [|
            "/gsho/./..";
            "/a/b/../c../d/e/f";
            "/a/b/../c/../d/e/f";
            "/gsho/./../..";
            "/a/b/c/d";
            "/a/b/c/d/";
            "/a/";
            "/a";
            "/a.txt/";
            "/a.txt"
          |] in 
      OUnit.assert_equal norm 
        [|
          "/";
          "/a/c../d/e/f";
          "/a/d/e/f";
          "/";
          "/a/b/c/d" ;
          "/a/b/c/d";
          "/a";
          "/a";
          "/a.txt";
          "/a.txt"
        |]
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) normalize "/./a/.////////j/k//../////..///././b/./c/d/./." =~ "/a/b/c/d"
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) normalize "/./a/.////////j/k//../////..///././b/./c/d/././../" =~ "/a/b/c"
    end;

    __LOC__ >:: begin fun _ -> 
    (* 3 *) let aux a b result = 
        
         (* 18 *) Ext_filename.rel_normalized_absolute_path
        a b =~ result ; 
        
        Ext_filename.rel_normalized_absolute_path
        (String.sub a 0 (String.length a - 1)) 
        b  =~ result ;
        
        Ext_filename.rel_normalized_absolute_path
        a
        (String.sub b 0 (String.length b - 1))  =~ result
        ;
        

        Ext_filename.rel_normalized_absolute_path
        (String.sub a 0 (String.length a - 1 ))
        (String.sub b 0 (String.length b - 1))
        =~ result  
       in   
      aux
        "/a/b/c/"
        "/a/b/c/d/"  "d";
      aux
        "/a/b/c/"
        "/a/b/c/d/e/f/" "d/e/f" ;
      aux
        "/a/b/c/d/"
        "/a/b/c/"  ".."  ;
      aux
        "/a/b/c/d/"
        "/a/b/"  "../.."  ;  
      aux
        "/a/b/c/d/"
        "/a/"  "../../.."  ;  
       aux
        "/a/b/c/d/"
        "//"  "../../../.."  ;  
     
     
    end;
    (* This is still correct just not optimal depends 
      on user's perspective *)
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_filename.rel_normalized_absolute_path 
        "/a/b/c/d"
        "/x/y" =~ "../../../../x/y"  

    end;
    
    __LOC__ >:: begin fun _ -> 
    (* 3 *) Ext_filename.rel_normalized_absolute_path
    "/usr/local/lib/node_modules/"
    "//" =~ "../../../..";
    Ext_filename.rel_normalized_absolute_path
    "/usr/local/lib/node_modules/"
    "/" =~ "../../../.."
    end;
    
  ]

end
module Resize_array : sig 
#1 "resize_array.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

module Make ( Resize : Vec_gen.ResizeType) : Vec_gen.S with type elt = Resize.t 



end = struct
#1 "resize_array.ml"
# 1 "ext/vec.cppo.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)
# 25
external unsafe_blit : 
    'a array -> int -> 'a array -> int -> int -> unit = "caml_array_blit"
module Make ( Resize :  Vec_gen.ResizeType) = struct
  type elt = Resize.t 

  let null = Resize.null 
  

# 41
external unsafe_sub : 'a array -> int -> int -> 'a array = "caml_array_sub"

type  t = {
  mutable arr : elt array ;
  mutable len : int ;  
}

let length d = (* 27 *) d.len

let compact d =
  (* 0 *) let d_arr = d.arr in 
  if d.len <> Array.length d_arr then 
    (* 0 *) begin
      let newarr = unsafe_sub d_arr 0 d.len in 
      d.arr <- newarr
    end
let singleton v = 
  (* 0 *) {
    len = 1 ; 
    arr = [|v|]
  }

let empty () =
  (* 33 *) {
    len = 0;
    arr = [||];
  }

let is_empty d =
  (* 0 *) d.len = 0

let reset d = 
  (* 0 *) d.len <- 0; 
  d.arr <- [||]


(* For [to_*] operations, we should be careful to call {!Array.*} function 
   in case we operate on the whole array
*)
let to_list d =
  (* 0 *) let rec loop (d_arr : elt array) idx accum =
    (* 0 *) if idx < 0 then (* 0 *) accum else (* 0 *) loop d_arr (idx - 1) (Array.unsafe_get d_arr idx :: accum)
  in
  loop d.arr (d.len - 1) []


let of_list lst =
  (* 0 *) let arr = Array.of_list lst in 
  { arr ; len = Array.length arr}


let to_array d = 
  (* 0 *) unsafe_sub d.arr 0 d.len

let of_array src =
  (* 0 *) {
    len = Array.length src;
    arr = Array.copy src;
    (* okay to call {!Array.copy}*)
  }
let of_sub_array arr off len = 
  (* 0 *) { 
    len = len ; 
    arr = Array.sub arr off len  
  }  
let unsafe_internal_array v = (* 0 *) v.arr  
(* we can not call {!Array.copy} *)
let copy src =
  (* 0 *) let len = src.len in
  {
    len ;
    arr = unsafe_sub src.arr 0 len ;
  }

(* FIXME *)
let reverse_in_place src = 
  (* 0 *) Ext_array.reverse_range src.arr 0 src.len 




(* {!Array.sub} is not enough for error checking, it 
   may contain some garbage
 *)
let sub (src : t) start len =
  (* 0 *) let src_len = src.len in 
  if len < 0 || start > src_len - len then (* 0 *) invalid_arg "Vec.sub"
  else 
  (* 0 *) { len ; 
    arr = unsafe_sub src.arr start len }

let iter f d = 
  (* 36 *) let arr = d.arr in 
  for i = 0 to d.len - 1 do
    (* 72 *) f (Array.unsafe_get arr i)
  done

let iteri f d =
  (* 0 *) let arr = d.arr in
  for i = 0 to d.len - 1 do
    (* 0 *) f i (Array.unsafe_get arr i)
  done

let iter_range ~from ~to_ f d =
  (* 0 *) if from < 0 || to_ >= d.len then (* 0 *) invalid_arg "Resize_array.iter_range"
  else 
    (* 0 *) let d_arr = d.arr in 
    for i = from to to_ do 
      (* 0 *) f  (Array.unsafe_get d_arr i)
    done

let iteri_range ~from ~to_ f d =
  (* 0 *) if from < 0 || to_ >= d.len then (* 0 *) invalid_arg "Resize_array.iteri_range"
  else 
    (* 0 *) let d_arr = d.arr in 
    for i = from to to_ do 
      (* 0 *) f i (Array.unsafe_get d_arr i)
    done

let map_into_array f src =
  (* 6 *) let src_len = src.len in 
  let src_arr = src.arr in 
  if src_len = 0 then (* 0 *) [||]
  else 
    (* 6 *) let first_one = f (Array.unsafe_get src_arr 0) in 
    let arr = Array.make  src_len  first_one in
    for i = 1 to src_len - 1 do
      (* 18 *) Array.unsafe_set arr i (f (Array.unsafe_get src_arr i))
    done;
    arr 
let map_into_list f src = 
  (* 0 *) let src_len = src.len in 
  let src_arr = src.arr in 
  if src_len = 0 then (* 0 *) []
  else 
    (* 0 *) let acc = ref [] in         
    for i =  src_len - 1 downto 0 do
      (* 0 *) acc := f (Array.unsafe_get src_arr i) :: !acc
    done;
    !acc

let mapi f src =
  (* 0 *) let len = src.len in 
  if len = 0 then (* 0 *) { len ; arr = [| |] }
  else 
    (* 0 *) let src_arr = src.arr in 
    let arr = Array.make len (Array.unsafe_get src_arr 0) in
    for i = 1 to len - 1 do
      (* 0 *) Array.unsafe_set arr i (f i (Array.unsafe_get src_arr i))
    done;
    {
      len ;
      arr ;
    }

let fold_left f x a =
  (* 27 *) let rec loop a_len (a_arr : elt array) idx x =
    (* 138 *) if idx >= a_len then (* 27 *) x else 
      (* 111 *) loop a_len a_arr (idx + 1) (f x (Array.unsafe_get a_arr idx))
  in
  loop a.len a.arr 0 x

let fold_right f a x =
  (* 0 *) let rec loop (a_arr : elt array) idx x =
    (* 0 *) if idx < 0 then (* 0 *) x
    else (* 0 *) loop a_arr (idx - 1) (f (Array.unsafe_get a_arr idx) x)
  in
  loop a.arr (a.len - 1) x

(**  
   [filter] and [inplace_filter]
*)
let filter f d =
  (* 0 *) let new_d = copy d in 
  let new_d_arr = new_d.arr in 
  let d_arr = d.arr in
  let p = ref 0 in
  for i = 0 to d.len  - 1 do
    (* 0 *) let x = Array.unsafe_get d_arr i in
    (* TODO: can be optimized for segments blit *)
    if f x  then
      (* 0 *) begin
        Array.unsafe_set new_d_arr !p x;
        incr p;
      end;
  done;
  new_d.len <- !p;
  new_d 

let equal eq x y : bool = 
  (* 0 *) if x.len <> y.len then (* 0 *) false 
  else 
    (* 0 *) let rec aux x_arr y_arr i =
      (* 0 *) if i < 0 then (* 0 *) true else  
      (* 0 *) if eq (Array.unsafe_get x_arr i) (Array.unsafe_get y_arr i) then 
        (* 0 *) aux x_arr y_arr (i - 1)
      else (* 0 *) false in 
    aux x.arr y.arr (x.len - 1)

let get d i = 
  (* 0 *) if i < 0 || i >= d.len then (* 0 *) invalid_arg "Resize_array.get"
  else (* 0 *) Array.unsafe_get d.arr i
let unsafe_get d i = (* 0 *) Array.unsafe_get d.arr i 
let last d = 
  (* 0 *) if d.len <= 0 then (* 0 *) invalid_arg   "Resize_array.last"
  else (* 0 *) Array.unsafe_get d.arr (d.len - 1)

let capacity d = (* 0 *) Array.length d.arr

(* Attention can not use {!Array.exists} since the bound is not the same *)  
let exists p d = 
  (* 0 *) let a = d.arr in 
  let n = d.len in   
  let rec loop i =
    (* 0 *) if i = n then (* 0 *) false
    else (* 0 *) if p (Array.unsafe_get a i) then (* 0 *) true
    else (* 0 *) loop (succ i) in
  loop 0

let map f src =
  (* 0 *) let src_len = src.len in 
  if src_len = 0 then (* 0 *) { len = 0 ; arr = [||]}
  (* TODO: we may share the empty array 
     but sharing mutable state is very challenging, 
     the tricky part is to avoid mutating the immutable array,
     here it looks fine -- 
     invariant: whenever [.arr] mutated, make sure  it is not an empty array
     Actually no: since starting from an empty array 
     {[
       push v (* the address of v should not be changed *)
     ]}
  *)
  else 
    (* 0 *) let src_arr = src.arr in 
    let first = f (Array.unsafe_get src_arr 0 ) in 
    let arr = Array.make  src_len first in
    for i = 1 to src_len - 1 do
      (* 0 *) Array.unsafe_set arr i (f (Array.unsafe_get src_arr i))
    done;
    {
      len = src_len;
      arr = arr;
    }

let init len f =
  (* 3 *) if len < 0 then (* 0 *) invalid_arg  "Resize_array.init"
  else (* 3 *) if len = 0 then (* 0 *) { len = 0 ; arr = [||] }
  else 
    (* 3 *) let first = f 0 in 
    let arr = Array.make len first in
    for i = 1 to len - 1 do
      (* 27 *) Array.unsafe_set arr i (f i)
    done;
    {

      len ;
      arr 
    }



  let make initsize : t =
    (* 9 *) if initsize < 0 then (* 0 *) invalid_arg  "Resize_array.make" ;
    {

      len = 0;
      arr = Array.make  initsize null ;
    }



  let reserve (d : t ) s = 
    (* 0 *) let d_len = d.len in 
    let d_arr = d.arr in 
    if s < d_len || s < Array.length d_arr then (* 0 *) ()
    else 
      (* 0 *) let new_capacity = min Sys.max_array_length s in 
      let new_d_arr = Array.make new_capacity null in 
       unsafe_blit d_arr 0 new_d_arr 0 d_len;
      d.arr <- new_d_arr 

  let push v (d : t) =
    (* 195 *) let d_len = d.len in
    let d_arr = d.arr in 
    let d_arr_len = Array.length d_arr in
    if d_arr_len = 0 then
      (* 33 *) begin 
        d.len <- 1 ;
        d.arr <- [| v |]
      end
    else  
      (* 162 *) begin 
        if d_len = d_arr_len then 
          (* 72 *) begin
            if d_len >= Sys.max_array_length then 
              (* 0 *) failwith "exceeds max_array_length";
            let new_capacity = min Sys.max_array_length d_len * 2 
            (* [d_len] can not be zero, so [*2] will enlarge   *)
            in
            let new_d_arr = Array.make new_capacity null in 
            d.arr <- new_d_arr;
             unsafe_blit d_arr 0 new_d_arr 0 d_len ;
          end;
        d.len <- d_len + 1;
        Array.unsafe_set d.arr d_len v
      end

(** delete element at offset [idx], will raise exception when have invalid input *)
  let delete (d : t) idx =
    (* 0 *) let d_len = d.len in 
    if idx < 0 || idx >= d_len then (* 0 *) invalid_arg "Resize_array.delete" ;
    let arr = d.arr in 
     unsafe_blit arr (idx + 1) arr idx  (d_len - idx - 1);
    let idx = d_len - 1 in 
    d.len <- idx
    
# 358
    ;
    Array.unsafe_set arr idx  null
    
# 362
(** pop the last element, a specialized version of [delete] *)
  let pop (d : t) = 
    (* 0 *) let idx  = d.len - 1  in
    if idx < 0 then (* 0 *) invalid_arg "Resize_array.pop";
    d.len <- idx
    
# 369
    ;    
    Array.unsafe_set d.arr idx null
  
# 373
(** pop and return the last element *)  
  let get_last_and_pop (d : t) = 
    (* 0 *) let idx  = d.len - 1  in
    if idx < 0 then (* 0 *) invalid_arg "Resize_array.get_last_and_pop";
    let last = Array.unsafe_get d.arr idx in 
    d.len <- idx 
    
# 381
    ;
    Array.unsafe_set d.arr idx null
    
# 384
    ;
    last 

(** delete elements start from [idx] with length [len] *)
  let delete_range (d : t) idx len =
    (* 45 *) let d_len = d.len in 
    if len < 0 || idx < 0 || idx + len > d_len then (* 0 *) invalid_arg  "Resize_array.delete_range"  ;
    let arr = d.arr in 
     unsafe_blit arr (idx + len) arr idx (d_len  - idx - len);
    d.len <- d_len - len
    
# 396
    ;
    for i = d_len - len to d_len - 1 do
      (* 60 *) Array.unsafe_set arr i null
    done

# 402
(** delete elements from [idx] with length [len] return the deleted elements as a new vec*)
  let get_and_delete_range (d : t) idx len : t = 
    (* 0 *) let d_len = d.len in 
    if len < 0 || idx < 0 || idx + len > d_len then (* 0 *) invalid_arg  "Resize_array.get_and_delete_range"  ;
    let arr = d.arr in 
    let value =  unsafe_sub arr idx len in
     unsafe_blit arr (idx + len) arr idx (d_len  - idx - len);
    d.len <- d_len - len; 
    
# 412
    for i = d_len - len to d_len - 1 do
      (* 0 *) Array.unsafe_set arr i null
    done;
    
# 416
    {len = len ; arr = value}


  (** Below are simple wrapper around normal Array operations *)  

  let clear (d : t ) =
    
# 424
    (* 0 *) for i = 0 to d.len - 1 do 
      (* 0 *) Array.unsafe_set d.arr i null
    done;
    
# 428
    d.len <- 0



  let inplace_filter f (d : t) : unit = 
    (* 0 *) let d_arr = d.arr in     
    let d_len = d.len in
    let p = ref 0 in
    for i = 0 to d_len - 1 do 
      (* 0 *) let x = Array.unsafe_get d_arr i in 
      if f x then 
        (* 0 *) begin 
          let curr_p = !p in 
          (if curr_p <> i then 
             (* 0 *) Array.unsafe_set d_arr curr_p x) ;
          incr p
        end
    done ;
    let last = !p  in 
    
# 451
    delete_range d last  (d_len - last)

  
# 454
  let inplace_filter_from start f (d : t) : unit = 
    (* 0 *) if start < 0 then (* 0 *) invalid_arg "Vec.inplace_filter_from"; 
    let d_arr = d.arr in     
    let d_len = d.len in
    let p = ref start in    
    for i = start to d_len - 1 do 
      (* 0 *) let x = Array.unsafe_get d_arr i in 
      if f x then 
        (* 0 *) begin 
          let curr_p = !p in 
          (if curr_p <> i then 
             (* 0 *) Array.unsafe_set d_arr curr_p x) ;
          incr p
        end
    done ;
    let last = !p  in 
    
# 473
    delete_range d last  (d_len - last)


# 477
(** inplace filter the elements and accumulate the non-filtered elements *)
  let inplace_filter_with  f ~cb_no acc (d : t)  = 
    (* 45 *) let d_arr = d.arr in     
    let p = ref 0 in
    let d_len = d.len in
    let acc = ref acc in 
    for i = 0 to d_len - 1 do 
      (* 132 *) let x = Array.unsafe_get d_arr i in 
      if f x then 
        (* 72 *) begin 
          let curr_p = !p in 
          (if curr_p <> i then 
             (* 0 *) Array.unsafe_set d_arr curr_p x) ;
          incr p
        end
      else 
        (* 60 *) acc := cb_no  x  !acc
    done ;
    let last = !p  in 
    
# 500
    delete_range d last  (d_len - last)
    
# 502
    ; !acc 



# 507
end

end
module Int_vec_vec : sig 
#1 "int_vec_vec.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

include Vec_gen.S with type elt = Int_vec.t

end = struct
#1 "int_vec_vec.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


include Resize_array.Make(struct type t = Int_vec.t let null = Int_vec.empty () end)

end
module Ext_scc : sig 
#1 "ext_scc.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)
 



type node = Int_vec.t
(** Assume input is int array with offset from 0 
    Typical input 
    {[
      [|
        [ 1 ; 2 ]; // 0 -> 1,  0 -> 2 
        [ 1 ];   // 0 -> 1 
        [ 2 ]  // 0 -> 2 
      |]
    ]}
    Note that we can tell how many nodes by calculating 
    [Array.length] of the input 
*)
val graph : Int_vec.t array -> Int_vec_vec.t


(** Used for unit test *)
val graph_check : node array -> int * int list 

end = struct
#1 "ext_scc.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)
 
type node = Int_vec.t 
(** 
   [int] as data for this algorithm
   Pros:
   1. Easy to eoncode algorithm (especially given that the capacity of node is known)
   2. Algorithms itself are much more efficient
   3. Node comparison semantics is clear
   4. Easy to print output
   Cons:
   1. post processing input data  
 *)
let min_int (x : int) y = (* 492 *) if x < y then (* 135 *) x else (* 357 *) y  


let graph  e =
  (* 33 *) let index = ref 0 in 
  let s = Int_vec.empty () in

  let output = Int_vec_vec.empty () in (* collect output *)
  let node_numes = Array.length e in
  
  let on_stack_array = Array.make node_numes false in
  let index_array = Array.make node_numes (-1) in 
  let lowlink_array = Array.make node_numes (-1) in
  
  let rec scc v_data  =
    (* 318 *) let new_index = !index + 1 in 
    index := new_index ;
    Int_vec.push  v_data s ; 

    index_array.(v_data) <- new_index ;  
    lowlink_array.(v_data) <- new_index ; 
    on_stack_array.(v_data) <- true ;
    
    let v = e.(v_data) in 
    v
    |> Int_vec.iter (fun w_data  ->
        (* 645 *) if Array.unsafe_get index_array w_data < 0 then (* not processed *)
          (* 261 *) begin  
            scc w_data;
            Array.unsafe_set lowlink_array v_data  
              (min_int (Array.unsafe_get lowlink_array v_data) (Array.unsafe_get lowlink_array w_data))
          end  
        else (* 384 *) if Array.unsafe_get on_stack_array w_data then 
          (* successor is in stack and hence in current scc *)
          (* 231 *) begin 
            Array.unsafe_set lowlink_array v_data  
              (min_int (Array.unsafe_get lowlink_array v_data) (Array.unsafe_get lowlink_array w_data))
          end
      ) ; 

    if Array.unsafe_get lowlink_array v_data = Array.unsafe_get index_array v_data then
      (* start a new scc *)
      (* 135 *) begin
        let s_len = Int_vec.length s in
        let last_index = ref (s_len - 1) in 
        let u = ref (Int_vec.unsafe_get s !last_index) in
        while  !u <> v_data do 
          (* 183 *) Array.unsafe_set on_stack_array (!u)  false ; 
          last_index := !last_index - 1;
          u := Int_vec.unsafe_get s !last_index
        done ;
        on_stack_array.(v_data) <- false; (* necessary *)
        Int_vec_vec.push   (Int_vec.get_and_delete_range s !last_index (s_len  - !last_index)) output;
      end   
  in
  for i = 0 to node_numes - 1 do 
    (* 318 *) if Array.unsafe_get index_array i < 0 then (* 57 *) scc i
  done ;
  output 

let graph_check v = 
  (* 27 *) let v = graph v in 
  Int_vec_vec.length v, 
  Int_vec_vec.fold_left (fun acc x -> (* 111 *) Int_vec.length x :: acc ) [] v  

end
module Ounit_scc_tests
= struct
#1 "ounit_scc_tests.ml"
let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal

let tiny_test_cases = {|
13
22
 4  2
 2  3
 3  2
 6  0
 0  1
 2  0
11 12
12  9
 9 10
 9 11
 7  9
10 12
11  4
 4  3
 3  5
 6  8
 8  6
 5  4
 0  5
 6  4
 6  9
 7  6
|}     

let medium_test_cases = {|
50
147
 0  7
 0 34
 1 14
 1 45
 1 21
 1 22
 1 22
 1 49
 2 19
 2 25
 2 33
 3  4
 3 17
 3 27
 3 36
 3 42
 4 17
 4 17
 4 27
 5 43
 6 13
 6 13
 6 28
 6 28
 7 41
 7 44
 8 19
 8 48
 9  9
 9 11
 9 30
 9 46
10  0
10  7
10 28
10 28
10 28
10 29
10 29
10 34
10 41
11 21
11 30
12  9
12 11
12 21
12 21
12 26
13 22
13 23
13 47
14  8
14 21
14 48
15  8
15 34
15 49
16  9
17 20
17 24
17 38
18  6
18 28
18 32
18 42
19 15
19 40
20  3
20 35
20 38
20 46
22  6
23 11
23 21
23 22
24  4
24  5
24 38
24 43
25  2
25 34
26  9
26 12
26 16
27  5
27 24
27 32
27 31
27 42
28 22
28 29
28 39
28 44
29 22
29 49
30 23
30 37
31 18
31 32
32  5
32  6
32 13
32 37
32 47
33  2
33  8
33 19
34  2 
34 19
34 40
35  9
35 37
35 46
36 20
36 42
37  5
37  9
37 35
37 47
37 47
38 35
38 37
38 38
39 18
39 42
40 15
41 28
41 44
42 31
43 37
43 38
44 39
45  8
45 14
45 14
45 15
45 49
46 16
47 23
47 30
48 12
48 21
48 33
48 33
49 34
49 22
49 49
|}
(* 
reference output: 
http://algs4.cs.princeton.edu/42digraph/KosarajuSharirSCC.java.html 
*)

let handle_lines tiny_test_cases = 
  (* 6 *) match Ext_string.split  tiny_test_cases '\n' with 
  | nodes :: edges :: rest -> 
    (* 6 *) let nodes_num = int_of_string nodes in 
    let node_array = 
      Array.init nodes_num
        (fun i -> (* 189 *) Int_vec.empty () )
    in 
    begin 
      rest |> List.iter (fun x ->
          (* 507 *) match Ext_string.split x ' ' with 
          | [ a ; b] -> 
            (* 507 *) let a , b = int_of_string a , int_of_string b in 
            Int_vec.push  b node_array.(a) 
          | _ -> (* 0 *) assert false 
        );
      node_array 
    end
  | _ -> (* 0 *) assert false

let read_file file = 
  (* 0 *) let in_chan = open_in_bin file in 
  let nodes_sum = int_of_string (input_line in_chan) in 
  let node_array = Array.init nodes_sum (fun i -> (* 0 *) Int_vec.empty () ) in 
  let rec aux () = 
    (* 0 *) match input_line in_chan with 
    | exception End_of_file -> (* 0 *) ()
    | x -> 
      (* 0 *) begin match Ext_string.split x ' ' with 
      | [ a ; b] -> 
        (* 0 *) let a , b = int_of_string a , int_of_string b in 
        Int_vec.push  b node_array.(a) 
      | _ -> (* assert false  *) (* 0 *) ()
      end; 
      aux () in 
  print_endline "read data into memory";
  aux ();
   (fst (Ext_scc.graph_check node_array)) (* 25 *)


let test  (input : (string * string list) list) = 
  (* string -> int mapping 
  *)
  (* 21 *) let tbl = String_hashtbl.create 32 in
  let idx = ref 0 in 
  let add x =
    (* 213 *) if not (String_hashtbl.mem tbl x ) then 
      (* 102 *) begin 
        String_hashtbl.add  tbl x !idx ;
        incr idx 
      end in
  input |> List.iter 
    (fun (x,others) -> (* 102 *) List.iter add (x::others));
  let nodes_num = String_hashtbl.length tbl in
  let node_array = 
      Array.init nodes_num
        (fun i -> (* 102 *) Int_vec.empty () ) in 
  input |> 
  List.iter (fun (x,others) -> 
      (* 102 *) let idx = String_hashtbl.find_exn tbl  x  in 
      others |> 
      List.iter (fun y -> (* 111 *) Int_vec.push (String_hashtbl.find_exn tbl y ) node_array.(idx) )
    ) ; 
  Ext_scc.graph_check node_array 

let test2  (input : (string * string list) list) = 
  (* string -> int mapping 
  *)
  (* 6 *) let tbl = String_hashtbl.create 32 in
  let idx = ref 0 in 
  let add x =
    (* 54 *) if not (String_hashtbl.mem tbl x ) then 
      (* 27 *) begin 
        String_hashtbl.add  tbl x !idx ;
        incr idx 
      end in
  input |> List.iter 
    (fun (x,others) -> (* 27 *) List.iter add (x::others));
  let nodes_num = String_hashtbl.length tbl in
  let other_mapping = Array.make nodes_num "" in 
  String_hashtbl.iter (fun k v  -> (* 27 *) other_mapping.(v) <- k ) tbl ;
  
  let node_array = 
      Array.init nodes_num
        (fun i -> (* 27 *) Int_vec.empty () ) in 
  input |> 
  List.iter (fun (x,others) -> 
      (* 27 *) let idx = String_hashtbl.find_exn tbl  x  in 
      others |> 
      List.iter (fun y -> (* 27 *) Int_vec.push (String_hashtbl.find_exn tbl y ) node_array.(idx) )
    )  ;
  let output = Ext_scc.graph node_array in 
  output |> Int_vec_vec.map_into_array (fun int_vec -> (* 24 *) Int_vec.map_into_array (fun i -> (* 27 *) other_mapping.(i)) int_vec )


let suites = 
    __FILE__
    >::: [
      __LOC__ >:: begin fun _ -> 
        (* 3 *) OUnit.assert_equal (fst @@ Ext_scc.graph_check (handle_lines tiny_test_cases))  5
      end       ;
      __LOC__ >:: begin fun _ -> 
        (* 3 *) OUnit.assert_equal (fst @@ Ext_scc.graph_check (handle_lines medium_test_cases))  10
      end       ;
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test [
            "a", ["b" ; "c"];
            "b" , ["c" ; "d"];
            "c", [ "b"];
            "d", [];
          ]) (3 , [1;2;1])
      end ; 
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test [
            "a", ["b" ; "c"];
            "b" , ["c" ; "d"];
            "c", [ "b"];
            "d", [];
            "e", []
          ])  (4, [1;1;2;1])
          (*  {[
              a -> b
              a -> c 
              b -> c 
              b -> d 
              c -> b 
              d 
              e
              ]}
              {[
              [d ; e ; [b;c] [a] ]
              ]}  
          *)
      end ;
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test [
            "a", ["b" ; "c"];
            "b" , ["c" ; "d"];
            "c", [ "b"];
            "d", ["e"];
            "e", []
          ]) (4 , [1;2;1;1])
      end ; 
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test [
            "a", ["b" ; "c"];
            "b" , ["c" ; "d"];
            "c", [ "b"];
            "d", ["e"];
            "e", ["c"]
          ]) (2, [1;4])
      end ;
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test [
            "a", ["b" ; "c"];
            "b" , ["c" ; "d"];
            "c", [ "b"];
            "d", ["e"];
            "e", ["a"]
          ]) (1, [5])
      end ; 
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test [
            "a", ["b"];
            "b" , ["c" ];
            "c", [ ];
            "d", [];
            "e", []
          ]) (5, [1;1;1;1;1])
      end ; 
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test [
            "1", ["0"];
            "0" , ["2" ];
            "2", ["1" ];
            "0", ["3"];
            "3", [ "4"]
          ]) (3, [3;1;1])
      end ; 
      (* http://algs4.cs.princeton.edu/42digraph/largeDG.txt *)
      (* __LOC__ >:: begin fun _ -> *)
      (*   OUnit.assert_equal (read_file "largeDG.txt") 25 *)
      (* end *)
      (* ; *)
      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test2 [
            "a", ["b" ; "c"];
            "b" , ["c" ; "d"];
            "c", [ "b"];
            "d", [];
          ]) [|[|"d"|]; [|"b"; "c"|]; [|"a"|]|]
      end ;

      __LOC__ >:: begin fun _ ->
        (* 3 *) OUnit.assert_equal (test2 [
            "a", ["b"];
            "b" , ["c" ];
            "c", ["d" ];
            "d", ["e"];
            "e", []
          ]) [|[|"e"|]; [|"d"|]; [|"c"|]; [|"b"|]; [|"a"|]|] 
      end ;

    ]

end
module Ext_sexp : sig 
#1 "ext_sexp.mli"
type t  =  
  | Atom of string 
  | List of t list
  | Data of t list 
  | Lit of string 


val token :  Lexing.lexbuf ->  t list

val from_file : string -> t list 

val from_string : string -> t list 
end = struct
#1 "ext_sexp.ml"
# 1 "ext/ext_sexp.mll"
 

type error =
  | Illegal_character of char
  | Illegal_escape of string
  | Unbalanced_paren 
  | Unterminated_paren
  | Unterminated_string
  | Non_sexp_outside
exception Error of error * Lexing.position * Lexing.position;;

let error  (lexbuf : Lexing.lexbuf) e = 
  (* 3 *) raise (Error (e, lexbuf.lex_start_p, lexbuf.lex_curr_p))


let char_for_backslash = function
  | 'n' -> (* 0 *) '\010'
  | 'r' -> (* 0 *) '\013'
  | 'b' -> (* 0 *) '\008'
  | 't' -> (* 0 *) '\009'
  | c -> (* 0 *) c

let lf = '\010'

let dec_code c1 c2 c3 =
  (* 0 *) 100 * (Char.code c1 - 48) + 10 * (Char.code c2 - 48) + (Char.code c3 - 48)

let hex_code c1 c2 =
  (* 0 *) let d1 = Char.code c1 in
  let val1 =
    if d1 >= 97 then (* 0 *) d1 - 87
    else (* 0 *) if d1 >= 65 then (* 0 *) d1 - 55
    else (* 0 *) d1 - 48 in
  let d2 = Char.code c2 in
  let val2 =
    if d2 >= 97 then (* 0 *) d2 - 87
    else (* 0 *) if d2 >= 65 then (* 0 *) d2 - 55
    else (* 0 *) d2 - 48 in
  val1 * 16 + val2

let update_loc ({ lex_curr_p; _ } as lexbuf : Lexing.lexbuf) diff =
  (* 36 *) lexbuf.lex_curr_p <-
    {
      lex_curr_p with
      pos_lnum = lex_curr_p.pos_lnum + 1;
      pos_bol = lex_curr_p.pos_cnum - diff;
    }

let lexeme_len ({ lex_start_pos; lex_curr_pos; _ } : Lexing.lexbuf) =
  (* 0 *) lex_curr_pos - lex_start_pos



type t  =
  | Atom of string 
  | List of t list
  | Data of t list 
  | Lit of string 



type st = 
  { sexps : (t list * bool) Stack.t ; 
    mutable top : t list   ;
    mutable has_prime : bool ;
    buf : Buffer.t;
    mutable paren_depth : int
  }

let push_atom lexbuf atom (buf : st ) = 
  (* 165 *) buf.top <- atom:: buf.top

(** entering the new stack *)
let new_lparen has_prime buf = 
  (* 54 *) buf.paren_depth <- buf.paren_depth + 1 ;
  Stack.push (buf.top, buf.has_prime) buf.sexps ;
  buf.top <- [];
  buf.has_prime <- has_prime

(** exit the stack *)
let new_rparen  buf lexbuf = 
  (* 51 *) buf.paren_depth <- buf.paren_depth - 1 ; 
  if buf.paren_depth < 0  then
    (* 0 *) error lexbuf Unbalanced_paren
  else 
    (* 51 *) let new_sexp =
      if buf.has_prime then 
        (* 6 *) Data (List.rev   buf.top)
      else (* 45 *) List (List.rev   buf.top) 
    in 
    let top, has_prime =  Stack.pop buf.sexps in
    buf.top<- top;
    buf.has_prime<-has_prime;
    push_atom lexbuf new_sexp buf 

let get_data buf = (* 18 *) buf.top


# 101 "ext/ext_sexp.ml"
let __ocaml_lex_tables = {
  Lexing.lex_base = 
   "\000\000\246\255\247\255\078\000\249\255\250\255\251\255\002\000\
    \001\000\006\000\006\000\255\255\252\255\191\000\246\255\192\000\
    \248\255\195\000\255\255\249\255\012\001\161\000\252\255\007\000\
    \011\000\012\000\210\000\251\255\035\001\250\255";
  Lexing.lex_backtrk = 
   "\255\255\255\255\255\255\007\000\255\255\255\255\255\255\008\000\
    \002\000\001\000\008\000\255\255\255\255\255\255\255\255\008\000\
    \255\255\255\255\255\255\255\255\006\000\006\000\255\255\006\000\
    \001\000\002\000\255\255\255\255\255\255\255\255";
  Lexing.lex_default = 
   "\002\000\000\000\000\000\255\255\000\000\000\000\000\000\255\255\
    \008\000\255\255\255\255\000\000\000\000\015\000\000\000\015\000\
    \000\000\019\000\000\000\000\000\255\255\255\255\000\000\255\255\
    \255\255\255\255\255\255\000\000\255\255\000\000";
  Lexing.lex_trans = 
   "\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\009\000\011\000\255\255\009\000\010\000\255\255\009\000\
    \011\000\025\000\009\000\000\000\024\000\025\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \009\000\000\000\004\000\000\000\000\000\000\000\009\000\007\000\
    \006\000\005\000\012\000\024\000\025\000\003\000\003\000\000\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\000\000\008\000\000\000\003\000\000\000\003\000\
    \000\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\000\000\000\000\000\000\000\000\003\000\
    \000\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\000\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \000\000\000\000\000\000\003\000\000\000\003\000\000\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\000\000\000\000\000\000\000\000\003\000\000\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\016\000\255\255\000\000\000\000\024\000\000\000\000\000\
    \023\000\026\000\026\000\026\000\026\000\026\000\026\000\026\000\
    \026\000\026\000\026\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\018\000\255\255\022\000\000\000\022\000\000\000\000\000\
    \000\000\000\000\022\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\021\000\021\000\021\000\021\000\021\000\
    \021\000\021\000\021\000\021\000\021\000\000\000\000\000\000\000\
    \001\000\255\255\027\000\027\000\027\000\027\000\027\000\027\000\
    \027\000\027\000\027\000\027\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\017\000\255\255\000\000\000\000\022\000\
    \000\000\000\000\000\000\000\000\000\000\022\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\022\000\000\000\000\000\000\000\022\000\000\000\022\000\
    \000\000\000\000\000\000\020\000\028\000\028\000\028\000\028\000\
    \028\000\028\000\028\000\028\000\028\000\028\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\028\000\028\000\028\000\
    \028\000\028\000\028\000\029\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\029\000\029\000\029\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\000\000\000\000\000\000\028\000\028\000\028\000\
    \028\000\028\000\028\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\029\000\029\000\029\000\029\000\
    \029\000\029\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\014\000\
    \255\255\000\000\000\000\255\255\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000";
  Lexing.lex_check = 
   "\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\000\000\000\000\008\000\000\000\000\000\008\000\009\000\
    \010\000\023\000\009\000\255\255\024\000\025\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \000\000\255\255\000\000\255\255\255\255\255\255\009\000\000\000\
    \000\000\000\000\007\000\024\000\025\000\000\000\000\000\255\255\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\255\255\000\000\255\255\000\000\255\255\000\000\
    \255\255\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\255\255\255\255\255\255\255\255\000\000\
    \255\255\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\000\
    \000\000\000\000\000\000\003\000\003\000\255\255\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \255\255\255\255\255\255\003\000\255\255\003\000\255\255\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\255\255\255\255\255\255\255\255\003\000\255\255\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\003\000\003\000\003\000\003\000\003\000\003\000\003\000\
    \003\000\013\000\015\000\255\255\255\255\017\000\255\255\255\255\
    \017\000\021\000\021\000\021\000\021\000\021\000\021\000\021\000\
    \021\000\021\000\021\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\013\000\015\000\017\000\255\255\017\000\255\255\255\255\
    \255\255\255\255\017\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\017\000\017\000\017\000\017\000\017\000\
    \017\000\017\000\017\000\017\000\017\000\255\255\255\255\255\255\
    \000\000\008\000\026\000\026\000\026\000\026\000\026\000\026\000\
    \026\000\026\000\026\000\026\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\013\000\015\000\255\255\255\255\017\000\
    \255\255\255\255\255\255\255\255\255\255\017\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\017\000\255\255\255\255\255\255\017\000\255\255\017\000\
    \255\255\255\255\255\255\017\000\020\000\020\000\020\000\020\000\
    \020\000\020\000\020\000\020\000\020\000\020\000\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\020\000\020\000\020\000\
    \020\000\020\000\020\000\028\000\028\000\028\000\028\000\028\000\
    \028\000\028\000\028\000\028\000\028\000\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\028\000\028\000\028\000\028\000\
    \028\000\028\000\255\255\255\255\255\255\020\000\020\000\020\000\
    \020\000\020\000\020\000\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\028\000\028\000\028\000\028\000\
    \028\000\028\000\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\013\000\
    \015\000\255\255\255\255\017\000\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\255\
    \255\255\255\255\255\255\255\255";
  Lexing.lex_base_code = 
   "";
  Lexing.lex_backtrk_code = 
   "";
  Lexing.lex_default_code = 
   "";
  Lexing.lex_trans_code = 
   "";
  Lexing.lex_check_code = 
   "";
  Lexing.lex_code = 
   "";
}

let rec main buf lexbuf =
    (* 408 *) __ocaml_lex_main_rec buf lexbuf 0
and __ocaml_lex_main_rec buf lexbuf __ocaml_lex_state =
  (* 408 *) match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 111 "ext/ext_sexp.mll"
                     (* 36 *) ( 
    update_loc lexbuf 0;
    main (buf : st ) lexbuf  )
# 281 "ext/ext_sexp.ml"

  | 1 ->
# 114 "ext/ext_sexp.mll"
           (* 132 *) ( main buf lexbuf  )
# 286 "ext/ext_sexp.ml"

  | 2 ->
# 115 "ext/ext_sexp.mll"
                       (* 0 *) (  main buf lexbuf )
# 291 "ext/ext_sexp.ml"

  | 3 ->
# 116 "ext/ext_sexp.mll"
         (* 6 *) (
    new_lparen true buf; 
    main buf lexbuf
  )
# 299 "ext/ext_sexp.ml"

  | 4 ->
# 120 "ext/ext_sexp.mll"
        (* 48 *) ( 
    new_lparen false buf ; 
    main buf lexbuf 
  )
# 307 "ext/ext_sexp.ml"

  | 5 ->
# 124 "ext/ext_sexp.mll"
        (* 51 *) ( 
      new_rparen  buf lexbuf; 
      main buf lexbuf 
  )
# 315 "ext/ext_sexp.ml"

  | 6 ->
# 129 "ext/ext_sexp.mll"
      (* 30 *) (
        let pos = Lexing.lexeme_start_p lexbuf in
        scan_string buf.buf pos lexbuf;
        push_atom lexbuf  ( Lit (Buffer.contents  buf.buf)) buf;
        Buffer.clear buf.buf;
        main buf lexbuf
      )
# 326 "ext/ext_sexp.ml"

  | 7 ->
(* 84 *) let
# 136 "ext/ext_sexp.mll"
                    s
# 332 "ext/ext_sexp.ml"
= Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos lexbuf.Lexing.lex_curr_pos in
# 137 "ext/ext_sexp.mll"
    ( push_atom lexbuf (Atom s) buf ; 
      main buf lexbuf
    )
# 338 "ext/ext_sexp.ml"

  | 8 ->
(* 0 *) let
# 140 "ext/ext_sexp.mll"
         c
# 344 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf lexbuf.Lexing.lex_start_pos in
# 141 "ext/ext_sexp.mll"
      (  error  lexbuf (Illegal_character c))
# 348 "ext/ext_sexp.ml"

  | 9 ->
# 143 "ext/ext_sexp.mll"
        (* 21 *) (
    if buf.paren_depth > 0 then 
      (* 3 *) error lexbuf Unterminated_paren
    else 
      (* 18 *) get_data buf )
# 357 "ext/ext_sexp.ml"

  | __ocaml_lex_state -> (* 0 *) lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_main_rec buf lexbuf __ocaml_lex_state

and scan_string buf start lexbuf =
    (* 60 *) __ocaml_lex_scan_string_rec buf start lexbuf 13
and __ocaml_lex_scan_string_rec buf start lexbuf __ocaml_lex_state =
  (* 60 *) match Lexing.engine __ocaml_lex_tables __ocaml_lex_state lexbuf with
      | 0 ->
# 150 "ext/ext_sexp.mll"
        (* 30 *) ( () )
# 369 "ext/ext_sexp.ml"

  | 1 ->
# 152 "ext/ext_sexp.mll"
      (* 0 *) (
        let len = lexeme_len lexbuf - 2 in
        update_loc lexbuf len;

        scan_string buf start lexbuf
      )
# 379 "ext/ext_sexp.ml"

  | 2 ->
# 159 "ext/ext_sexp.mll"
      (* 0 *) (
        let len = lexeme_len lexbuf - 3 in
        update_loc lexbuf len;
        scan_string buf start lexbuf
      )
# 388 "ext/ext_sexp.ml"

  | 3 ->
(* 0 *) let
# 164 "ext/ext_sexp.mll"
                                                 c
# 394 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 1) in
# 165 "ext/ext_sexp.mll"
      (
        Buffer.add_char buf (char_for_backslash c);
        scan_string buf start lexbuf
      )
# 401 "ext/ext_sexp.ml"

  | 4 ->
(* 0 *) let
# 169 "ext/ext_sexp.mll"
                   c1
# 407 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 1)
and
# 169 "ext/ext_sexp.mll"
                                 c2
# 412 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 2)
and
# 169 "ext/ext_sexp.mll"
                                               c3
# 417 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 3)
and
# 169 "ext/ext_sexp.mll"
                                                      s
# 422 "ext/ext_sexp.ml"
= Lexing.sub_lexeme lexbuf lexbuf.Lexing.lex_start_pos (lexbuf.Lexing.lex_start_pos + 4) in
# 170 "ext/ext_sexp.mll"
      (
        let v = dec_code c1 c2 c3 in
        if v > 255 then
          (* 0 *) error lexbuf (Illegal_escape s) ;
        Buffer.add_char buf (Char.chr v);

        scan_string buf start lexbuf
      )
# 433 "ext/ext_sexp.ml"

  | 5 ->
(* 0 *) let
# 178 "ext/ext_sexp.mll"
                          c1
# 439 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 2)
and
# 178 "ext/ext_sexp.mll"
                                           c2
# 444 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 3) in
# 179 "ext/ext_sexp.mll"
      (
        let v = hex_code c1 c2 in
        Buffer.add_char buf (Char.chr v);

        scan_string buf start lexbuf
      )
# 453 "ext/ext_sexp.ml"

  | 6 ->
(* 0 *) let
# 185 "ext/ext_sexp.mll"
               c
# 459 "ext/ext_sexp.ml"
= Lexing.sub_lexeme_char lexbuf (lexbuf.Lexing.lex_start_pos + 1) in
# 186 "ext/ext_sexp.mll"
      (
        Buffer.add_char buf '\\';
        Buffer.add_char buf c;

        scan_string buf start lexbuf
      )
# 468 "ext/ext_sexp.ml"

  | 7 ->
# 193 "ext/ext_sexp.mll"
      (* 0 *) (
        update_loc lexbuf 0;
        Buffer.add_char buf lf;

        scan_string buf start lexbuf
      )
# 478 "ext/ext_sexp.ml"

  | 8 ->
# 200 "ext/ext_sexp.mll"
      (* 30 *) (
        let ofs = lexbuf.lex_start_pos in
        let len = lexbuf.lex_curr_pos - ofs in
        Buffer.add_substring buf lexbuf.lex_buffer ofs len;

        scan_string buf start lexbuf
      )
# 489 "ext/ext_sexp.ml"

  | 9 ->
# 208 "ext/ext_sexp.mll"
      (* 0 *) (
        error lexbuf Unterminated_string
      )
# 496 "ext/ext_sexp.ml"

  | __ocaml_lex_state -> (* 0 *) lexbuf.Lexing.refill_buff lexbuf; 
      __ocaml_lex_scan_string_rec buf start lexbuf __ocaml_lex_state

;;

# 212 "ext/ext_sexp.mll"
  

    let token  lexbuf  =
      (* 21 *) List.rev @@ main { 
        buf = Buffer.create 256 ;
        sexps = Stack.create () ; 
        paren_depth = 0; 
        top = [];
        has_prime = false } lexbuf
    let from_string str = 
      (* 21 *) token (Lexing.from_string str)    
    let from_file file = 
      (* 0 *) let in_channel =  open_in file in 
      match  token (Lexing.from_channel in_channel) with 
      | exception  e -> (* 0 *) close_in in_channel; raise e 
      | sexps -> (* 0 *) close_in in_channel ; sexps

# 521 "ext/ext_sexp.ml"

end
module Ounit_sexp_tests
= struct
#1 "ounit_sexp_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal

let suites = 
    __FILE__
    >::: [
        __LOC__ >:: begin fun _ -> 
             (* 3 *) Ext_sexp.from_string "( a)" =~ 
             [ List [ Atom "a"]]
        end;
        __LOC__ >:: begin fun _ -> 
             (* 3 *) Ext_sexp.from_string "( a ())" =~ 
             [ List [ Atom "a"; List []]]
        end;
        __LOC__ >:: begin fun _ -> 
             (* 3 *) Ext_sexp.from_string "( a (b))" =~ 
             [ List [ Atom "a"; List [Atom "b"]]]
        end;
        __LOC__ >:: begin fun _ -> 
             (* 3 *) Ext_sexp.from_string "( a (b)) (c d)" =~ 
             [ List [ Atom "a"; List [Atom "b"]];
                List [ Atom "c"; Atom "d"]
             ]
        end;
        __LOC__ >:: begin fun _ -> 
             (* 3 *) Ext_sexp.from_string "( a (b 1 2 3)  c  d) (c d)" =~ 
             [ List [ Atom "a"; List [Atom "b"; Atom "1"; Atom "2"; Atom "3"] ; Atom "c"; Atom "d"];
                List [ Atom "c"; Atom "d"]
             ];
        end;
        __LOC__ ^ "raise" >:: begin fun _ -> 
            (* 3 *) (try ignore @@ Ext_sexp.from_string  {|  (1 2 3  ( a (b) ) |}; false
            with e -> (* 3 *) true) =~ true ;

            match Ext_sexp.from_string {|
(setq 
 bsc 
 "../bin/bsc.exe"
 bs-external-includes
 '( "../runtime" "../stdlib"  "./others")
 bs-package-name
 "bs-platform")

(setq 
 bsc-flags '("-w" "-40" "-bs-no-version-header " "-bs-diagnose" "-bs-cross-module-opt"))

|}       with 
        | _ -> (* 3 *) ()
        | exception _ -> (* 0 *) OUnit.assert_failure __LOC__
        end;
    ]
end
module Ounit_data_random
= struct
#1 "ounit_data_random.ml"


let min_int x y = 
    (* 18006 *) if x < y then (* 0 *) x else (* 18006 *) y

let random_string chars upper = 
    (* 18006 *) let len = Array.length chars in 
    let string_len = (Random.int (min_int upper len)) in
    String.init string_len (fun i -> (* 26646 *) chars.(Random.int len ))
end
module Ounit_string_tests
= struct
#1 "ounit_string_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal    




let suites = 
  __FILE__ >::: 
  [
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_bool "not found " (Ext_string.rindex_neg "hello" 'x' < 0 )
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.rindex_neg "hello" 'h' =~ 0 ;
      Ext_string.rindex_neg "hello" 'e' =~ 1 ;
      Ext_string.rindex_neg "hello" 'l' =~ 3 ;
      Ext_string.rindex_neg "hello" 'l' =~ 3 ;
      Ext_string.rindex_neg "hello" 'o' =~ 4 ;
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool "empty string" (Ext_string.rindex_neg "" 'x' < 0 )
    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__
        (Ext_string.for_all_range "xABc"~start:1
           ~finish:2 (function 'A' .. 'Z' -> (* 6 *) true | _ -> (* 0 *) false));
      OUnit.assert_bool __LOC__
        (not (Ext_string.for_all_range "xABc"~start:1
                ~finish:3(function 'A' .. 'Z' -> (* 6 *) true | _ -> (* 3 *) false)));
      OUnit.assert_bool __LOC__
        ( (Ext_string.for_all_range "xABc"~start:1
             ~finish:2 (function 'A' .. 'Z' -> (* 6 *) true | _ -> (* 0 *) false)));
      OUnit.assert_bool __LOC__
        ( (Ext_string.for_all_range "xABc"~start:1
             ~finish:1 (function 'A' .. 'Z' -> (* 3 *) true | _ -> (* 0 *) false)));
      OUnit.assert_bool __LOC__
        ( (Ext_string.for_all_range "xABc"~start:1
             ~finish:0 (function 'A' .. 'Z' -> (* 0 *) true | _ -> (* 0 *) false)));    
      OUnit.assert_raise_any       
        (fun _ ->  (* 3 *) (Ext_string.for_all_range "xABc"~start:1
                      ~finish:4 (function 'A' .. 'Z' -> (* 0 *) true | _ -> (* 0 *) false)));    

    end;

    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ @@
      List.for_all (fun x -> (* 30 *) Ext_string.is_valid_source_name x = Good)
        ["x.ml"; "x.mli"; "x.re"; "x.rei"; "x.mll"; 
         "A_x.ml"; "ab.ml"; "a_.ml"; "a__.ml";
         "ax.ml"];
      OUnit.assert_bool __LOC__ @@ not @@
      List.exists (fun x -> (* 51 *) Ext_string.is_valid_source_name x = Good)
        [".re"; ".rei";"..re"; "..rei"; "..ml"; ".mll~"; 
         "...ml"; "_.mli"; "_x.ml"; "__.ml"; "__.rei"; 
         ".#hello.ml"; ".#hello.rei"; "a-.ml"; "a-b.ml"; "-a-.ml"
        ; "-.ml"
        ]
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.find ~sub:"hello" "xx hello xx" =~ 3 ;
      Ext_string.rfind ~sub:"hello" "xx hello xx" =~ 3 ;
      Ext_string.find ~sub:"hello" "xx hello hello xx" =~ 3 ;
      Ext_string.rfind ~sub:"hello" "xx hello hello xx" =~ 9 ;
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.non_overlap_count ~sub:"0" "1000,000" =~ 6;
      Ext_string.non_overlap_count ~sub:"0" "000000" =~ 6;
      Ext_string.non_overlap_count ~sub:"00" "000000" =~ 3;
      Ext_string.non_overlap_count ~sub:"00" "00000" =~ 2
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ (Ext_string.contain_substring "abc" "abc");
      OUnit.assert_bool __LOC__ (Ext_string.contain_substring "abc" "a");
      OUnit.assert_bool __LOC__ (Ext_string.contain_substring "abc" "b");
      OUnit.assert_bool __LOC__ (Ext_string.contain_substring "abc" "c");
      OUnit.assert_bool __LOC__ (Ext_string.contain_substring "abc" "");
      OUnit.assert_bool __LOC__ (not @@ Ext_string.contain_substring "abc" "abcc");
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.trim " \t\n" =~ "";
      Ext_string.trim " \t\nb" =~ "b";
      Ext_string.trim "b \t\n" =~ "b";
      Ext_string.trim "\t\n b \t\n" =~ "b";            
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.starts_with "ab" "a" =~ true;
      Ext_string.starts_with "ab" "" =~ true;
      Ext_string.starts_with "abb" "abb" =~ true;
      Ext_string.starts_with "abb" "abbc" =~ false;
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.ends_with_then_chop "xx.ml"  ".ml" =~ Some "xx";
      Ext_string.ends_with_then_chop "xx.ml" ".mll" =~ None
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.starts_with_and_number "js_fn_mk_01" ~offset:0 "js_fn_mk_" =~ 1 ;
      Ext_string.starts_with_and_number "js_fn_run_02" ~offset:0 "js_fn_mk_" =~ -1 ;
      Ext_string.starts_with_and_number "js_fn_mk_03" ~offset:6 "mk_" =~ 3 ;
      Ext_string.starts_with_and_number "js_fn_mk_04" ~offset:6 "run_" =~ -1;
      Ext_string.starts_with_and_number "js_fn_run_04" ~offset:6 "run_" =~ 4;
      Ext_string.(starts_with_and_number "js_fn_run_04" ~offset:6 "run_" = 3) =~ false 
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.for_all (function '_' -> (* 12 *) true | _ -> (* 0 *) false)
        "____" =~ true;
      Ext_string.for_all (function '_' -> (* 9 *) true | _ -> (* 3 *) false)
        "___-" =~ false;
      Ext_string.for_all (function '_' -> (* 0 *) true | _ -> (* 0 *) false)        
        "" =~ true
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.tail_from "ghsogh" 1 =~ "hsogh";
      Ext_string.tail_from "ghsogh" 0 =~ "ghsogh"
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) Ext_string.digits_of_str "11_js" ~offset:0 2 =~ 11 
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ 
        (Ext_string.replace_backward_slash "a:\\b\\d" = 
         "a:/b/d"
        ) ;
      OUnit.assert_bool __LOC__ 
        (Ext_string.replace_backward_slash "a:\\b\\d\\" = 
         "a:/b/d/"
        ) ;
      OUnit.assert_bool __LOC__ 
        (Ext_string.replace_slash_backward "a:/b/d/"= 
         "a:\\b\\d\\" 
        ) ;  
      OUnit.assert_bool __LOC__ 
        (let old = "a:bd" in 
         Ext_string.replace_backward_slash old == 
         old
        ) ;
      OUnit.assert_bool __LOC__ 
        (let old = "a:bd" in 
         Ext_string.replace_backward_slash old == 
         old
        ) ;

    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ 
        (Ext_string.no_slash "ahgoh" );
      OUnit.assert_bool __LOC__ 
        (Ext_string.no_slash "" );            
      OUnit.assert_bool __LOC__ 
        (not (Ext_string.no_slash "ahgoh/" ));
      OUnit.assert_bool __LOC__ 
        (not (Ext_string.no_slash "/ahgoh" ));
      OUnit.assert_bool __LOC__ 
        (not (Ext_string.no_slash "/ahgoh/" ));            
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ (Ext_string.compare "" ""  = 0);
      OUnit.assert_bool __LOC__ (Ext_string.compare "0" "0"  = 0);
      OUnit.assert_bool __LOC__ (Ext_string.compare "" "acd" < 0);
      OUnit.assert_bool __LOC__ (Ext_string.compare  "acd" "" > 0);
      for i = 0 to 256 do 
        (* 771 *) let a = String.init i (fun _ -> (* 98688 *) '0') in 
        let b = String.init i (fun _ -> (* 98688 *) '0') in 
        OUnit.assert_bool __LOC__ (Ext_string.compare  b a = 0);
        OUnit.assert_bool __LOC__ (Ext_string.compare a b = 0)
      done ;
      for i = 0 to 256 do 
        (* 771 *) let a = String.init i (fun _ -> (* 98688 *) '0') in 
        let b = String.init i (fun _ -> (* 98688 *) '0') ^ "\000"in 
        OUnit.assert_bool __LOC__ (Ext_string.compare a b < 0);
        OUnit.assert_bool __LOC__ (Ext_string.compare  b a  > 0)
      done ;

    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let slow_compare x y  = 
        (* 9003 *) let x_len = String.length x  in 
        let y_len = String.length y in 
        if x_len = y_len then 
          (* 2319 *) String.compare x y 
        else 
          (* 6684 *) Pervasives.compare x_len y_len  in 
      let same_sign x y =
        (* 9003 *) if x = 0 then (* 780 *) y = 0 
        else (* 8223 *) if x < 0 then (* 4242 *) y < 0 
        else (* 3981 *) y > 0 in 
      for i = 0 to 3000 do
        (* 9003 *) let chars = [|'a';'b';'c';'d'|] in 
        let x = Ounit_data_random.random_string chars 129 in 
        let y = Ounit_data_random.random_string chars 129 in 
        let a = Ext_string.compare  x y  in 
        let b = slow_compare x y in 
        if same_sign a b then (* 9003 *) OUnit.assert_bool __LOC__ true 
        else (* 0 *) failwith ("incosistent " ^ x ^ " " ^ y ^ " " ^ string_of_int a ^ " " ^ string_of_int b)
      done 
    end ;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ 
        (Ext_string.equal
           (Ext_string.concat3 "a0" "a1" "a2") "a0a1a2"
        );
      OUnit.assert_bool __LOC__ 
        (Ext_string.equal
           (Ext_string.concat3 "a0" "a11" "") "a0a11"
        );
 
      OUnit.assert_bool __LOC__ 
        (Ext_string.equal
           (Ext_string.concat4 "a0" "a1" "a2" "a3") "a0a1a2a3"
        );
     OUnit.assert_bool __LOC__ 
        (Ext_string.equal
           (Ext_string.concat4 "a0" "a11" "" "a33") "a0a11a33"
        );   
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ 
        (Ext_string.equal
           (Ext_string.inter2 "a0" "a1") "a0 a1"
        );
      OUnit.assert_bool __LOC__ 
        (Ext_string.equal
           (Ext_string.inter3 "a0" "a1" "a2") "a0 a1 a2"
        );
      OUnit.assert_bool __LOC__ 
        (Ext_string.equal
           (Ext_string.inter4 "a0" "a1" "a2" "a3") "a0 a1 a2 a3"
        );
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__ 
        (Ext_string.no_slash_idx "xxx" < 0);
      OUnit.assert_bool __LOC__ 
        (Ext_string.no_slash_idx "xxx/" = 3);
      OUnit.assert_bool __LOC__ 
        (Ext_string.no_slash_idx "xxx/g/" = 3);
      OUnit.assert_bool __LOC__ 
        (Ext_string.no_slash_idx "/xxx/g/" = 0)
    end;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [||])
           Ext_string.empty
        );
      OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [|"a0"|])
           "a0"
        );
      OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [|"a0";"a1"|])
           "a0 a1"
        );   
      OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [|"a0";"a1"; "a2"|])
           "a0 a1 a2"
        );   
       OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [|"a0";"a1"; "a2";"a3"|])
           "a0 a1 a2 a3"
        );    
      OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [|"a0";"a1"; "a2";"a3";""; "a4"|])
           "a0 a1 a2 a3  a4"
        );      
      OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [|"0";"a1"; "2";"a3";""; "a4"|])
           "0 a1 2 a3  a4"
        );        
      OUnit.assert_bool __LOC__
        (Ext_string.equal 
           (Ext_string.concat_array Ext_string.single_space [|"0";"a1"; "2";"3";"d"; ""; "e"|])
           "0 a1 2 3 d  e"
        );        
  
    end
  ]

end
module Ext_topsort : sig 
#1 "ext_topsort.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


type edges = { id : int ; deps : Int_vec.t }

module Edge_vec : Vec_gen.S with type elt = edges 

type t = Edge_vec.t 

(** the input will be modified ,
*)
val layered_dfs : t -> Set_int.t Queue.t
end = struct
#1 "ext_topsort.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

type edges = { id : int ; deps : Int_vec.t }

module Edge_vec = Resize_array.Make( struct 
    type t = edges
    let null = { id = 0 ; deps = Int_vec.empty ()}
    end
    )

type t = Edge_vec.t 


(** 
    This graph is different the graph used in [scc] graph, since 
    we need dynamic shrink the graph, so for each vector the first node is it self ,
    it will also change the input.
    
    TODO: error handling (cycle handling) and defensive bad input (missing edges etc)
*)

let layered_dfs (g : t) =
   (* 9 *) let queue = Queue.create () in 
   let rec aux g = 
        (* 45 *) let new_entries = 
        Edge_vec.inplace_filter_with 
        (fun (x : edges) -> (* 132 *) not (Int_vec.is_empty x.deps) ) 
        ~cb_no:(fun x acc -> (* 60 *) Set_int.add x.id acc) Set_int.empty  g in 
        if not (Set_int.is_empty new_entries) 
        then 
        (* 36 *) begin 
            Queue.push new_entries queue ; 
            Edge_vec.iter 
            (fun edges -> (* 72 *) Int_vec.inplace_filter  
                (fun x -> (* 150 *) not (Set_int.mem x new_entries)) edges.deps ) g ;
            aux g 
        end
  in aux  g ; queue      

  
end
module Ounit_topsort_tests
= struct
#1 "ounit_topsort_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let handle graph = 
  (* 9 *) let len = List.length graph in 
  let result = Ext_topsort.Edge_vec.make len in 
  List.iter (fun (id,deps) -> 
      (* 60 *) Ext_topsort.Edge_vec.push {id ; deps = Int_vec.of_list deps } result 
    ) graph; 
  result 


let graph1 = 
  [ 
    0, [1;2];
    1, [2;3];
    2, [4];
    3, [];
    4, []
  ], [[0]; [1]; [2] ; [3;4]]


let graph2 = 
  [ 
    0, [1;2];
    1, [2;3];
    2, [4];
    3, [5];
    4, [5];
    5, []
  ],  
  [[0]; [1]; [2] ; [3;4]; [5]]

let graph3 = 
    [ 0,[1;2;3;4;5];
      1, [6;7;8] ;
      2, [6;7;8];
      3, [6;7;8];
      4, [6;7;8];
      5, [6;7;8];
      6, [];
      7, [] ;
      8, []
     ],
     [[0]; [1;2;3;4;5]; [6; 7; 8]]


let expect loc (graph1, v) = 
  (* 9 *) let graph = handle graph1  in 
  let queue = Ext_topsort.layered_dfs graph  in 
  OUnit.assert_bool loc
    (Queue.fold (fun acc x -> (* 36 *) Set_int.elements x::acc) [] queue =
     v)





let (=~) = OUnit.assert_equal
let suites = 
  __FILE__
  >:::
  [
    __LOC__ >:: begin fun _ -> 
      (* 3 *) expect __LOC__ graph1;
      expect __LOC__ graph2 ;
      expect __LOC__ graph3
    end

  ]
end
module Union_find : sig 
#1 "union_find.mli"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


 type t 

val init : int -> t 

  
 
val find : t -> int -> int

val union : t -> int -> int -> unit 

val count : t -> int

end = struct
#1 "union_find.ml"
(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

type t = {
  id : int array;
  sz : int array ;
  mutable components : int  
} 

let init n = 
  (* 6 *) let id = Array.make n 0 in 
  for i = 0 to  n - 1 do
    (* 1905 *) Array.unsafe_set id i i  
  done  ;
  {
    id ; 
    sz = Array.make n 1;
    components = n
  }

let rec find_aux id_store p = 
  (* 11058 *) let parent = Array.unsafe_get id_store p in 
  if p <> parent then 
    (* 5592 *) find_aux id_store parent 
  else (* 5466 *) p       

let find store p = (* 0 *) find_aux store.id p 

let union store p q =
  (* 2733 *) let id_store = store.id in 
  let p_root = find_aux id_store p in 
  let q_root = find_aux id_store q in 
  if p_root <> q_root then 
    (* 1890 *) begin
      let () = store.components <- store.components - 1 in
      let sz_store = store.sz in
      let sz_p_root = Array.unsafe_get sz_store p_root in 
      let sz_q_root = Array.unsafe_get sz_store q_root in  
      let bigger = sz_p_root + sz_q_root in
      (* Smaller root point to larger to make 
         it more balanced
         it will introduce a cost for small root find,
         but major will not be impacted 
      *) 
      if  sz_p_root < sz_q_root  then
        (* 606 *) begin
          Array.unsafe_set id_store p q_root;   
          Array.unsafe_set id_store p_root q_root;
          Array.unsafe_set sz_store q_root bigger;            
          (* little optimization *) 
        end 
      else   
        (* 1284 *) begin
          Array.unsafe_set id_store q  p_root ;
          Array.unsafe_set id_store q_root p_root;   
          Array.unsafe_set sz_store p_root bigger;          
          (* little optimization *)
        end
    end 

let count store = (* 6 *) store.components    


end
module Ounit_union_find_tests
= struct
#1 "ounit_union_find_tests.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal
let tinyUF = {|10
               4 3
               3 8
               6 5
               9 4
               2 1
               8 9
               5 0
               7 2
               6 1
               1 0
               6 7
             |}
let mediumUF = {|625
                 528 503
                 548 523
                 389 414
                 446 421
                 552 553
                 154 155
                 173 174
                 373 348
                 567 542
                 44 43
                 370 345
                 546 547
                 204 229
                 404 429
                 240 215
                 364 389
                 612 611
                 513 512
                 377 376
                 468 443
                 410 435
                 243 218
                 347 322
                 580 581
                 188 163
                 61 36
                 545 546
                 93 68
                 84 83
                 94 69
                 7 8
                 619 618
                 314 339
                 155 156
                 150 175
                 605 580
                 118 93
                 385 360
                 459 458
                 167 168
                 107 108
                 44 69
                 335 334
                 251 276
                 196 197
                 501 502
                 212 187
                 251 250
                 269 270
                 332 331
                 125 150
                 391 416
                 366 367
                 65 40
                 515 540
                 248 273
                 34 9
                 480 479
                 198 173
                 463 488
                 111 86
                 524 499
                 28 27
                 323 324
                 198 199
                 146 147
                 133 158
                 416 415
                 103 102
                 457 482
                 57 82
                 88 113
                 535 560
                 181 180
                 605 606
                 481 456
                 127 102
                 470 445
                 229 254
                 169 170
                 386 385
                 383 384
                 153 152
                 541 542
                 36 37
                 474 473
                 126 125
                 534 509
                 154 129
                 591 592
                 161 186
                 209 234
                 88 87
                 61 60
                 161 136
                 472 447
                 239 240
                 102 101
                 342 343
                 566 565
                 567 568
                 41 42
                 154 153
                 471 496
                 358 383
                 423 448
                 241 242
                 292 293
                 363 364
                 361 362
                 258 283
                 75 100
                 61 86
                 81 106
                 52 27
                 230 255
                 309 334
                 378 379
                 136 111
                 439 464
                 532 533
                 166 191
                 523 522
                 210 211
                 115 140
                 347 346
                 218 217
                 561 560
                 526 501
                 174 149
                 258 259
                 77 52
                 36 11
                 307 306
                 577 552
                 62 61
                 450 425
                 569 570
                 268 293
                 79 78
                 233 208
                 571 570
                 534 535
                 527 552
                 224 199
                 409 408
                 521 520
                 621 622
                 493 518
                 107 106
                 511 510
                 298 299
                 37 62
                 224 249
                 405 380
                 236 237
                 120 121
                 393 418
                 206 231
                 287 288
                 593 568
                 34 59
                 483 484
                 226 227
                 73 74
                 276 277
                 588 587
                 288 313
                 410 385
                 506 505
                 597 598
                 337 312
                 55 56
                 300 325
                 135 134
                 4 29
                 501 500
                 438 437
                 311 312
                 598 599
                 320 345
                 211 236
                 587 562
                 74 99
                 473 498
                 278 279
                 394 369
                 123 148
                 233 232
                 252 277
                 177 202
                 160 185
                 331 356
                 192 191
                 119 118
                 576 601
                 317 316
                 462 487
                 42 43
                 336 311
                 515 490
                 13 14
                 210 235
                 473 448
                 342 341
                 340 315
                 413 388
                 514 515
                 144 143
                 146 145
                 541 566
                 128 103
                 184 159
                 488 489
                 454 455
                 82 83
                 70 45
                 221 222
                 241 240
                 412 411
                 591 590
                 592 593
                 276 301
                 452 453
                 256 255
                 397 372
                 201 200
                 232 207
                 466 465
                 561 586
                 417 442
                 409 434
                 238 239
                 389 390
                 26 1
                 510 485
                 283 282
                 281 306
                 449 474
                 324 349
                 121 146
                 111 112
                 434 435
                 507 508
                 103 104
                 319 294
                 455 480
                 558 557
                 291 292
                 553 578
                 392 391
                 552 551
                 55 80
                 538 539
                 367 392
                 340 365
                 272 297
                 266 265
                 401 376
                 279 280
                 516 515
                 178 177
                 572 571
                 154 179
                 263 262
                 6 31
                 323 348
                 481 506
                 178 179
                 526 527
                 444 469
                 273 274
                 132 133
                 275 300
                 261 236
                 344 369
                 63 38
                 5 30
                 301 300
                 86 87
                 9 10
                 344 319
                 428 427
                 400 375
                 350 375
                 235 236
                 337 336
                 616 615
                 381 380
                 58 59
                 492 493
                 555 556
                 459 434
                 368 369
                 407 382
                 166 141
                 70 95
                 380 355
                 34 35
                 49 24
                 126 127
                 403 378
                 509 484
                 613 588
                 208 207
                 143 168
                 406 431
                 263 238
                 595 596
                 218 193
                 183 182
                 195 220
                 381 406
                 64 65
                 371 372
                 531 506
                 218 219
                 144 145
                 475 450
                 547 548
                 363 362
                 337 362
                 214 239
                 110 111
                 600 575
                 105 106
                 147 148
                 599 574
                 622 623
                 319 320
                 36 35
                 258 233
                 266 267
                 481 480
                 414 439
                 169 168
                 479 478
                 224 223
                 181 182
                 351 326
                 466 441
                 85 60
                 140 165
                 91 90
                 263 264
                 188 187
                 446 447
                 607 606
                 341 316
                 143 142
                 443 442
                 354 353
                 162 137
                 281 256
                 549 574
                 407 408
                 575 550
                 171 170
                 389 388
                 390 391
                 250 225
                 536 537
                 227 228
                 84 59
                 139 140
                 485 484
                 573 598
                 356 381
                 314 315
                 299 324
                 370 395
                 166 165
                 63 62
                 507 506
                 426 425
                 479 454
                 545 570
                 376 375
                 572 597
                 606 581
                 278 277
                 303 302
                 190 165
                 230 205
                 175 200
                 529 528
                 18 17
                 458 457
                 514 513
                 617 616
                 298 323
                 162 161
                 471 472
                 81 56
                 182 207
                 539 564
                 573 572
                 596 621
                 64 39
                 571 546
                 554 555
                 388 363
                 351 376
                 304 329
                 123 122
                 135 160
                 157 132
                 599 624
                 451 426
                 162 187
                 502 477
                 508 483
                 141 140
                 303 328
                 551 576
                 471 446
                 161 160
                 465 490
                 3 2
                 138 113
                 309 284
                 452 451
                 414 413
                 540 565
                 210 185
                 350 325
                 383 382
                 2 1
                 598 623
                 97 72
                 485 460
                 315 316
                 19 20
                 31 32
                 546 521
                 320 321
                 29 54
                 330 331
                 92 67
                 480 505
                 274 249
                 22 47
                 304 279
                 493 468
                 424 423
                 39 40
                 164 165
                 269 268
                 445 446
                 228 203
                 384 409
                 390 365
                 283 308
                 374 399
                 361 386
                 94 119
                 237 262
                 43 68
                 295 270
                 400 425
                 360 335
                 122 121
                 469 468
                 189 188
                 377 352
                 367 342
                 67 42
                 616 591
                 442 467
                 558 533
                 395 394
                 3 28
                 476 477
                 257 258
                 280 281
                 517 542
                 505 504
                 302 301
                 14 15
                 523 498
                 393 368
                 46 71
                 141 142
                 477 452
                 535 510
                 237 238
                 232 231
                 5 6
                 75 50
                 278 253
                 68 69
                 584 559
                 503 504
                 281 282
                 19 44
                 411 410
                 290 265
                 579 554
                 85 84
                 65 66
                 9 8
                 484 459
                 427 402
                 195 196
                 617 618
                 418 443
                 101 126
                 268 243
                 92 117
                 290 315
                 562 561
                 255 280
                 488 487
                 578 603
                 80 79
                 57 58
                 77 78
                 417 418
                 246 271
                 95 96
                 234 233
                 530 555
                 543 568
                 396 397
                 22 23
                 29 28
                 502 527
                 12 13
                 217 216
                 522 547
                 357 332
                 543 518
                 151 176
                 69 70
                 556 557
                 247 248
                 513 538
                 204 205
                 604 605
                 528 527
                 455 456
                 624 623
                 284 285
                 27 26
                 94 95
                 486 511
                 192 167
                 372 347
                 129 104
                 349 374
                 313 314
                 354 329
                 294 293
                 377 378
                 291 290
                 433 408
                 57 56
                 215 190
                 467 492
                 383 408
                 569 594
                 209 208
                 2 27
                 466 491
                 147 122
                 112 113
                 21 46
                 284 259
                 563 538
                 392 417
                 458 433
                 464 465
                 297 298
                 336 361
                 607 582
                 553 554
                 225 200
                 186 211
                 33 34
                 237 212
                 52 51
                 620 595
                 492 517
                 585 610
                 257 282
                 520 545
                 541 540
                 269 244
                 609 584
                 109 84
                 247 246
                 562 537
                 172 197
                 166 167
                 264 265
                 129 130
                 89 114
                 204 179
                 51 76
                 415 390
                 54 53
                 219 244
                 491 490
                 494 493
                 87 62
                 158 183
                 517 518
                 358 359
                 105 104
                 285 260
                 343 318
                 348 347
                 615 614
                 169 144
                 53 78
                 494 495
                 576 577
                 23 24
                 22 21
                 41 40
                 467 466
                 112 87
                 245 220
                 442 441
                 411 436
                 256 257
                 469 494
                 441 416
                 132 107
                 468 467
                 345 344
                 608 609
                 358 333
                 418 419
                 430 429
                 130 131
                 127 128
                 115 90
                 364 365
                 296 271
                 260 235
                 229 228
                 232 257
                 189 190
                 234 235
                 195 170
                 117 118
                 487 486
                 203 204
                 142 117
                 582 583
                 561 536
                 7 32
                 387 388
                 333 334
                 420 421
                 317 292
                 327 352
                 564 563
                 39 14
                 177 152
                 144 119
                 426 401
                 248 223
                 566 567
                 53 28
                 106 131
                 473 472
                 525 526
                 327 302
                 382 381
                 222 197
                 610 609
                 522 521
                 291 316
                 339 338
                 328 329
                 31 56
                 247 222
                 185 186
                 554 529
                 393 392
                 108 83
                 514 489
                 48 23
                 37 12
                 46 45
                 25 0
                 463 462
                 101 76
                 11 10
                 548 573
                 137 112
                 123 124
                 359 360
                 489 490
                 368 367
                 71 96
                 229 230
                 496 495
                 366 365
                 86 85
                 496 497
                 482 481
                 326 301
                 278 303
                 139 114
                 71 70
                 275 276
                 223 198
                 590 565
                 496 521
                 16 41
                 501 476
                 371 370
                 511 536
                 577 602
                 37 38
                 423 422
                 71 72
                 399 424
                 171 146
                 32 33
                 157 182
                 608 583
                 474 499
                 205 206
                 539 514
                 601 600
                 419 420
                 208 183
                 537 538
                 110 85
                 105 130
                 288 289
                 455 430
                 531 532
                 337 338
                 227 202
                 120 145
                 559 534
                 261 262
                 241 216
                 379 354
                 430 405
                 241 266
                 396 421
                 317 318
                 139 164
                 310 285
                 478 477
                 532 557
                 238 213
                 195 194
                 359 384
                 243 242
                 432 457
                 422 447
                 519 518
                 271 272
                 12 11
                 478 453
                 453 428
                 614 613
                 138 139
                 96 97
                 399 398
                 55 54
                 199 174
                 566 591
                 213 188
                 488 513
                 169 194
                 603 602
                 293 318
                 432 431
                 524 523
                 30 31
                 88 63
                 172 173
                 510 509
                 272 273
                 559 558
                 494 519
                 374 373
                 547 572
                 263 288
                 17 16
                 78 103
                 542 543
                 131 132
                 519 544
                 504 529
                 60 59
                 356 355
                 341 340
                 415 414
                 285 286
                 439 438
                 588 563
                 25 50
                 463 438
                 581 556
                 244 245
                 500 475
                 93 92
                 274 299
                 351 350
                 152 127
                 472 497
                 440 415
                 214 215
                 231 230
                 80 81
                 550 525
                 511 512
                 483 458
                 67 68
                 255 254
                 589 588
                 147 172
                 454 453
                 587 612
                 343 368
                 508 509
                 240 265
                 49 48
                 184 183
                 583 558
                 164 189
                 461 436
                 109 134
                 196 171
                 156 181
                 124 99
                 531 530
                 116 91
                 431 430
                 326 325
                 44 45
                 507 482
                 557 582
                 519 520
                 167 142
                 469 470
                 563 562
                 507 532
                 94 93
                 3 4
                 366 391
                 456 431
                 524 549
                 489 464
                 397 398
                 98 97
                 377 402
                 413 412
                 148 149
                 91 66
                 308 333
                 16 15
                 312 287
                 212 211
                 486 461
                 571 596
                 226 251
                 356 357
                 145 170
                 295 294
                 308 309
                 163 138
                 364 339
                 416 417
                 402 401
                 302 277
                 349 348
                 582 581
                 176 175
                 254 279
                 589 614
                 322 297
                 587 586
                 221 246
                 526 551
                 159 158
                 460 461
                 452 427
                 329 330
                 321 322
                 82 107
                 462 461
                 495 520
                 303 304
                 90 65
                 295 320
                 160 159
                 463 464
                 10 35
                 619 594
                 403 402
               |}


let process_str tinyUF = 
  (* 6 *) match Ext_string.split tinyUF '\n' with 
  | number :: rest ->
    (* 6 *) let n = int_of_string number in
    let store = Union_find.init n in
    List.iter (fun x ->
        (* 2739 *) match Ext_string.quick_split_by_ws x with 
        | [a;b] ->
          (* 2733 *) let a,b = int_of_string a , int_of_string b in 
          Union_find.union store a b 
        | _ -> (* 6 *) ()) rest;
    Union_find.count store
  | _ -> (* 0 *) assert false
;;        

let process_file file = 
  (* 0 *) let ichan = open_in_bin file in
  let n = int_of_string (input_line ichan) in
  let store = Union_find.init n in
  let edges = Int_vec_vec.make n in   
  let rec aux i =  
    (* 0 *) match input_line ichan with 
    | exception _ -> (* 0 *) ()
    | v ->
      (* 0 *) begin 
        (* if i = 0 then 
          print_endline "processing 100 nodes start";
    *)
        begin match Ext_string.quick_split_by_ws v with
          | [a;b] ->
            (* 0 *) let a,b = int_of_string a , int_of_string b in
            Int_vec_vec.push  (Int_vec.of_array [|a;b|]) edges; 
          | _ -> (* 0 *) ()
        end;
        aux ((i+1) mod 10000);
      end
  in aux 0;
  (* indeed, [unsafe_internal_array] is necessary for real performnace *)
  let internal = Int_vec_vec.unsafe_internal_array edges in
  for i = 0 to Array.length internal - 1 do
     (* 0 *) let i = Int_vec.unsafe_internal_array (Array.unsafe_get internal i) in 
     Union_find.union store (Array.unsafe_get i 0) (Array.unsafe_get i 1) 
  done;  
              (* Union_find.union store a b *)
  Union_find.count store 
;;                
let suites = 
  __FILE__
  >:::
  [
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_equal (process_str tinyUF) 2
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) OUnit.assert_equal (process_str mediumUF) 3
    end;
(*
   __LOC__ >:: begin fun _ ->
      OUnit.assert_equal (process_file "largeUF.txt") 6
    end;
  *)  

  ]
end
module Ounit_utf8_test
= struct
#1 "ounit_utf8_test.ml"


(* https://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt
*)

let ((>::),
    (>:::)) = OUnit.((>::),(>:::))

let (=~) = OUnit.assert_equal
let suites = 
    __FILE__
    >:::
    [
        __LOC__ >:: begin fun _ -> 
            (* 3 *) Ext_utf8.decode_utf8_string
            "hello 你好，中华民族 hei" =~
            [104; 101; 108; 108; 111; 32; 20320; 22909; 65292; 20013; 21326; 27665; 26063; 32; 104; 101; 105]
        end ;
        __LOC__ >:: begin fun _ -> 
            (* 3 *) Ext_utf8.decode_utf8_string
            "" =~ []
        end
    ]
end
module Ounit_vec_test
= struct
#1 "ounit_vec_test.ml"
let ((>::),
     (>:::)) = OUnit.((>::),(>:::))

open Ext_json

let v = Int_vec.init 10 (fun i -> (* 30 *) i);;
let (=~) x y = (* 0 *) OUnit.assert_equal ~cmp:(Int_vec.equal  (fun (x: int) y -> (* 0 *) x=y)) x y
let (=~~) x y 
  = 
  (* 66 *) OUnit.assert_equal ~cmp:(Int_vec.equal  (fun (x: int) y -> (* 4815 *) x=y)) 
  x (Int_vec.of_array y) 

let suites = 
  __FILE__ 
  >:::
  [
    (** idea 
      [%loc "inplace filter" ] --> __LOC__ ^ "inplace filter" 
      or "inplace filter" [@bs.loc]
    *)
    "inplace_filter " ^ __LOC__ >:: begin fun _ -> 
      (* 3 *) v =~~ [|0; 1; 2; 3; 4; 5; 6; 7; 8; 9|];
      
      ignore @@ Int_vec.push  32 v;
      let capacity = Int_vec.capacity v  in 
      v =~~ [|0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 32|];
      Int_vec.inplace_filter (fun x -> (* 33 *) x mod 2 = 0) v ;
      v =~~ [|0; 2; 4; 6; 8; 32|];
      Int_vec.inplace_filter (fun x -> (* 18 *) x mod 3 = 0) v ;
      v =~~ [|0;6|];
      Int_vec.inplace_filter (fun x -> (* 6 *) x mod 3 <> 0) v ;
      v =~~ [||];
      OUnit.assert_equal (Int_vec.capacity v ) capacity ;
      Int_vec.compact v ; 
      OUnit.assert_equal (Int_vec.capacity v ) 0 
    end
    ;
    "inplace_filter_from " ^ __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Int_vec.of_array (Array.init 10 (fun i -> (* 30 *) i)) in 
      v =~~ [|0; 1; 2; 3; 4; 5; 6; 7; 8; 9|]; 
      Int_vec.push 96 v  ;      
      Int_vec.inplace_filter_from 2 (fun x -> (* 27 *) x mod 2 = 0) v ;
      v =~~ [|0; 1; 2; 4; 6; 8; 96|];
      Int_vec.inplace_filter_from 2 (fun x -> (* 15 *) x mod 3 = 0) v ;
      v =~~ [|0; 1; 6; 96|];
      Int_vec.inplace_filter (fun x -> (* 12 *) x mod 3 <> 0) v ;
      v =~~ [|1|];      
      Int_vec.compact v ; 
      OUnit.assert_equal (Int_vec.capacity v ) 1
    end
    ;
    "map " ^ __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Int_vec.of_array (Array.init 1000 (fun i -> (* 3000 *) i )) in 
      Int_vec.map succ v =~~ (Array.init 1000 succ) ;
      OUnit.assert_bool __LOC__ (Int_vec.exists (fun x -> (* 3000 *) x >= 999) v );
      OUnit.assert_bool __LOC__ (not (Int_vec.exists (fun x -> (* 3000 *) x > 1000) v ));
      OUnit.assert_equal (Int_vec.last v ) 999
    end ;  
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let count = 1000 in 
      let init_array = (Array.init count (fun i -> (* 3000 *) i)) in 
      let u = Int_vec.of_array  init_array in 
      let v = Int_vec.inplace_filter_with (fun x -> (* 3000 *) x mod 2 = 0) ~cb_no:Set_int.add Set_int.empty u  in
      let (even,odd) = init_array |> Array.to_list |> List.partition (fun x -> (* 3000 *) x mod 2 = 0) in 
      OUnit.assert_equal 
      (Set_int.elements v) odd ;
      u =~~ Array.of_list even 
    end ;
    "filter" ^ __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Int_vec.of_array [|1;2;3;4;5;6|] in 
      v |> Int_vec.filter (fun x -> (* 18 *) x mod 3 = 0) |> (fun x -> (* 3 *) x =~~ [|3;6|]);
      v =~~ [|1;2;3;4;5;6|];
      Int_vec.pop v ; 
      v =~~ [|1;2;3;4;5|];
      let count = ref 0 in 
      let len = Int_vec.length v  in 
      while not (Int_vec.is_empty v ) do 
        (* 15 *) Int_vec.pop v ;
        incr count
      done;
      OUnit.assert_equal len !count
    end
    ;
    __LOC__ >:: begin fun _ -> 
      (* 3 *) let count = 100 in 
      let v = Int_vec.of_array (Array.init count (fun i -> (* 300 *) i)) in 
      OUnit.assert_bool __LOC__ 
        (try Int_vec.delete v count; false with _ -> (* 3 *) true );
      for i = count - 1 downto 10 do 
        (* 270 *) Int_vec.delete v i ;
      done ;
      v =~~ [|0;1;2;3;4;5;6;7;8;9|] 
    end; 
    "sub" ^ __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Int_vec.make 5 in 
      OUnit.assert_bool __LOC__
        (try ignore @@ Int_vec.sub v 0 2 ; false with Invalid_argument _  -> (* 3 *) true);
      Int_vec.push 1 v;
      OUnit.assert_bool __LOC__
        (try ignore @@ Int_vec.sub v 0 2 ; false with Invalid_argument _  -> (* 3 *) true);
      Int_vec.push 2 v ;  
      ( Int_vec.sub v 0 2 =~~ [|1;2|])
    end;
    "reserve" ^ __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Int_vec.empty () in 
      Int_vec.reserve v  1000 ;
      for i = 0 to 900 do
        (* 2703 *) Int_vec.push i v 
      done ;
      OUnit.assert_equal (Int_vec.length v) 901 ;
      OUnit.assert_equal (Int_vec.capacity v) 1000
    end ; 
    "capacity"  ^ __LOC__ >:: begin fun _ -> 
      (* 3 *) let v = Int_vec.of_array [|3|] in 
      Int_vec.reserve v 10 ;
      v =~~ [|3 |];
      Int_vec.push 1 v ;
      Int_vec.push 2 v ;
      Int_vec.push 5 v ;
      v=~~ [|3;1;2;5|];
      OUnit.assert_equal (Int_vec.capacity v  ) 10 ;
      for i = 0 to 5 do
        (* 18 *) Int_vec.push i  v
      done;
      v=~~ [|3;1;2;5;0;1;2;3;4;5|];
      Int_vec.push   100 v;
      v=~~[|3;1;2;5;0;1;2;3;4;5;100|];
      OUnit.assert_equal (Int_vec.capacity v ) 20
    end
    ;
    __LOC__  >:: begin fun _ -> 
      (* 3 *) let empty = Int_vec.empty () in 
      Int_vec.push   3 empty;
      empty =~~ [|3|];

    end
    ;
    __LOC__ >:: begin fun _ ->
      (* 3 *) let lst = [1;2;3;4] in 
      let v = Int_vec.of_list lst in 
      OUnit.assert_equal 
        (Int_vec.map_into_list (fun x -> (* 12 *) x + 1) v)
        (List.map (fun x -> (* 12 *) x + 1) lst)  
    end;
    __LOC__ >:: begin fun _ ->
      (* 3 *) let v = Int_vec.make 4 in 
      Int_vec.push 1 v;
      Int_vec.push 2 v;
      Int_vec.reverse_in_place v;
      v =~~ [|2;1|]
    end
    ;
  ]

end
module Ounit_tests_main : sig 
#1 "ounit_tests_main.mli"

end = struct
#1 "ounit_tests_main.ml"




module Int_array = Resize_array.Make(struct type t = int let null = 0 end);;
let v = Int_array.init 10 (fun i -> (* 30 *) i);;

let ((>::),
    (>:::)) = OUnit.((>::),(>:::))


let (=~) x y = (* 0 *) OUnit.assert_equal ~cmp:(Int_array.equal  (fun (x: int) y -> (* 0 *) x=y)) x y
let (=~~) x y 
  = 
  (* 0 *) OUnit.assert_equal ~cmp:(Int_array.equal  (fun (x: int) y -> (* 0 *) x=y)) x (Int_array.of_array y) 

let suites = 
  __FILE__ >:::
  [
    Ounit_vec_test.suites;
    Ounit_json_tests.suites;
    Ounit_path_tests.suites;
    Ounit_array_tests.suites;    
    Ounit_scc_tests.suites;
    Ounit_list_test.suites;
    Ounit_hash_set_tests.suites;
    Ounit_union_find_tests.suites;
    Ounit_bal_tree_tests.suites;
    Ounit_hash_stubs_test.suites;
    Ounit_map_tests.suites;
    Ounit_ordered_hash_set_tests.suites;
    Ounit_hashtbl_tests.suites;
    Ounit_string_tests.suites;
    Ounit_topsort_tests.suites;
    Ounit_sexp_tests.suites;
    Ounit_int_vec_tests.suites;
    Ounit_ident_mask_tests.suites;
    Ounit_cmd_tests.suites;
    Ounit_ffi_error_debug_test.suites;
    Ounit_js_regex_checker_tests.suites;
    Ounit_utf8_test.suites;
  ]
let _ = 
  OUnit.run_test_tt_main suites

end
