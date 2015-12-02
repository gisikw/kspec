// KSpec BDD Library
// http://github.com/gisikw/kspec
// Kevin Gisi

@LAZYGLOBAL off.

// Allow single file or list arguments
parameter spec_files.
if list(spec_files):dump:substring(25,5) <> "LIST" {
  set spec_files to list(spec_files).
}

// Constants
local EXECUTING is 1.
local PASSING   is 2.
local FAILING   is 3.
local PENDING   is 4.

local l is lexicon().
set l["0"] to 0.
local quote is l:dump:split("")[24].


local spec_tree is lexicon().
local tree_path is list().

function current_node {
  local n is spec_tree.
  for p in tree_path set n to n[p].
  return n.
}

// KSpec syntax functions
function describe {
  parameter s.
  current_node():add(s, lexicon()).
  tree_path:add(s).
}

function context {
  parameter s.
  describe(s).
}

function end {
  set tree_path to tree_path:sublist(0, tree_path:length-1).
}

function it {
  parameter s.
  parameter f.

  local n is current_node().
  n:add(s, lexicon()).
  n[s]:add("function", f).
  n[s]:add("status", "waiting").
  tree_path:add(s).
}

function xit {
  parameter s.
  parameter f.
  it(s, f).
  set current_node()["status"] to "pending".
}

// KSpec execution
clearscreen.

// Run all spec files to build up the tree
log "" to _kspec_tree.ks.
delete _kspec_tree.ks.
for file in spec_files {
  log "describe(" + quote + file + quote + "). " to _kspec_tree.ks.
  log "run " + file + ". " to _kspec_tree.ks.
  log "end. " to _kspec_tree.ks.
}
run _kspec_tree.ks.
delete _kspec_tree.ks.

function execute_spec {
  parameter node.
  parameter sourcefile.
  parameter executor.

  switch to executor:volume.
  log "switch to 0."            to "kspec_boot.ks".
  log "run kspec_runtime."      to "kspec_boot.ks".
  log "run " + sourcefile + "." to "kspec_boot.ks".
  log "clearscreen."            to "kspec_boot.ks".
  log node["function"] + "()."  to "kspec_boot.ks".
  log "kspec_done()."           to "kspec_boot.ks".

  executor:deactivate.
  set executor:bootfilename to "kspec_boot.ks".
  executor:activate.

  local now is time:seconds.
  until time:seconds > (now + 10) {
    if executor:tag <> EXECUTING and executor:mode = "OFF" break.
    wait 0.5.
  }

  executor:deactivate.
  delete "kspec_boot.ks".
  switch to 0.

  if executor:tag = EXECUTING return FAILING.
  else return executor:tag.

}

function exec_node {
  parameter node.
  parameter name.
  parameter file.
  parameter executor.
  parameter indent.

  if node:haskey("function") {
    local result is execute_spec(node, file, executor).
    if result = PASSING print indent + name.
    if result = FAILING print indent + "[X] " + name.
    if result = PENDING print indent + "[*] " + name.
  } else {
    print indent + name.
    for n in node:keys {
      exec_node(node[n], n, file, executor, indent + "  ").
    }
  }
}

function exec_suite {
  parameter file.
  parameter tree.
  parameter executor.

  print "===== " + file + " =====".
  for node in tree:keys {
    exec_node(tree[node], node, file, executor, "").
  }
}

// Execute each file
local executor is false.
local ps is false.

list processors in ps.
for p in ps { if p:part <> core:part set executor to p. }

for file in spec_tree:keys {
  exec_suite(file, spec_tree[file], executor).
}
