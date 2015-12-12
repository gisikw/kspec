// +--------------------------------------------------------------------------+
// | KSpec BDD Library v0.0.2                                                 |
// | http://github.com/gisikw/kspec                                           |
// | Kevin Gisi                                                               |
// +--------------------------------------------------------------------------+

@LAZYGLOBAL off.

// +--------------------------------------------------------------------------+
// | KSpec State and Defaults                                                 |
// +--------------------------------------------------------------------------+

global kspec_state is lexicon().
set kspec_state["noparse"] to true.
set kspec_state["suite"] to lexicon().
set kspec_state["suite"]["state"] to "waiting".
set kspec_state["runtime"] to lexicon().
set kspec_state["runtime"]["total"] to 0.
set kspec_state["runtime"]["execution"] to 0.
set kspec_state["runtime"]["results"] to 0.
set kspec_state["runtime"]["parsing"] to 0.

set kspec_state["current_node"] to kspec_state["suite"].

// +--------------------------------------------------------------------------+
// | Utility Functions and Variables                                          |
// +--------------------------------------------------------------------------+

// Get the " character for use in logged scripts
local l is lexicon().
l:add("0",0).
local q is l:dump:substring(23, 1).
unset l.

// Get the first CPU that is not our own, for executing specs.
function kspec_get_available_cpu {
  list processors in ps.
  for p in ps { if p:part <> core:part return p. }.
}

// +--------------------------------------------------------------------------+
// | KSpec Syntax Stub Functions                                              |
// +--------------------------------------------------------------------------+

function xdescribe { parameter s. kspec_syntax(list("xdescribe", s)). }
function xcontext  { parameter s. kspec_syntax(list("xdescribe", s)). }
function describe  { parameter s. kspec_syntax(list("describe", s)).  }
function context   { parameter s. kspec_syntax(list("context", s)).   }
function end       { kspec_syntax(list("end")).                       }
function xit       { parameter s, f. kspec_syntax(list("xit", s, f)). }
function it        { parameter s, f. kspec_syntax(list("it",  s, f)). }

// +--------------------------------------------------------------------------+
// | KSpec Parsing Functions                                                  |
// +--------------------------------------------------------------------------+

// Stateful syntax function
// KSpec syntax is used for building the suite tree, but otherwise should be a
// noop. Unfortunately, there's no way to set global functions from within a
// function, so this logic allows the behavior of kspec syntax functions to be
// togglable.
function kspec_syntax {
  parameter args.
  if kspec_state["noparse"] return.
  if args[0] = "end" {
    set kspec_state["current_node"] to kspec_state["current_node"]["parent"].
  } else {
    local c is lexicon().
    local state is "waiting".
    if args[0]:substring(0, 1) = "x" set state to "pending".
    c:add("parent", kspec_state["current_node"]).
    c:add("state", state).
    if args[0]:contains("it") c:add("function", args[2]).
    kspec_state["current_node"]:add(args[1], c).
    set kspec_state["current_node"] to c.
  }
}

// Log each spec file, within a describe(filename) block, so they can be added
// to the parse tree.
function kspec_parse_files {
  parameter files.
  log "" to _kspec_parse.ks. delete _kspec_parse.ks.

  for file in files {
    log "describe(" + q + file + q + "). " to _kspec_parse.ks.
    log "run " + file + ". "               to _kspec_parse.ks.
    log "end."                             to _kspec_parse.ks.
  }

  set kspec_state["noparse"] to false.
  run _kspec_parse.ks. delete _kspec_parse.ks.
  set kspec_state["noparse"] to true.
}

// +--------------------------------------------------------------------------+
// | Kspec Assertion Functions                                                |
// +--------------------------------------------------------------------------+

function assert {
  parameter p.
  set kspec_state["runtime"][0] to kspec_state["runtime"][0] + 1.
  if not p set kspec_state["runtime"][1] to kspec_state["runtime"][1] + 1.
}

// +--------------------------------------------------------------------------+
// | Kspec Suite Manipulation Functions                                       |
// +--------------------------------------------------------------------------+

// Return a sanitized copy of a tree, such that self-referential elements are
// removed.
function kspec_safe_tree {
  parameter tree.
  local result is lexicon().
  for key in tree:keys if key <> "parent" {
    if key = "function" or key = "state" result:add(key, tree[key]).
    else result:add(key, kspec_safe_tree(tree[key])).
  }
  return result.
}

// Travel through a nested lex tree, depth first. Return false if there are no
// new nodes to visit.
function kspec_depth_first_traverse {
  local node is kspec_state["current_node"].
  if not node:haskey("function") {
    for key in node:keys if key <> "parent" and key <> "state" {
      set kspec_state["current_node"] to kspec_state["current_node"][key].
      return true.
    }
  }

  function take_next_sibling {
    parameter node.

    if not node:haskey("parent") return false.
    local parent is node["parent"].
    local take_next is false.
    for key in parent:keys {
      if take_next and key <> "parent" and key <> "state" {
        set kspec_state["current_node"] to parent[key].
        return true.
      }
      if parent[key] = node set take_next to true.
    }
    return false.
  }

  until not node:haskey("parent") {
    if take_next_sibling(node) return true.
    set node to node["parent"].
  }

  return false.
}

