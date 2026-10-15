#!/usr/bin/env python3
"""Metal.hpp: out-errors are autoreleased (+0); make the wrappers retain them for Reference<Error>."""
import re

p = "/Volumes/ExT2/GameHub/work/dxmt-tess/src-wt/src/winemetal/Metal.hpp"
s = open(p).read()

helper_anchor = """class Error : public Object {
public:
};
"""
helper = helper_anchor + """
/**
Metal hands out errors autoreleased (+0), but Reference<Error> releases what it holds.
Wrappers write the error into a plain handle and adopt it with this, which retains it;
storing the +0 handle in the Reference directly released the error twice, and the
thread crashed when its autorelease pool drained (pipeline compile threads when they
exit, which hung process teardown after a pipeline failed to compile).
*/
inline void
AdoptAutoreleasedError(Reference<Error> &error, obj_handle_t autoreleased) {
  if (autoreleased == NULL_OBJECT_HANDLE) {
    error = nullptr;
    return;
  }
  Error non_retained;
  non_retained.handle = autoreleased;
  error = non_retained; // retains
}
"""
assert s.count(helper_anchor) == 1
s = s.replace(helper_anchor, helper)

# Every wrapper taking `Error &error` and passing `&error.handle` to a thunk.
pattern = re.compile(r"(\n  [^\n]*\n  \w+\((?:[^)]*?))Error &error(\)\s*\{\n)(.*?)(\n  \}\n)", re.S)


def fix(m):
    head, sig_end, body, tail = m.group(1), m.group(2), m.group(3), m.group(4)
    assert "&error.handle" in body, body
    body = body.replace("&error.handle", "&error_handle")
    lines = body.split("\n")
    # Rewrite "return X;" (possibly multi-line) into "auto ret = X; Adopt...; return ret;"
    text = "\n".join(lines)
    if "return " in text and "auto ret = " not in text:
        idx = text.rindex("return ")
        expr_end = text.index(";", idx)
        expr = text[idx + len("return "):expr_end]
        text = text[:idx] + "auto ret = " + expr + ";\n    AdoptAutoreleasedError(error, error_handle);\n    return ret;" + text[expr_end + 1:]
    elif "auto ret = " in text:
        text = text.replace("    return ret;", "    AdoptAutoreleasedError(error, error_handle);\n    return ret;")
    else:  # void
        text = text + "\n    AdoptAutoreleasedError(error, error_handle);"
    text = "\n    obj_handle_t error_handle = NULL_OBJECT_HANDLE;" + text
    return head + "Reference<Error> &error" + sig_end.rstrip("\n") + text + tail


s2, n = pattern.subn(fix, s)
assert "Error &error" not in s2.replace("Reference<Error> &error", ""), "unconverted wrapper left"
open(p, "w").write(s2)
print("converted", n)
