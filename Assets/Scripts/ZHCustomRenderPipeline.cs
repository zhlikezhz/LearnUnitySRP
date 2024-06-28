using UnityEngine;
using System.Collections;
using System.Collections.Generic;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;
using System.ComponentModel.Design.Serialization;

public class ZHCustomRenderPipeline : RenderPipeline
{
    public static ZHCustomRenderPipeline CreateRenderPipeline(ZHCustomRenderPipelineAsset settings)
    {
        return new ZHCustomRenderPipeline(settings);
    }

    ZHCustomRenderPipelineAsset Settings;
    public ZHCustomRenderPipeline(ZHCustomRenderPipelineAsset settings)
    {
        Settings = settings;
        //配置SRP Batch
        GraphicsSettings.useScriptableRenderPipelineBatching = Settings.useSRPBatcher;
        //设置光源颜色为线性空间
        GraphicsSettings.lightsUseLinearIntensity = true;
    }

    CommandBuffer buffer;
    protected override void Render(ScriptableRenderContext context, Camera[] cameras)
    {
        for(int i = 0; i < cameras.Length; i++)
        {
            Camera camera = cameras[i];
            buffer = new CommandBuffer{ name = camera.name };
            RenderCamera(context, camera);
        }
    }

    void RenderCamera(ScriptableRenderContext context, Camera camera)
    {
        buffer.BeginSample(camera.name);
        ExecuteCommandBuffer(context, buffer);
        if (camera.TryGetCullingParameters(out var param))
        {
            param.shadowDistance = Settings.maxShadowDistance;
            CullingResults results = context.Cull(ref param);

            //设置光照数据
            SetupLight(context, camera, results);
            //设置阴影数据
            int shadowID = SetupShadow(context, camera, results);

            context.SetupCameraProperties(camera);
            bool isClearColor = camera.clearFlags == CameraClearFlags.Color;
            buffer.ClearRenderTarget(camera.clearFlags <= CameraClearFlags.Depth, isClearColor, isClearColor ? camera.backgroundColor.linear : Color.clear);
            ExecuteCommandBuffer(context, buffer);

            //渲染不透明物体
            SortingSettings sortSettings = new SortingSettings(camera);
            sortSettings.criteria = SortingCriteria.CommonOpaque;
            DrawingSettings drawSettings = new DrawingSettings(new ShaderTagId("SRPDefaultUnlit"), sortSettings);
            drawSettings.enableDynamicBatching = Settings.useDynamicBatching;
            drawSettings.enableInstancing = Settings.useGPUInstancing;
            FilteringSettings filterSettings = new FilteringSettings(RenderQueueRange.opaque);
            context.DrawRenderers(results, ref drawSettings, ref filterSettings);

            //渲染天空盒
            if (camera.clearFlags == CameraClearFlags.Skybox)
            {
                //context.DrawSkybox(camera);
            }

            //渲染透明物体
            sortSettings.criteria = SortingCriteria.CommonTransparent;
            drawSettings.sortingSettings = sortSettings;
            filterSettings.renderQueueRange = RenderQueueRange.transparent;
            context.DrawRenderers(results, ref drawSettings, ref filterSettings);

            buffer.ReleaseTemporaryRT(shadowID);
            ExecuteCommandBuffer(context, buffer);
        }
        buffer.EndSample(camera.name);
        ExecuteCommandBuffer(context, buffer);
        context.Submit();
    }

    private readonly static string c_strMainLightColorName = "_LightColor0";
    private readonly static string c_strMainLightWorldSpacePos = "_WorldSpaceLightPos0";
    void SetupLight(ScriptableRenderContext context, Camera camera, CullingResults results)
    {
        VisibleLight mainLight = new VisibleLight();
        for (int i = 0; i < results.visibleLights.Length; i++)
        {
            VisibleLight light = results.visibleLights[i];
            if (light.lightType == LightType.Directional)
            {
                if (mainLight.light == null)
                {
                    mainLight = light;
                }
                else if (light.light.intensity > mainLight.light.intensity)
                {
                    mainLight = light;
                }
            }
        }

        if (mainLight.light != null)
        {
            Shader.SetGlobalColor(c_strMainLightColorName, mainLight.finalColor);
            Shader.SetGlobalVector(c_strMainLightWorldSpacePos, -mainLight.light.transform.forward);
        }
    }

