#!/usr/bin/env python3
"""GS mesh pipelines: output every user varying the pixel shader reads (zero if the GS does not write it)."""
import os

os.chdir("/Volumes/ExT2/GameHub/work/dxmt-tess/src-wt/src")


def edit(p, reps):
    s = open(p).read()
    for a, b in reps:
        assert s.count(a) == 1, (p, a[:80])
        s = s.replace(a, b)
    open(p, "w").write(s)


# 1. public API: new argument carrying the pixel shader of the pipeline
edit("airconv/airconv_public.h", [
    ("""  SM50_SHADER_PSO_TESSELLATOR = 7,
  SM50_SHADER_ARGUMENT_TYPE_MAX = 0xffffffff,""",
     """  SM50_SHADER_PSO_TESSELLATOR = 7,
  SM50_SHADER_PSO_PIXEL_SHADER_INPUT = 8,
  SM50_SHADER_ARGUMENT_TYPE_MAX = 0xffffffff,"""),
    ("""struct SM50_SHADER_PSO_TESSELLATOR_DATA {""",
     """/**
The pixel shader of the pipeline, for a geometry shader compiled as a mesh function:
the mesh function then also outputs every user varying the pixel shader reads, the
value of the GS output register if the GS declares it, otherwise zero. D3D11 leaves
such inputs undefined; Metal's compiler crashes on M1/M2 (G14X) if a fragment input is
missing from the mesh outputs. Converters that do not know this type ignore it.
*/
struct SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA {
  void *next;
  enum SM50_SHADER_COMPILATION_ARGUMENT_TYPE type;
  sm50_shader_t pixel_shader;
};

struct SM50_SHADER_PSO_TESSELLATOR_DATA {"""),
])

# 2. 32-bit argument conversion in winemetal.so
edit("winemetal/unix/winemetal_unix.c", [
    ("""struct SM50_SHADER_PSO_TESSELLATOR_DATA32 {""",
     """struct SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA32 {
  uint32_t next;
  enum SM50_SHADER_COMPILATION_ARGUMENT_TYPE type;
  uint64_t pixel_shader; /* sm50_shader_t, 64-bit on both sides, offset 8 */
};

struct SM50_SHADER_PSO_TESSELLATOR_DATA32 {"""),
    ("""    case SM50_SHADER_ARGUMENT_TYPE_MAX:
      break;
    }
    args32 = UInt32ToPtr(args32->next);""",
     """    case SM50_SHADER_PSO_PIXEL_SHADER_INPUT: {
      struct SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA32 *src = (void *)args32;
      struct SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA *data =
          malloc(sizeof(struct SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA));
      last_arg->next = data;
      last_arg = (void *)data;
      last_arg->next = NULL;
      data->type = src->type;
      data->pixel_shader = (sm50_shader_t)src->pixel_shader;
      break;
    }
    case SM50_SHADER_ARGUMENT_TYPE_MAX:
      break;
    }
    args32 = UInt32ToPtr(args32->next);"""),
])

# 3. parse-time records
edit("airconv/dxbc_converter.hpp", [
    ("""class SM50ShaderInternal {
public:""",
     """struct PixelShaderUserInput {
  uint32_t reg;
  uint32_t mask; /* components of the signature element */
  std::string name;
  RegisterComponentType type;
};

class SM50ShaderInternal {
public:"""),
    ("""  uint32_t num_mesh_vertex_data = 0;""",
     """  uint32_t num_mesh_vertex_data = 0;
  /* pixel shader: the user (non system value) inputs it declares */
  std::vector<PixelShaderUserInput> ps_user_inputs;
  /* geometry shader: components declared by dcl_output, per output register */
  std::array<uint8_t, 32> gs_output_reg_masks = {};"""),
    ("""pop_mesh_output_vertex_data(uint32_t from_reg, uint32_t mask, uint32_t idx, pvalue vertex_id, air::MSLScalerOrVectorType desired_type);""",
     """pop_mesh_output_vertex_data(uint32_t from_reg, uint32_t mask, uint32_t idx, pvalue vertex_id, air::MSLScalerOrVectorType desired_type);
IREffect
pop_mesh_output_vertex_data_zero(uint32_t idx, pvalue vertex_id, air::MSLScalerOrVectorType desired_type);"""),
])

