using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(fileName = "ZHCustomRenderPipelineAsset", menuName = "ZHCustomRenderPipelineAsset")]
public class ZHCustomRenderPipelineAsset : RenderPipelineAsset
{
    public bool useSRPBatcher = true;
    public bool useGPUInstancing = true;
    public bool useDynamicBatching = true;

    public float maxShadowDistance = 50;

    protected override RenderPipeline CreatePipeline()
    {
        return ZHCustomRenderPipeline.CreateRenderPipeline(this);
    }
}
