p = "/Volumes/ExT2/GameHub/work/dxmt-tess/src-wt/src/winemetal/Metal.hpp"
s = open(p).read()
reps = [
("""  newLibrary(const void *bytecode, uint64_t bytecode_length, Error &error) {
    auto data = DispatchData_alloc_init((uint64_t)bytecode, bytecode_length);
    auto ret = Reference<Library>(MTLDevice_newLibrary(handle, data, &error.handle));
    NSObject_release(data);
    return ret;""",
"""  newLibrary(const void *bytecode, uint64_t bytecode_length, Reference<Error> &error) {
    obj_handle_t error_handle = NULL_OBJECT_HANDLE;
    auto data = DispatchData_alloc_init((uint64_t)bytecode, bytecode_length);
    auto ret = Reference<Library>(MTLDevice_newLibrary(handle, data, &error_handle));
    NSObject_release(data);
    AdoptAutoreleasedError(error, error_handle);
    return ret;"""),
("""  newLibraryFromNativeBuffer(uint64_t bytecode, uint64_t bytecode_length, Error &error) {
    auto data = DispatchData_alloc_init(bytecode, bytecode_length);
    auto ret = Reference<Library>(MTLDevice_newLibrary(handle, data, &error.handle));
    NSObject_release(data);
    return ret;""",
"""  newLibraryFromNativeBuffer(uint64_t bytecode, uint64_t bytecode_length, Reference<Error> &error) {
    obj_handle_t error_handle = NULL_OBJECT_HANDLE;
    auto data = DispatchData_alloc_init(bytecode, bytecode_length);
    auto ret = Reference<Library>(MTLDevice_newLibrary(handle, data, &error_handle));
    NSObject_release(data);
    AdoptAutoreleasedError(error, error_handle);
    return ret;"""),
("""  newLibrary(DispatchData data, Error &error) {
    return Reference<Library>(MTLDevice_newLibrary(handle, data, &error.handle));""",
"""  newLibrary(DispatchData data, Reference<Error> &error) {
    obj_handle_t error_handle = NULL_OBJECT_HANDLE;
    auto ret = Reference<Library>(MTLDevice_newLibrary(handle, data, &error_handle));
    AdoptAutoreleasedError(error, error_handle);
    return ret;"""),
]
for a, b in reps:
    assert s.count(a) == 1, a[:60]
    s = s.replace(a, b)

# Remaining single-statement wrappers: "(..., Error &error) {\n    [...]return Reference<T>(CALL(..., &error.handle));"
import re
pat = re.compile(r"Error &error\) \{\n((?:    [^\n]*\n)*?)    return (Reference<\w+>\(\w+\([^;]*?&error\.handle\)\));\n")
def fix(m):
    pre, expr = m.group(1), m.group(2)
    return ("Reference<Error> &error) {\n" + pre +
            "    obj_handle_t error_handle = NULL_OBJECT_HANDLE;\n"
            "    auto ret = " + expr.replace("&error.handle", "&error_handle") + ";\n"
            "    AdoptAutoreleasedError(error, error_handle);\n"
            "    return ret;\n")
s, n = pat.subn(fix, s)
print("regex converted", n)
assert "&error.handle" not in s, "left: " + str(s.count("&error.handle"))
open(p, "w").write(s)