edit("airconv/dxbc_converter_basicblock.cpp", [
    ("""IREffect pull_vertex_input(""",
     """IREffect
pop_mesh_output_vertex_data_zero(uint32_t idx, pvalue vertex_id, air::MSLScalerOrVectorType desired_type) {
  auto ctx = co_yield get_context();
  ctx.air.CreateSetMeshVertexData(
      vertex_id, idx, llvm::Constant::getNullValue(air::get_llvm_type(desired_type, ctx.llvm))
  );
  co_return {};
}

IREffect pull_vertex_input("""),
])

# 4. record PS inputs and GS output masks while parsing
edit("airconv/dxbc_signature.cpp", [
    ("""    max_input_register = std::max(reg + 1, max_input_register);
    if (sig.mask() == 0) break;
    signature_handlers.push_back([=, type = sig.componentType(), name = sig.consistentAttributeName()]
    (SignatureContext &ctx) {
      bool pull_mode = bool(ctx.pull_mode_reg_mask & (1 << reg)) && interpolation != air::Interpolation::flat;""",
     """    max_input_register = std::max(reg + 1, max_input_register);
    if (sig.mask() == 0) break;
    sm50_shader->ps_user_inputs.push_back(
      {.reg = reg, .mask = sig.mask(), .name = sig.consistentAttributeName(), .type = sig.componentType()}
    );
    signature_handlers.push_back([=, type = sig.componentType(), name = sig.consistentAttributeName()]
    (SignatureContext &ctx) {
      bool pull_mode = bool(ctx.pull_mode_reg_mask & (1 << reg)) && interpolation != air::Interpolation::flat;"""),
])

s = open("airconv/dxbc_signature.cpp").read()
gs_start = s.index("handle_signature_gs(")
gs_part = s[gs_start:]
a = """      max_output_register = std::max(reg + 1, max_output_register);
      if (sig.mask() == 0) break;
      auto const mesh_vertex_data_index = num_mesh_vertex_data++;"""
b = """      max_output_register = std::max(reg + 1, max_output_register);
      if (reg < sm50_shader->gs_output_reg_masks.size())
        sm50_shader->gs_output_reg_masks[reg] |= mask;
      if (sig.mask() == 0) break;
      auto const mesh_vertex_data_index = num_mesh_vertex_data++;"""
assert gs_part.count(a) == 1
s = s[:gs_start] + gs_part.replace(a, b)
open("airconv/dxbc_signature.cpp", "w").write(s)

# 5. signature builder query
edit("airconv/air_signature.hpp", [
    ("""  void UseEarlyFragmentTests() { early_fragment_tests = true; }""",
     """  bool HasMeshVertexData(const std::string &user) const {
    for (auto &output : mesh_vertex_outputs)
      if (auto data = std::get_if<OutputMeshData>(&output); data && data->user == user)
        return true;
    return false;
  }
  void UseEarlyFragmentTests() { early_fragment_tests = true; }"""),
])