// Traverse the suite, and mark any children of pending contexts as also
// pending.
function kspec_pend_descendants {
  set kspec_state["current_node"] to kspec_state["suite"].
  until kspec_depth_first_traverse() = false {
    local node is kspec_state["current_node"].
    if node["state"] = "pending" and not node:haskey("function") {
      for key in node:keys if key <> "state" {
        set node[key]["state"] to "pending".
      }
    }
  }
}

// Traverse the suite, returning a list of all, failed, and pending spec counts
function kspec_get_stats {
  local result to list(0, 0, 0).
  set kspec_state["current_node"] to kspec_state["suite"].
  until kspec_depth_first_traverse() = false {
    local node is kspec_state["current_node"].
    if node:haskey("function") {
      set result[0] to result[0] + 1.
      if node["state"] = "failing" set result[1] to result[1] + 1.
      else if node["state"] = "pending" set result[2] to result[2] + 1.
    }
  }
  return result.
}

// +--------------------------------------------------------------------------+
// | KSpec Runtime Functions                                                  |
// +--------------------------------------------------------------------------+

// On the executing CPU, create a list(all assertions, failed assertions)
function kspec_runtime_init {
  set kspec_state["runtime"] to list(0, 0).
}


// Once the test function has run, update the part tag to reflect the result.
// If no assertions were made, the result is pending. If failing assertions
// were made, the result is failing. Otherwise, the result is passing.
function kspec_runtime_end {
  if kspec_state["runtime"][0] = 0 set core:part:tag to "kspec:pending".
  else {
    if kspec_state["runtime"][1] = 0 set core:part:tag to "kspec:passing".
    else set core:part:tag to "kspec:failing".
  }
  core:deactivate.
}

function kspec_print_summary {
  parameter start_time.

  local results is kspec_get_stats().
  local time_str is "Finished in ".
  local diff is time:seconds - start_time.

  local result_str is results[0] + " examples, " + results[1] + " failures".
  if results[2] > 0 {
    set result_str to result_str + ", " + results[2] + " pending".
  }

  if diff > 59 set time_str to time_str + floor(diff / 60) + " minutes ".
  print " ".
  print time_str + round(mod(diff, 60), 2) + " seconds".
  print result_str.
  print " ".
}

// +--------------------------------------------------------------------------+
// | Kspec Execution Functions                                                |
// +--------------------------------------------------------------------------+

function kspec_run_spec {
  local spec is kspec_state["current_node"].
  if spec["state"] = "pending" return "pending".

  local cpu is  kspec_get_available_cpu().
  local source_file is 0.
  local fn is spec["function"].

  local trace is spec.
  until source_file <> 0 {
    if trace["parent"]:haskey("parent") = false {
      for key in trace["parent"]:keys if trace["parent"][key] = trace {
        set source_file to key. break.
      }
    }
    set trace to trace["parent"].
  }

  switch to cpu:volume.
  log "" to "_kspec_boot.ks".
  delete "_kspec_boot.ks".
  log "switch to 0."              to "_kspec_boot.ks".
  log "run kspec."                to "_kspec_boot.ks".
  log "kspec_runtime_init()."     to "_kspec_Boot.ks".
  log "run " + source_file + "."  to "_kspec_boot.ks".
  log "clearscreen."              to "_kspec_boot.ks".
  log fn + "()."                  to "_kspec_boot.ks".
  log "kspec_runtime_end()."      to "_kspec_boot.ks".
  cpu:deactivate.
  set cpu:bootfilename to "_kspec_boot.ks".
  cpu:activate.

  local now is time:seconds.
  until false {
    if cpu:mode = "OFF" break.
    if time:seconds > (now + 5) break. // make config
    wait 0.01.
  }

  cpu:deactivate.
  delete "_kspec_boot.ks".
  switch to 0.

  local result is cpu:part:tag.
  if result:substring(0, 5) <> "kspec" return "failing".
  return result:substring(6, result:length - 6).
}

function kspec_run_suite {
  set kspec_state["current_node"] to kspec_state["suite"].

  until kspec_depth_first_traverse() = false {
    local node is kspec_state["current_node"].

    local text is 0.
    for key in node["parent"]:keys if node["parent"][key] = node {
      set text to key.
    }

    local indent is "". local trace is node["parent"].
    until trace:haskey("parent") = false {
      set indent to indent + "  ".
      set trace to trace["parent"].
    }

    if node:haskey("function") {
      local result is kspec_run_spec().
      set node["state"] to result.
      print indent + text  + ": " + result.
    } else print indent + text.
  }
}

// +--------------------------------------------------------------------------+
// | Kspec Public Function                                                    |
// +--------------------------------------------------------------------------+

function kspec {
  parameter files.
  if list(files):dump:substring(25, 4) <> "LIST" set files to list(files).
  local now is time:seconds.

  clearscreen.
  kspec_parse_files(files).
  kspec_pend_descendants().
  kspec_run_suite().
  kspec_print_summary(now).
}
