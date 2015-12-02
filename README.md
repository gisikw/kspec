# KSpec (WIP)

BDD-style test framework for KerboScript, a la RSpec, Jasmine, Mocha, etc.

## Ship Dependencies

The ship must have at least 2 CPUs, and an active connection to the archive
volume. One CPU runs the individual tests in a sandboxed environment, and the
other monitors the full suite.

This is necessary so that the suite is able to continue if the body of your
tests should happen to contain an error.

## Spec Syntax

Here's an example KSpec spec file:

```
describe("Some really cool thing I want to test").
  it("should be incredibly awesome", "test_incredibly_awesome").
    function test_incredibly_awesome {
      run totally_awesome_lib.
      assert(totally_awesome = true).
    }
  end.

  context("if it's not awesome").
    it("should fail", "test_not_awesome").
      function test_not_awesome {
        assert(false).
      }
    end
  end.

  it("should have more specs", "test_more_specs").
    function test_more_specs {
      pending().
    }
  end.
end.
```

## Usage

Assuming you wrote the previous example into `awesome_spec.ks`, you can run the
spec via `RUN kspec("awesome_spec").` (you could also supply a list, e.g.
`RUN kspec(list("file1","file2"))`. It will run each test in isolation on the
second CPU, and report the results as they come in. Here's the output from that
example.

```
===== awesome_spec =====
Some really cool thing I want to test
  should be incredibly awesome
  if it's not awesome
    [X] should fail
  [*] should have more specs
```

## Installation

Provided you have KOS installed, you'll want to download `kspec.ks` and
`kspec_runtime.ks` into your Ships/Script folder, and you should be good to go.
Happy testing!

## TODO

* Suite summaries
* Flexible reporting (e.g. dots `...F...F...***...`)
* Code cleanup
* Better assertions, `assert_equal` with descriptive failure output, etc
* `xit`, `it_only`, `xdescribe`, etc. support
* Config options (timeout, show pending)
* Probably should switch to the executing volume prior to running spec bodies
* `before__each`, `after_each` hooks
* Reboot-tolerant spec bodies? Expose some interface via which specs could use
  kuniverse reverts for complex things?

## Copyright and Legal Stuffs

Copyright (c) 2015 by Kevin Gisi, released under the MIT License.
