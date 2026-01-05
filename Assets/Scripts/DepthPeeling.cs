using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public class DepthPeeling : MonoBehaviour
{
    [SerializeField] [Range(2, 8)] private int _layers;
    [SerializeField] [Range(0, 4)] private int _lod;
    [SerializeField] private Instance _instance;
    [SerializeField] private Shader _compositeShader;
    [SerializeField] private bool _enable;
    [SerializeField] private BlendMode _srcFactor;
    [SerializeField] private BlendMode _dstFactor;
    private Material _compositeMaterial;
    private Camera _camera;
    private CommandBuffer _commandBuffer;
    [SerializeField] private RenderTexture _colorTexture = null;
    [SerializeField] private RenderTexture[] _depthTextures = null;
    [SerializeField] private RenderTexture[] _colorTexs = null;
    
    // Start is called before the first frame update
    void Start()
    {
        _compositeMaterial = new Material(_compositeShader);
        _camera = Camera.main;
        _depthTextures = new RenderTexture[2];
    }

    void CreateTexture()
    {
        var lod = 1 << _lod;
        _colorTexture = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 24, RenderTextureFormat.ARGB32);
        _camera.clearFlags = CameraClearFlags.Skybox;
        _camera.targetTexture = _colorTexture;
        // _camera.Render();
        _camera.targetTexture = null;
        _depthTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32);
        _depthTextures[1] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32);
        
        if(_colorTexs == null || _layers != _colorTexs.Length)
            _colorTexs = new RenderTexture[_layers];
        _colorTexs[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
    }

    public void ClearBuffer(RenderTexture rt, Color? clearColor = null)
    {
        Color c = clearColor.HasValue ? clearColor.Value : new Color(0, 0, 0, 0);
        RenderTexture temp = RenderTexture.active;
        Graphics.SetRenderTarget(rt);
        GL.Clear(false, true, c);
        Graphics.SetRenderTarget(temp);
    }
    
    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        CreateTexture();
        if (!_enable)
        {
            Shader.DisableKeyword("DepthPeeling");
            _instance.UpdateCommandBuffer(_colorTexs[0], _depthTextures[0], _colorTexture, null, RTClearFlags.None);
            _instance.ExecuteCommandBuffer();
            _instance.RemoveCommandBuffer();
            Graphics.Blit(_colorTexs[0], destination);
            ReleaseRenderTextures();
            return;
        }

        // First iteration to render the scene as normal
        Shader.DisableKeyword("DepthPeeling");
        _instance.UpdateCommandBuffer(_colorTexs[0], _depthTextures[0], _colorTexture, null, RTClearFlags.None);
        _instance.ExecuteCommandBuffer();
        _instance.RemoveCommandBuffer();
        
        var lod = 1 << _lod;
        // Peel away the depth
        for (int i = 1; i < _layers; i++)
        {
            _colorTexs[i] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            Shader.EnableKeyword("DepthPeeling");
            Shader.SetGlobalTexture("_PrevDepthTex", _depthTextures[1 - i%2]);
            _instance.UpdateCommandBuffer(_colorTexs[i], _depthTextures[i%2], _colorTexture);
            _instance.ExecuteCommandBuffer();
            _instance.RemoveCommandBuffer();
        }

        // Blend all the layers
        _compositeMaterial.SetFloat("_SrcFactor", (int)_srcFactor);
        _compositeMaterial.SetFloat("_DstFactor", (int)_dstFactor);
        RenderTexture colorAccumTex = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
        Graphics.Blit(_colorTexture, colorAccumTex);
        for (int i = _layers - 1; i >= 0; i--) {
            RenderTexture tmpAccumTex = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            _compositeMaterial.SetTexture("_LayerTex", _colorTexs[i]);
            Graphics.Blit(colorAccumTex, tmpAccumTex, _compositeMaterial, 1);
            RenderTexture.ReleaseTemporary(colorAccumTex);
            colorAccumTex = tmpAccumTex;
        }
        
        Graphics.Blit(colorAccumTex, destination);
        RenderTexture.ReleaseTemporary(colorAccumTex);
        ReleaseRenderTextures();
    }

    void ReleaseRenderTextures()
    {
        RenderTexture.ReleaseTemporary(_colorTexture);
        RenderTexture.ReleaseTemporary(_depthTextures[0]);
        RenderTexture.ReleaseTemporary(_depthTextures[1]);
        
        for (int i = 0; i < _layers; i++) 
        {
            if(_colorTexs.Length > i && _colorTexs[i] != null)
                RenderTexture.ReleaseTemporary(_colorTexs[i]);
        }
        _colorTexs = null;
    }
    
    private void OnDestroy()
    {
        if (_compositeMaterial != null)
        {
            if (Application.isEditor)
                DestroyImmediate(_compositeMaterial);
            else
                Destroy(_compositeMaterial);
            _compositeMaterial = null;
        }
        
        _commandBuffer?.Release();
        _commandBuffer = null;
        ReleaseRenderTextures();
    }
}