# 6. GS converter: extra outputs for the pixel shader inputs
edit("airconv/dxbc_converter_gs.cpp", [
    ("""  auto& gs_output_handlers = pShaderInternal->mesh_output_handlers;
""",
     """  auto gs_output_handlers = pShaderInternal->mesh_output_handlers; // copy: extended per pipeline below

  SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA *ps_input_data = nullptr;
  if (args_get_data<SM50_SHADER_PSO_PIXEL_SHADER_INPUT, SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA>(
          pArgs, &ps_input_data
      ) &&
      ps_input_data->pixel_shader) {
    // Output every user varying the pixel shader reads. D3D11 links by register and
    // leaves a register the GS does not write undefined; Metal requires each fragment
    // input among the mesh outputs (the G14X compiler crashes otherwise).
    auto pixel_stage = (SM50ShaderInternal *)ps_input_data->pixel_shader;
    uint32_t next_index = pShaderInternal->num_mesh_vertex_data;
    for (auto &input : pixel_stage->ps_user_inputs) {
      if (func_signature.HasMeshVertexData(input.name))
        continue;
      auto const index = next_index++;
      auto const type = to_msl_type(input.type);
      func_signature.DefineMeshVertexOutput(air::OutputMeshData{.user = input.name, .type = type, .index = index});
      bool written = input.reg < max_output_register && input.reg < pShaderInternal->gs_output_reg_masks.size() &&
                     (pShaderInternal->gs_output_reg_masks[input.reg] & input.mask);
      if (written) {
        gs_output_handlers.push_back([=, reg = input.reg, mask = input.mask](MeshOutputContext &output) -> IREffect {
          return pop_mesh_output_vertex_data(reg, mask, index, output.vertex_id, type);
        });
      } else {
        gs_output_handlers.push_back([=](MeshOutputContext &output) -> IREffect {
          return pop_mesh_output_vertex_data_zero(index, output.vertex_id, type);
        });
      }
    }
  }
"""),
])

# 7. d3d11: the GS variant depends on the pixel shader
edit("d3d11/d3d11_shader.hpp", [
    ("""struct ShaderVariantGeometry {
  using this_type = ShaderVariantGeometry;
  ManagedShader vertex_shader_handle;
  bool strip_topology;
  bool operator==(const this_type &rhs) const {
    return vertex_shader_handle == rhs.vertex_shader_handle &&
           strip_topology == rhs.strip_topology;
  }
};""",
     """struct ShaderVariantGeometry {
  using this_type = ShaderVariantGeometry;
  ManagedShader vertex_shader_handle;
  /* nullptr when rasterization is disabled */
  ManagedShader pixel_shader_handle;
  bool strip_topology;
  bool operator==(const this_type &rhs) const {
    return vertex_shader_handle == rhs.vertex_shader_handle &&
           pixel_shader_handle == rhs.pixel_shader_handle &&
           strip_topology == rhs.strip_topology;
  }
};"""),
])

edit("d3d11/d3d11_pipeline_gs.cpp", [
    ("""      ShaderVariantGeometry{pDesc->VertexShader, pDesc->GSStripTopology});""",
     """      ShaderVariantGeometry{pDesc->VertexShader, pDesc->PixelShader, pDesc->GSStripTopology});"""),
])

s = open("d3d11/d3d11_shader.cpp").read()
start = s.index("                    ShaderVariantGeometry variant) {")
part = s[start:]
reps = [
    ("""  h.update(variant.vertex_shader_handle->sha1());
  h.update(variant.strip_topology);""",
     """  h.update(variant.vertex_shader_handle->sha1());
  h.update(variant.strip_topology);
  if (variant.pixel_shader_handle)
    h.update(variant.pixel_shader_handle->sha1());"""),
    ("""    SM50_SHADER_PSO_GEOMETRY_SHADER_DATA geometry;
    geometry.type = SM50_SHADER_PSO_GEOMETRY_SHADER;
    geometry.next = common;
    geometry.strip_topology = variant.strip_topology;
""",
     """    SM50_SHADER_PSO_PIXEL_SHADER_INPUT_DATA pixel_input;
    pixel_input.type = SM50_SHADER_PSO_PIXEL_SHADER_INPUT;
    pixel_input.next = common;
    pixel_input.pixel_shader = variant.pixel_shader_handle ? variant.pixel_shader_handle->handle() : sm50_shader_t{};

    SM50_SHADER_PSO_GEOMETRY_SHADER_DATA geometry;
    geometry.type = SM50_SHADER_PSO_GEOMETRY_SHADER;
    geometry.next = variant.pixel_shader_handle ? (void *)&pixel_input : (void *)common;
    geometry.strip_topology = variant.strip_topology;
"""),
]
for a, b in reps:
    assert part.count(a) >= 1, a[:60]
    part = part.replace(a, b, 1)
open("d3d11/d3d11_shader.cpp", "w").write(s[:start] + part)
print("ok")
