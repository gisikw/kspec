// +--------------------------------------------------------------------------+
// | KSpec BDD Library v0.0.3                                                 |
// | http://github.com/gisikw/kspec                                           |
// | Kevin Gisi                                                               |
// +--------------------------------------------------------------------------+

@LAZYGLOBAL off.

global kspec_state is list(
  list(), // Parsed suite
  0,      // Pending
  1,      // Depth
  0,      // File name
  0,      // Total count
  0,      // Pending count
  0       // Failure count
).

function kspec {
  parameter files.
  if list(files):dump:substring(25, 4) <> "LIST" set files to list(files).

  local start_time is time:seconds.
  clearscreen.

  local results is list("?","*",".","x").
  local l is lexicon().
  l:add("0",0).
  local q is l:dump:substring(23, 1).
  unset l.

  function result {
    parameter item.
    local prefix is "".
    from { local i is 1. } until i = item[2] step { set i to i + 1. } do {
      set prefix to prefix + "  ".
    }
    if item:length > 3 {
      if item[1] {
        set prefix to prefix + "[*] ".
        set kspec_state[5] to kspec_state[5] + 1.
      } else set prefix to prefix + "["+results[item[5]]+"] ".
      set kspec_state[4] to kspec_state[4] + 1.
      if item[5] = 1 set kspec_state[5] to kspec_state[5] + 1.
      if item[5] = 3 set kspec_state[6] to kspec_state[6] + 1.
    }
    return prefix+item[0].
  }

  local runtime_dsl is "function assert{parameter p.set kspec_assertions[0] to kspec_assertions[0]+1.if not p{set kspec_assertions[1] to kspec_assertions[1]+1.}}function xdescribe{parameter s.}function xcontext{parameter s.}function describe{parameter s.}function context{parameter s.}function end{}function xit{parameter s,f.}function it{parameter s,f.}function kspec_done{if kspec_assertions[0]=0 set core:part:tag to "+q+"kspec:pending"+q+".else if kspec_assertions[1]=0 set core:part:tag to "+q+"kspec:passing"+q+".core:deactivate.}set kspec_assertions to list(0,0).switch to 0.clearscreen.".

  local dsl is "function xdescribe{parameter s.if not kspec_state[1] {set kspec_state[1] to kspec_state[2].}describe(s).}function xcontext{parameter s.xdescribe(s).}function describe{parameter s.kspec_state[0]:add(list(s,kspec_state[1],kspec_state[2])).set kspec_state[2] to kspec_state[2]+1.}function context{parameters.describe(s).}function end{if kspec_state[1]=kspec_state[2] set kspec_state[1] to 0.set kspec_state[2] to kspec_state[2]-1.}function xit{parameter s,f.set kspec_state[1] to kspec_state[1]+1.it(s,f).}function it{parameter s,f.if kspec_state[1] set kspec_state[1] to kspec_state[1]+1.kspec_state[0]:add(list(s,kspec_state[1],kspec_state[2],kspec_state[3],f,0,0)).set kspec_state[2] to kspec_state[2]+1.}function kspec_set_file{parameter n. set kspec_state[3] to n.}".

  // Describe: list(text, pending, depth)
  // It: list(text, pending, depth, file, function, result, message)

  log "" to kspec_dsl.ks.
  delete kspec_dsl.ks.
  log dsl to kspec_dsl.ks.
  run kspec_dsl.ks.
  delete kspec_dsl.ks.

  log "" to _kspec_parse.ks. delete _kspec_parse.ks.
  for file in files {
    log "kspec_set_file("+q+file+q+")." to _kspec_parse.ks.
    log "run " + file + "." to _kspec_parse.ks.
  }
  run _kspec_parse.ks. delete _kspec_parse.ks.

  // Execution
  function get_cpu {
    local ps is 0.
    list processors in ps.
    for p in ps { if p:part <> core:part return p. }.
  }
  local cpu is get_cpu.

  for item in kspec_state[0] {
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
        if time:seconds > (now + 5) break. // make config
        wait 0.01.
      }

      cpu:deactivate.
      delete "_kspec_boot.ks".
      switch to 0.

      local val is cpu:part:tag.
      if val = "kspec:passing" set item[5] to 2.
      else if val = "kspec:pending" set item[5] to 1.
      else set item[5] to 3.

      print result(item).
    } else print result(item).
  }

  local time_str is "Finished in ".
  local diff is time:seconds - start_time.

  local result_str is kspec_state[4] + " examples, " + kspec_state[6] + " failures".
  if kspec_state[5] > 0 {
    set result_str to result_str + ", " + kspec_state[5] + " pending".
  }

  if diff > 59 set time_str to time_str + floor(diff / 60) + " minutes ".
  print " ".
  print time_str + round(mod(diff, 60), 2) + " seconds".
  print result_str.
  print " ".
}

kspec("demo_spec").
