describe("kspec_listify").
  context("when passed a list").
    it("returns the original argument", "test_listify_list").
      function test_listify_list {
        local l is list(1, 2, 3).
        assert(kspec_listify(l) = l).
      }
    end.
  end.
  context("when passed a string").
    it("returns a list containing the string", "test_listify_string").
      function test_listify_string {
        local l is "argument".
        assert(kspec_listify(l):contains(l)).
      }
    end.
  end.
end.

describe("kspec_tree_get").
  it("returns the nested value of a lex tree", "test_kspec_tree_get").
    function test_kspec_tree_get {
      local l is lexicon().
      set l["foo"] to lexicon().
      set l["foo"]["bar"] to 5.
      assert(kspec_tree_get(l, list("foo", "bar")) = 5).
    }
  end.
end.

describe("kspec_tree_set").
  it("sets a nested value in a lex tree", "test_kspec_tree_set").
    function test_kspec_tree_set {
      local l is lexicon().
      set l["foo"] to lexicon().
      kspec_tree_set(l, list("foo", "bar"), 5).
      assert(l["foo"]["bar"] = 5).
    }
  end.
end.

xdescribe("kspec_parse_files").

  function write_fake_spec {
    local l is lexicon(). set l["0"] to 0.
    local q is l:dump:substring(23, 1).

    local spec is "_fake_spec.ks".
    log "" to spec.
    delete spec.
    log "describe("+q+"simple assertion"+q+")."                 to spec.
    log "it("+q+"parses correctly"+q+","+q+"test_assert"+q+")." to spec.
    log "function test_assert { assert(true). }"                to spec.
    log "end. end."                                             to spec.
    return spec.
  }

  xit("returns a lex tree", "test_kspec_parse_files").
    function test_kspec_parse_files {
      local spec is write_fake_spec().
      local result is list(kspec_parse_files(spec)).
      local type is result:dump:substring(25, 7).

      assert(type = "LEXICON").
    }
  end.

  xit("contains top-level elements", "test_kspec_parse_top_level").
    function test_kspec_parse_top_level {
      local spec is write_fake_spec().
      local result is kspec_parse_files(spec).

      assert(result:haskey("simple assertion")).
    }
  end.
end.
