// KSpec BDD Library Runtime
// http://github.com/gisikw/kspec
// Kevin Gisi

@LAZYGLOBAL off.

local STAT_EXECUTING is 1.
local STAT_PASSING   is 2.
local STAT_FAILING   is 3.
local STAT_PENDING   is 4.

local any_assertions is false.
local status is STAT_EXECUTING.

function kspec_report {
  parameter s.
  set status to s.
  set core:part:tag to status.
}

function kspec_done {
  if any_assertions kspec_report(STAT_PASSING).
  else kspec_report(STAT_PENDING).
  core:deactivate.
}

// Stub out kspec syntax (we're only interested in the actual functions)
function describe { parameter s. }
function context  { parameter s. }
function end      {}
function it       { parameter s. parameter f. }
function xit      { parameter s. parameter f. }

// Assertion tools
function pending  { kspec_report(STAT_PENDING). core:deactivate. }
function assert {
  parameter v.
  if v set any_assertions to true.
  else {
    kspec_report(STAT_FAILING). core:deactivate.
  }
  wait 0.1. // This is necessary for assert(true). assert(false). Not yet sure why
}

kspec_report(STAT_EXECUTING).
