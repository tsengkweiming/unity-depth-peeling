using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

public struct InstanceData
{
    public Vector3 Position;
    public Vector3 Rotation;
    public Vector3 Scale;
    public Color Color;
}

[System.Serializable]
public class InstanceProp
{
    public Mesh Mesh;
    public Texture2D Texture;
    [Range(0f, 1f)] public float Alpha;
    public float Scale;
}
public class Instance : MonoBehaviour
{
    [SerializeField] private InstanceProp[] _instanceProps;
    [SerializeField] [Range(0, 20)] private float _size;
    [SerializeField] private Vector3 _scale;
    [SerializeField] private int _count;
    [SerializeField] private Shader _shader;
    [SerializeField] private bool _zwrite;
    [SerializeField] private CompareFunction _compareFunction;
    [SerializeField] private BlendMode _srcFactor0;
    [SerializeField] private BlendMode _dstFactor0;
    [SerializeField] private BlendMode _srcFactor1;
    [SerializeField] private BlendMode _dstFactor1;
    private GraphicsBuffer[] _dataBuffers;
    private GraphicsBuffer _argsBuffer;
    private GraphicsBuffer[][] _argsBuffers;
    private CommandBuffer _commandBuffer;
    private Material[] _materials;
    private readonly uint[] _args = { 0, 0, 0, 0, 0 };
    void Start()
    {
        _materials  = new Material[_instanceProps.Length];
        for (var i = 0; i < _instanceProps.Length; i++)
        {
            _materials[i] = new Material(_shader);
        }
        InitBuffer();
    }

    void InitBuffer()
    {
        ReleaseBuffer();
        _dataBuffers  = new GraphicsBuffer[_instanceProps.Length];
        for (var i = 0; i < _instanceProps.Length; i++)
        {
            _dataBuffers[i] = new GraphicsBuffer(GraphicsBuffer.Target.Structured, _count, Marshal.SizeOf<InstanceData>());
            var instanceDatas = new InstanceData[_count];
            for (var j = 0; j < _count; j++)
            {
                instanceDatas[j].Position = Random.insideUnitSphere * _size + transform.position;
                instanceDatas[j].Rotation = Random.insideUnitSphere;
                instanceDatas[j].Scale = _scale;
                instanceDatas[j].Color = Random.ColorHSV();
            }
            _dataBuffers[i].SetData(instanceDatas);
        }

        InitArgsBuffers();
    }
    
    void InitArgsBuffers()
    {
        _argsBuffers = new GraphicsBuffer[_instanceProps.Length][];
        for (int i = 0; i < _instanceProps.Length; i++)
        {
            var mesh = _instanceProps[i].Mesh;
            _argsBuffers[i] = new GraphicsBuffer[mesh.subMeshCount];

            for (int sm = 0; sm < mesh.subMeshCount; sm++)
            {
                _argsBuffers[i][sm] =
                    new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments, _args.Length, sizeof(uint));
            }
        }
    }

    public void UpdateCommandBuffer(RenderTexture color0, RenderTexture color1, RenderTexture depthRT, 
        Color? backgroundColor = null, RTClearFlags clearFlags = RTClearFlags.Color | RTClearFlags.Depth)
    {
        _commandBuffer ??= new CommandBuffer { name = "Renderer" };
        _commandBuffer.Clear();
        var colorIds = new RenderTargetIdentifier[] { new (color0.colorBuffer), new (color1.colorBuffer) };
        var depthId = new RenderTargetIdentifier(depthRT.depthBuffer);
        _commandBuffer.SetRenderTarget(colorIds, depthId);
        var clearColor = backgroundColor ?? Color.clear;
        _commandBuffer.ClearRenderTarget(clearFlags, clearColor, 1, 0);

        for (var i = 0; i < _instanceProps.Length; i++)
        {
            _materials[i].SetFloat("_ZWrite", _zwrite ? 1 : 0);
            _materials[i].SetFloat("_ZTest", (int)_compareFunction);
            _materials[i].SetFloat("_SrcFactor0", (int)_srcFactor0);
            _materials[i].SetFloat("_DstFactor0", (int)_dstFactor0);
            _materials[i].SetFloat("_SrcFactor1", (int)_srcFactor1);
            _materials[i].SetFloat("_DstFactor1", (int)_dstFactor1);
            _materials[i].SetFloat("_Scale", _instanceProps[i].Scale);
            _materials[i].SetFloat("_Alpha", _instanceProps[i].Alpha);
            _materials[i].SetTexture("_MainTex", _instanceProps[i].Texture);
            _materials[i].SetBuffer("_InstanceBuffer", _dataBuffers[i]);

            var mesh = _instanceProps[i].Mesh;
            for (int sm = 0; sm < mesh.subMeshCount; sm++)
            {
                var smInfo = mesh.GetSubMesh(sm);
                // 0 == number of triangle indices, 1 == population, others are only relevant if drawing submeshes.
                _args[0] = (uint)smInfo.indexCount;
                _args[1] = (uint)_count;
                _args[2] = (uint)smInfo.indexStart;
                _args[3] = (uint)smInfo.baseVertex;
                _argsBuffers[i][sm].SetData(_args);
                _commandBuffer.DrawMeshInstancedIndirect(mesh, sm, _materials[i], -1, _argsBuffers[i][sm]);
            }
        }
    }

    public void ExecuteCommandBuffer()
    {
        Graphics.ExecuteCommandBuffer(_commandBuffer);
    }
    private void RemoveCommandBuffer()
    {
        _commandBuffer?.Release();
        _commandBuffer = null;
    }
    
    void ReleaseBuffer()
    {
        if (_dataBuffers != null)
        {
            for (int i = 0; i < _dataBuffers.Length; i++)
            {
                _dataBuffers[i]?.Release();
                _dataBuffers[i] = null;
            }
        }
        if (_argsBuffers != null)
        {
            for (int i = 0; i < _argsBuffers.Length; i++)
            {
                for (int j = 0; j < _argsBuffers[i].Length; j++)
                {
                    _argsBuffers[i][j]?.Release();
                    _argsBuffers[i][j] = null;
                }
            }
        }
        _argsBuffer?.Release();
        _argsBuffer = null;
    }
    
    void DeleteMaterial(Material material)
    {
        if (material != null)
        {
            if (Application.isEditor)
                DestroyImmediate(material);
            else
                Destroy(material);
        }
    }
    
    private void OnDestroy()
    {
        RemoveCommandBuffer();
        
        ReleaseBuffer();
        if (_materials != null)
        {
            for (int i = 0; i < _materials.Length; i++)
            {
                DeleteMaterial(_materials[i]);
            }
        }
    }
}
