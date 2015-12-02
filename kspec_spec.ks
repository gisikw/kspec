// KSpec Basic Specs
// http://github.com/gisikw/kspec
// Kevin Gisi

describe("Basic spec assertions").

  context("when all assertions pass").
    it("reports a passing spec", "test_spec_assertion").
      function test_spec_assertion {
        assert(true).
      }
    end.
  end.

  context("when one assertion fails").
    it("reports a failing spec", "test_spec_fail_assert").
      function test_spec_fail_assert {
        assert(true).
        assert(false).
      }
    end.
  end.

  context("when the function fails").
    it("reports a failing spec", "test_spec_failure").
      function test_spec_failure {
        print 1 / 0.
      }
    end.
  end.

  context("when the block is marked as pending").
    it("reports a pending spec", "test_spec_pending").
      function test_spec_pending {
        pending().
      }
    end.
  end.

end.