    Matrix4x4 shadowMatrix;
    private readonly static string c_strShadowTex = "_ShadowMapTexture";
    private readonly static string c_strShadowMatric = "_ShadowMatric";
    int SetupShadow(ScriptableRenderContext context, Camera camera, CullingResults results)
    {
        int id = Shader.PropertyToID(c_strShadowTex);
        buffer.GetTemporaryRT(id, Screen.width, Screen.height, 32, FilterMode.Bilinear, RenderTextureFormat.Shadowmap);
        buffer.SetRenderTarget(id, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
        buffer.ClearRenderTarget(true, false, Color.clear);
        ExecuteCommandBuffer(context, buffer);

        for(int index = 0; index < results.visibleLights.Length; index++)
        {
            VisibleLight light = results.visibleLights[index];
            if (light.light.shadows != LightShadows.None && light.light.shadowStrength > 0f
            && results.GetShadowCasterBounds(index, out Bounds b))
            {
                ShadowDrawingSettings settings = new ShadowDrawingSettings(results, index);
                results.ComputeDirectionalShadowMatricesAndCullingPrimitives(index, 0, 1, Vector3.zero, 1024, 0f, out var viewMatrix, out var projMatrix, out var splitData);
                shadowMatrix = ConvertToAtlasMatrix(projMatrix * viewMatrix, Vector2.zero, 1.0f);
                buffer.SetViewProjectionMatrices(viewMatrix, projMatrix);
                ExecuteCommandBuffer(context, buffer);
                settings.splitData = splitData;
                context.DrawShadows(ref settings);
                Shader.SetGlobalMatrix(c_strShadowMatric, shadowMatrix);
                break;
            }
        }
        return id;
    }

    Matrix4x4 ConvertToAtlasMatrix(Matrix4x4 m, Vector2 offset, float scale)
    {
        //如果使用反向Z缓冲区，为Z取反
        if (SystemInfo.usesReversedZBuffer)
        {
            m.m20 = -m.m20;
            m.m21 = -m.m21;
            m.m22 = -m.m22;
            m.m23 = -m.m23;
        }
        //光源裁剪空间坐标范围为[-1,1]，而纹理坐标和深度都是[0,1]，因此，我们将裁剪空间坐标转化到[0,1]内
        //然后将[0,1]下的x,y偏移到光源对应的Tile上
        m.m00 = (0.5f * (m.m00 + m.m30) + offset.x * m.m30) * scale;
        m.m01 = (0.5f * (m.m01 + m.m31) + offset.x * m.m31) * scale;
        m.m02 = (0.5f * (m.m02 + m.m32) + offset.x * m.m32) * scale;
        m.m03 = (0.5f * (m.m03 + m.m33) + offset.x * m.m33) * scale;
        m.m10 = (0.5f * (m.m10 + m.m30) + offset.y * m.m30) * scale;
        m.m11 = (0.5f * (m.m11 + m.m31) + offset.y * m.m31) * scale;
        m.m12 = (0.5f * (m.m12 + m.m32) + offset.y * m.m32) * scale;
        m.m13 = (0.5f * (m.m13 + m.m33) + offset.y * m.m33) * scale;
        m.m20 = 0.5f * (m.m20 + m.m30);
        m.m21 = 0.5f * (m.m21 + m.m31);
        m.m22 = 0.5f * (m.m22 + m.m32);
        m.m23 = 0.5f * (m.m23 + m.m33);
        return m;
    }

    void ExecuteCommandBuffer(ScriptableRenderContext context, CommandBuffer buffer)
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
}
