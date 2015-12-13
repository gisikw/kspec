# KSpec - A Test Framework for Kerbals!

BDD-style test framework for KerboScript, a la RSpec, Jasmine, Mocha, etc.

## Ship Dependencies

The ship must have at least 2 CPUs, and an active connection to the archive
volume. One CPU runs the individual tests in a sandboxed environment, and the
other monitors the full suite. Here's one example craft:

![](https://www.dropbox.com/s/83x11okoynjzqjk/kspec.png?dl=1)

This is necessary so that the suite is able to continue if the body of your
tests should happen to contain an error.

## Spec Syntax

Here's an example KSpec spec file:

```
describe("Enabled suite").
  it("is not pending", "test_enabled").
    function test_enabled { assert(true). }
  end.
end.

xdescribe("Disabled suite").
  it("is pending", "test_pending").
    function test_pending { assert(true). }
  end.
  describe("even nested").
    it("is also pending", "test_also_pending").
      function test_also_pending { assert(true). }
    end.
  end.
end.

describe("Failing spec").
  it("fails", "test_failing").
    function test_failing { assert(false). }
  end.
end.

describe("Equality assertions").
  it("shows helpful error messages", "test_equality").
    function test_equality { assert_equal("foo", "bar"). }
  end.
end.

describe("Erroring spec").
  it("errors", "test_error").
    function test_error { print 1/0. }
  end.
end.
```

## Usage

Assuming you wrote the previous example into `demo_spec.ks`, you can run the
spec via `run kspec.ks. kspec("demo_spec").` (you could also supply a list, e.g.
`run kspec. kspec(list("file1","file2"))`. It will run each test in isolation
on the second CPU, and report the results as they come in. Here's the output
from that example:

```
Enabled suite
  [.] is not pending
Disabled suite
  [*] is pending
  even nested
    [*] is also pending
Failing spec
  [x] fails
Equality assertions
  [x] shows helpful error messages
Erroring spec
  [x] errors

Finished in 5.52 seconds
6 examples, 3 failures, 2 pending

Failures:

  1) Failing spec fails
     Failure/Error: Expected false to be true

  2) Equality assertions shows helpful error messages
     Failure/Error: Expected foo to equal bar

  3) Erroring spec errors
```

## Installation

Provided you have KOS installed, you'll want to download `kspec.ks` and into
your Ships/Script folder, and you should be good to go.

Happy testing!

## Configuration

In order to handle error cases, KSpec uses a five-second timeout for specs that
may have failed. However, if you have a test body that takes longer, you can
change this behavior before running the suite:

```
run kspec.
set kspec_config["timeout"] to 15.
kspec("my_spec").
```

## TODO

* Flexible reporting (e.g. dots `...F...F...***...`)
* `it_only` support for quick debugging of a single test
* Reboot-tolerant spec bodies? Expose some interface via which specs could use
  kuniverse reverts for complex things?

## Copyright and Legal Stuffs

Copyright (c) 2015 by Kevin Gisi, released under the MIT License.
