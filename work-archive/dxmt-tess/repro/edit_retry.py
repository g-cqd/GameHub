import os
os.chdir("/Volumes/ExT2/GameHub/work/dxmt-tess/src-wt/src/d3d11")
def edit(p, reps):
    s = open(p).read()
    for a, b in reps:
        assert s.count(a) == 1, (p, a[:70])
        s = s.replace(a, b)
    open(p, "w").write(s)

edit("d3d11_pipeline.hpp", [(
"""#include "util_hash.hpp"
""",
"""#include "util_hash.hpp"
#include "log/log.hpp"
#include <cstring>

namespace dxmt {

/**
Creates a render pipeline state and retries when the connection to the Metal compiler
service was interrupted. On M1/M2 GPUs the service crashes on some mesh pipelines (a
pixel shader reading a varying the geometry shader does not write; Crysis 3). Every
pipeline compiling at that moment then fails with XPC_ERROR_CONNECTION_INTERRUPTED,
valid ones included; those compile once the service has restarted.
*/
template <typename Info>
WMT::Reference<WMT::RenderPipelineState>
NewRenderPipelineStateRetryingInterrupted(WMT::Device device, const Info &info, WMT::Reference<WMT::Error> &err) {
  constexpr unsigned kMaxRetries = 2;
  auto pso = device.newRenderPipelineState(info, err);
  for (unsigned retry = 1; !pso && err && retry <= kMaxRetries; retry++) {
    auto description = err.description();
    const char *text = description.getUTF8String();
    if (!text || !std::strstr(text, "XPC_ERROR_CONNECTION_INTERRUPTED"))
      break;
    WARN("Metal compiler service connection interrupted, retrying pipeline creation (", retry, "/", kMaxRetries, ")");
    pso = device.newRenderPipelineState(info, err);
  }
  return pso;
}

} // namespace dxmt
""")])

edit("d3d11_pipeline.cpp", [(
"    state_ = device_->GetMTLDevice().newRenderPipelineState(info, err);",
"    state_ = NewRenderPipelineStateRetryingInterrupted(device_->GetMTLDevice(), info, err);")])
edit("d3d11_pipeline_gs.cpp", [(
"    state_mesh_ = device_->GetMTLDevice().newRenderPipelineState(info, err);",
"    state_mesh_ = NewRenderPipelineStateRetryingInterrupted(device_->GetMTLDevice(), info, err);")])
edit("d3d11_pipeline_ts.cpp", [(
"""      state_rasterization_ =
          device_->GetMTLDevice().newRenderPipelineState(info, err);""",
"""      state_rasterization_ = NewRenderPipelineStateRetryingInterrupted(device_->GetMTLDevice(), info, err);""")])
print("ok")
