import os
os.chdir("/Volumes/ExT2/GameHub/work/dxmt-tess/src-wt/src")
def edit(p, reps):
    s = open(p).read()
    for a, b in reps:
        assert s.count(a) == 1, (p, a[:70])
        s = s.replace(a, b)
    open(p, "w").write(s)

edit("dxmt/dxmt_context.hpp", [
("""struct ComputeEncoderData : EncoderData {
  wmtcmd_compute_nop cmd_head;
  wmtcmd_base *cmd_tail;
  WMT::Buffer allocated_argbuf;
  uint64_t allocated_argbuf_offset;
  void *allocated_argbuf_mapping;
};""",
"""struct ComputeEncoderData : EncoderData {
  wmtcmd_compute_nop cmd_head;
  wmtcmd_base *cmd_tail;
  WMT::Buffer allocated_argbuf;
  uint64_t allocated_argbuf_offset;
  void *allocated_argbuf_mapping;
  /**
  The compute pipeline of the last set-pipeline command of this encoder failed to
  compile; dispatches are dropped until one is set successfully (see
  RenderEncoderData::pipeline_failed).
  */
  bool pipeline_failed = 0;
};"""),
("""  currentRenderEncoder() {
    assert(encoder_current && encoder_current->type == EncoderType::Render);
    return static_cast<RenderEncoderData *>(encoder_current);
  }
""",
"""  currentRenderEncoder() {
    assert(encoder_current && encoder_current->type == EncoderType::Render);
    return static_cast<RenderEncoderData *>(encoder_current);
  }

  ComputeEncoderData *
  currentComputeEncoder() {
    assert(encoder_current && encoder_current->type == EncoderType::Compute);
    return static_cast<ComputeEncoderData *>(encoder_current);
  }
"""),
])

edit("d3d11/d3d11_context_impl.cpp", [
("""    EmitOP([ThreadGroupCountX, ThreadGroupCountY, ThreadGroupCountZ](ArgumentEncodingContext &enc) {
      enc.resolveComputePassBarrier();""",
"""    EmitOP([ThreadGroupCountX, ThreadGroupCountY, ThreadGroupCountZ](ArgumentEncodingContext &enc) {
      if (enc.currentComputeEncoder()->pipeline_failed)
        return;
      enc.resolveComputePassBarrier();"""),
("""      EmitOP([AlignedByteOffsetForArgs, ArgBuffer = bindable->buffer()](ArgumentEncodingContext &enc) {
        auto [buffer, buffer_offset] = enc.access(ArgBuffer, AlignedByteOffsetForArgs, 12, ResourceAccess::Read);""",
"""      EmitOP([AlignedByteOffsetForArgs, ArgBuffer = bindable->buffer()](ArgumentEncodingContext &enc) {
        if (enc.currentComputeEncoder()->pipeline_failed)
          return;
        auto [buffer, buffer_offset] = enc.access(ArgBuffer, AlignedByteOffsetForArgs, 12, ResourceAccess::Read);"""),
("""      pso->GetPipeline(&ComputePipeline); // may block
      if (!ComputePipeline.PipelineState)
        return;""",
"""      pso->GetPipeline(&ComputePipeline); // may block
      enc.currentComputeEncoder()->pipeline_failed = ComputePipeline.PipelineState == nullptr;
      if (!ComputePipeline.PipelineState) {
        static std::atomic_bool warned = false;
        if (!warned.exchange(true))
          WARN("Skipping dispatches whose compute pipeline failed to compile (see the error above)");
        return;
      }"""),
])

edit("d3d11/d3d11_pipeline.hpp", [
("""template <typename Info>
WMT::Reference<WMT::RenderPipelineState>
NewRenderPipelineStateRetryingInterrupted(WMT::Device device, const Info &info, WMT::Reference<WMT::Error> &err) {
  constexpr unsigned kMaxRetries = 2;
  auto pso = device.newRenderPipelineState(info, err);
  for (unsigned retry = 1; !pso && err && retry <= kMaxRetries; retry++) {
    if (err.description().getUTF8String().find("XPC_ERROR_CONNECTION_INTERRUPTED") == std::string::npos)
      break;
    WARN("Metal compiler service connection interrupted, retrying pipeline creation (", retry, "/", kMaxRetries, ")");
    pso = device.newRenderPipelineState(info, err);
  }
  return pso;
}""",
"""template <typename Create>
auto
CreatePipelineRetryingInterrupted(Create &&create, WMT::Reference<WMT::Error> &err) {
  constexpr unsigned kMaxRetries = 2;
  auto pso = create();
  for (unsigned retry = 1; !pso && err && retry <= kMaxRetries; retry++) {
    if (err.description().getUTF8String().find("XPC_ERROR_CONNECTION_INTERRUPTED") == std::string::npos)
      break;
    WARN("Metal compiler service connection interrupted, retrying pipeline creation (", retry, "/", kMaxRetries, ")");
    pso = create();
  }
  return pso;
}

template <typename Info>
WMT::Reference<WMT::RenderPipelineState>
NewRenderPipelineStateRetryingInterrupted(WMT::Device device, const Info &info, WMT::Reference<WMT::Error> &err) {
  return CreatePipelineRetryingInterrupted([&] { return device.newRenderPipelineState(info, err); }, err);
}"""),
])
edit("d3d11/d3d11_pipeline.cpp", [
("    state_ = device_->GetMTLDevice().newComputePipelineState(info, err);",
 """    auto device = device_->GetMTLDevice();
    state_ = CreatePipelineRetryingInterrupted([&] { return device.newComputePipelineState(info, err); }, err);"""),
])
print("ok")
