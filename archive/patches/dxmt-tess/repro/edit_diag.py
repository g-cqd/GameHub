#!/usr/bin/env python3
"""Adds the shader SHA-1 prefixes to DXMT's mesh-pipeline error logs (GS and TS)."""
import os

os.chdir("/Volumes/ExT2/GameHub/work/dxmt-tess/src-wt/src/d3d11")


def edit(path, reps):
    s = open(path).read()
    for a, b in reps:
        assert s.count(a) == 1, (path, a[:70])
        s = s.replace(a, b)
    open(path, "w").write(s)


helper = """
static std::string
ShaderNames(std::initializer_list<std::pair<const char *, ManagedShader>> shaders) {
  // The first 8 hex digits of the SHA-1 of a shader are the ones in its function
  // names (vsgs_xxxxxxxx_*, gs_xxxxxxxx_*, ps_xxxxxxxx_*) in the DXMT shader cache.
  std::string names;
  for (auto &[stage, shader] : shaders) {
    if (!shader)
      continue;
    names += names.empty() ? "" : " ";
    names += stage;
    names += "=";
    names += shader->sha1().string().substr(0, 8);
  }
  return names;
}
"""

edit("d3d11_pipeline_gs.cpp", [
    ("namespace dxmt {\n\nclass MTLCompiledGeometryPipelineImpl",
     "namespace dxmt {\n" + helper + "\nclass MTLCompiledGeometryPipelineImpl"),
    ("""        RasterizationEnabled(pDesc->RasterizationEnabled),
        SampleCount(pDesc->SampleCount) {
    uint32_t unorm_output_reg_mask = 0;""", """        RasterizationEnabled(pDesc->RasterizationEnabled),
        SampleCount(pDesc->SampleCount),
        shader_names_(ShaderNames(
            {{"VS", pDesc->VertexShader}, {"GS", pDesc->GeometryShader}, {"PS", pDesc->PixelShader}}
        )) {
    uint32_t unorm_output_reg_mask = 0;"""),
    ("""      ERR("Failed to create mesh PSO: ", err.description().getUTF8String());""",
     """      ERR("Failed to create mesh PSO (", shader_names_, "): ", err.description().getUTF8String());"""),
    ("""  bool RasterizationEnabled;
  UINT SampleCount;

  CompiledShader *VertexShader;""", """  bool RasterizationEnabled;
  UINT SampleCount;
  std::string shader_names_;

  CompiledShader *VertexShader;"""),
])

edit("d3d11_pipeline_ts.cpp", [
    ("namespace dxmt {\n\nstatic dxmt::mutex ts_global_mutex;",
     "namespace dxmt {\n" + helper + "\nstatic dxmt::mutex ts_global_mutex;"),
    ("""        RasterizationEnabled(pDesc->RasterizationEnabled),
        SampleCount(pDesc->SampleCount) {
    uint32_t unorm_output_reg_mask = 0;""", """        RasterizationEnabled(pDesc->RasterizationEnabled),
        SampleCount(pDesc->SampleCount),
        shader_names_(ShaderNames(
            {{"VS", pDesc->VertexShader}, {"HS", pDesc->HullShader}, {"DS", pDesc->DomainShader}, {"PS", pDesc->PixelShader}}
        )) {
    uint32_t unorm_output_reg_mask = 0;"""),
    ("""      ERR("Failed to create tessellation raster PSO: ",
          err.description().getUTF8String());""", """      ERR("Failed to create tessellation raster PSO (", shader_names_, "): ",
          err.description().getUTF8String());"""),
    ("""  bool RasterizationEnabled;
  UINT SampleCount;

  MTL_SHADER_REFLECTION hull_reflection;""", """  bool RasterizationEnabled;
  UINT SampleCount;
  std::string shader_names_;

  MTL_SHADER_REFLECTION hull_reflection;"""),
])
print("ok")
