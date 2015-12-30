// +--------------------------------------------------------------------------+
// | KSpec BDD Library v0.1.0                                                 |
// | http://github.com/gisikw/kspec                                           |
// | Kevin Gisi                                                               |
// +--------------------------------------------------------------------------+

@LAZYGLOBAL off.

// +--------------------------------------------------------------------------+
// | Global configuration lexicon                                             |
// | This contains both configurable components and tweakable settings, but   |
// | must exist globally so that it can be modified by nested programs.       |
// +--------------------------------------------------------------------------+
global kspec_config is lexicon().

set kspec_config["timeout"] to 5. // Time to wait on a single spec

set kspec_config[0] to list().    // Contains all specs/contexts
// Context: list(text, pending, depth)
// Spec:    list(text, pending, depth, file, function, result, error)

set kspec_config[1] to 0. // Pending flag (assigned to depth when active)
set kspec_config[2] to 1. // Current depth
set kspec_config[3] to 0. // Current file
set kspec_config[4] to 0. // Total spec count
set kspec_config[5] to 0. // Pending spec count
set kspec_config[6] to list(). // Failing specs

// +--------------------------------------------------------------------------+
// | KSpec Runtime                                                            |
// | Provides the API for invoking KSpec. Examples:                           |
// | kspec("my_spec.ks"). kspec(list("my_spec", "other_spec")).               |
// +--------------------------------------------------------------------------+
function kspec {
  parameter files.
  if list(files):dump:substring(25, 4) <> "LIST" set files to list(files).

  local start_time is time:seconds.
  clearscreen.

  local results is list("?","*",".","x").
  local l is lexicon().
  l:add("0",0).
  local q is l:dump:substring(22, 1).
  unset l.

  // Creates DSL functions for spec files (describe, it, etc), which append
  // items to the kspec_config global. This allows KSpec to build up a tree of
  // all specs found in the source files prior to execution
  local dsl is "function xdescribe{parameter s.if not kspec_config[1] {set kspec_config[1] to kspec_config[2].}describe(s).}function xcontext{parameter s.xdescribe(s).}function describe{parameter s.kspec_config[0]:add(list(s,kspec_config[1],kspec_config[2])).set kspec_config[2] to kspec_config[2]+1.}function context{parameter s.describe(s).}function end{if kspec_config[1]=kspec_config[2] set kspec_config[1] to 0.set kspec_config[2] to kspec_config[2]-1.}function xit{parameter s,f.set kspec_config[1] to kspec_config[1]+1.it(s,f).}function it{parameter s,f.if kspec_config[1] set kspec_config[1] to kspec_config[1]+1.kspec_config[0]:add(list(s,kspec_config[1],kspec_config[2],kspec_config[3],f,0,0)).set kspec_config[2] to kspec_config[2]+1.}function kspec_set_file{parameter n. set kspec_config[3] to n.}".

  // Stubs out DSL functions (describe, it, etc), while creating assertion
  // helpers to be used in the body of spec functions
  local runtime_dsl is "function assert{parameter p.set kspec_assertions[0] to 1. if not p{set kspec_assertions[1] to "+q+"Expected false to be true"+q+". kspec_done().}}function assert_equal{parameter a,b. set kspec_assertions[0] to 1. if a<>b{set kspec_assertions[1] to "+q+"Expected "+q+"+a+"+q+" to equal "+q+"+b. kspec_done().}}function xdescribe{parameter s.}function xcontext{parameter s.}function describe{parameter s.}function context{parameter s.}function end{}function xit{parameter s,f.}function it{parameter s,f.}function kspec_done{if kspec_assertions[0]=0 set core:part:tag to "+q+"kspec:pending"+q+".else if kspec_assertions[1]<>0{set core:part:tag to "+q+"kspec:failing|"+q+"+kspec_assertions[1].}else set core:part:tag to "+q+"kspec:passing"+q+".core:deactivate.}set kspec_assertions to list(0,0).switch to 0.clearscreen.".

  // Handles a spec upon completion, returning back a string to represent its
  // status
  function result {
    parameter idx.
    local item is kspec_config[0][idx].
    local prefix is "".
    from { local i is 1. } until i = item[2] step { set i to i + 1. } do {
      set prefix to prefix + "  ".
    }
    if item:length > 3 {
      if item[1] {
        set prefix to prefix + "[*] ".
        set kspec_config[5] to kspec_config[5] + 1.
      } else set prefix to prefix + "["+results[item[5]]+"] ".
      set kspec_config[4] to kspec_config[4] + 1.
      if item[5] = 1 set kspec_config[5] to kspec_config[5] + 1.
      if item[5] = 3 kspec_config[6]:add(idx).
    }
    return prefix+item[0].
  }

  // Log the DSL to file, and run all the inputs, to build up the list of specs
  log "" to _kspec_dsl.ks. delete _kspec_dsl.ks.
  log dsl to _kspec_dsl.ks.
  run _kspec_dsl.ks. delete _kspec_dsl.ks.
  log "" to _kspec_parse.ks. delete _kspec_parse.ks.
  for file in files {
    log "kspec_set_file("+q+file+q+")." to _kspec_parse.ks.
    log "run " + file + "." to _kspec_parse.ks.
  }
  run _kspec_parse.ks. delete _kspec_parse.ks.

  // Get a secondary CPU on which to run the specs.
  local cpu is 0. list processors in cpu.
  for c in cpu { if c:part <> core:part { set cpu to c. break. }}

  // Run through each context/spec, getting the result if the spec isn't
  // pending
  from {local i is 0.} until i=kspec_config[0]:length step {set i to i+1.} do {
    local item is kspec_config[0][i].
    if item:length > 3 and not item[1] {

      switch to cpu:volume.
      log "" to "_kspec_boot.ks".
      delete "_kspec_boot.ks".
      log runtime_dsl to "_kspec_boot.ks".
      log "run " + item[3] + "." to "_kspec_boot.ks".
      log item[4] + "()." to "_kspec_boot.ks".
      log "kspec_done()." to "_kspec_boot.ks".
      cpu:deactivate.
      set cpu:bootfilename to "_kspec_boot.ks".
      set cpu:part:tag to "kspec:running".
      cpu:activate.

      local now is time:seconds.
      until false {
        if cpu:mode = "OFF" break.
        if time:seconds > (now + kspec_config["timeout"]) break.
        wait 0.01.
      }

      cpu:deactivate.
      delete "_kspec_boot.ks".
      switch to 0.

      local val is cpu:part:tag.
      if val = "kspec:passing" set item[5] to 2.
      else if val = "kspec:pending" set item[5] to 1.
      else {
        set item[5] to 3.
        if val:length > 14 and val:substring(0,14) = "kspec:failing|" {
          set item[6] to val:substring(14, val:length - 14).
        }
      }

      print result(i).
    } else print result(i).
  }

  // Output the result summary
  local time_str is "Finished in ".
  local diff is time:seconds - start_time.
  local result_str is kspec_config[4] + " examples, " + kspec_config[6]:length + " failures".
  if kspec_config[5] > 0 {
    set result_str to result_str + ", " + kspec_config[5] + " pending".
  }
  if diff > 59 set time_str to time_str + floor(diff / 60) + " minutes ".
  print " ".
  print time_str + round(mod(diff, 60), 2) + " seconds".
  print result_str.
  print " ".

  // If there were failing specs, print them along with any error messages.
  if kspec_config[6]:length {
    print "Failures:". print " ".
    from { local j is 0. } until j = kspec_config[6]:length step { set j to j + 1. } do {
      local i is kspec_config[6][j].
      local d is kspec_config[0][i][2].
      local text is kspec_config[0][i][0].
      until 0 {
        if kspec_config[0][i][2] < d {
          set text to kspec_config[0][i][0] + " " + text.
          set d to d - 1.
          if kspec_config[0][i][2] = 1 break.
        }
        set i to i - 1.
      }
      print "  " + (j+1) + ") " + text.
      if kspec_config[0][kspec_config[6][j]][6] <> 0 {
        print "     Failure/Error: " + kspec_config[0][kspec_config[6][j]][6].
      }
      print " ".
    }
  }
}
