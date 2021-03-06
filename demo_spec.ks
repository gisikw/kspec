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
