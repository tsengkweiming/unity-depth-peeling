using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public enum DepthPeelingType { Front2Back, DualPeeling }
public enum ComopsiteType { AlphaBlend, Additive }
public class DepthPeeling : MonoBehaviour
{
    [SerializeField] private DepthPeelingType _depthPeelingType;
    [SerializeField] private ComopsiteType _comopsiteType;
    [SerializeField] [Range(1, 50)] private int _layers;
    [SerializeField] [Range(0, 4)] private int _lod1;
    [SerializeField] [Range(0, 4)] private int _lod2;
    [SerializeField] private bool _enable;
    [SerializeField] private Instance _instance;
    [SerializeField] private Shader _compositeShader;
    private Material _compositeMaterial;
    private RenderTexture _allTexture = null;
    private RenderTexture[] _depthTextures = null;
    private RenderTexture[] _colorTextures = null;
    
    // Start is called before the first frame update
    void Start()
    {
        _compositeMaterial = new Material(_compositeShader);
        _depthTextures = new RenderTexture[2];
    }

    void CreateTexture()
    {
        var lod = 1 << _lod1;
        _allTexture = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 24, RenderTextureFormat.ARGB32);
        switch (_depthPeelingType)
        {
            case DepthPeelingType.Front2Back:
                default:
                _depthTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32);
                _depthTextures[1] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32);
                
                if(_colorTextures == null || _layers != _colorTextures.Length)
                    _colorTextures = new RenderTexture[_layers];
                _colorTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
                break;
            case DepthPeelingType.DualPeeling:
                _depthTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.RGFloat);
                _depthTextures[1] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.RGFloat);
                
                _colorTextures ??= new RenderTexture[2];
                _colorTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
                _colorTextures[1] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
                break;
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        _instance.DepthPeelingType = _depthPeelingType;
        CreateTexture();
        Shader.DisableKeyword("FRONT_BACK");
        Shader.DisableKeyword("DUAL_PEELING");
        RenderTargetIdentifier[] colorIds = { new (_depthTextures[0].colorBuffer), new (_colorTextures[0].colorBuffer)};
        RenderTargetIdentifier depthId = new RenderTargetIdentifier(_allTexture.depthBuffer);
        if (!_enable)
        {
            _instance.UpdateCommandBuffer(colorIds, depthId, Color.clear, Color.clear);
            _instance.ExecuteCommandBuffer();
            Graphics.Blit(_colorTextures[0], destination);
            ReleaseRenderTextures();
            return;
        }

        // First iteration to render the scene as normal
        Color? clearColor = new Color(1.0f, 1.0f, 1.0f, 0.0f);
        Color? depthClearColor = clearColor;
        RTClearFlags clearFlags = RTClearFlags.ColorDepth;
        var lod1 = 1 << _lod1;
        var lod2 = 1 << _lod2;
        switch (_depthPeelingType)
        {
            case DepthPeelingType.Front2Back:
            default:
                _instance.UpdateCommandBuffer(colorIds, depthId, clearColor, depthClearColor);
                _instance.ExecuteCommandBuffer();
                break;
            case DepthPeelingType.DualPeeling:
                Shader.EnableKeyword("DUAL_PEELING");
                colorIds = new RenderTargetIdentifier[] { new (_depthTextures[0].colorBuffer), new (_colorTextures[0].colorBuffer), 
                    new (_colorTextures[1].colorBuffer) };
                clearColor = Color.clear;
                depthClearColor = new Color(-1e20f, -1e20f, 0.0f, 0.0f);
                _instance.UpdateCommandBuffer(colorIds, depthId, clearColor, depthClearColor, clearFlags, 1);
                _instance.ExecuteCommandBuffer();
                break;
        }
        
        // Peel away the depth
        for (int i = 1; i < _layers; i++)
        {
            switch (_depthPeelingType)
            {
                case DepthPeelingType.Front2Back:
                default:
                    _colorTextures[i] = RenderTexture.GetTemporary(Screen.width / lod1, Screen.height / lod1, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
                    Shader.EnableKeyword("FRONT_BACK");
                    colorIds = new RenderTargetIdentifier[] { new (_depthTextures[i%2].colorBuffer) , new (_colorTextures[i].colorBuffer)}; 
                    // try maybe dont clear depth
                    break;
                case DepthPeelingType.DualPeeling:
                    Shader.EnableKeyword("DUAL_PEELING");
                    clearColor = null; // don't clear accumulate color
                    depthClearColor = new Color(-1e20f, -1e20f, 0.0f, 0.0f); // but clear the depth to initial
                    colorIds = new RenderTargetIdentifier[] { new (_depthTextures[i%2].colorBuffer), new (_colorTextures[0].colorBuffer), 
                        new (_colorTextures[1].colorBuffer) };
                    break;
            }

            Shader.SetGlobalTexture("_PrevDepthTex", _depthTextures[1 - i%2]);
            _instance.UpdateCommandBuffer(colorIds, depthId, clearColor, depthClearColor, clearFlags);
            _instance.ExecuteCommandBuffer();
        }

        // Blend all the layers
        switch (_comopsiteType)
        {
            case ComopsiteType.AlphaBlend:
            default:
                _compositeMaterial.DisableKeyword("ADDITIVE");
                _compositeMaterial.EnableKeyword("ALPHA_BLEND");
                break;
            case ComopsiteType.Additive:
                _compositeMaterial.DisableKeyword("ALPHA_BLEND");
                _compositeMaterial.EnableKeyword("ADDITIVE");
                break;
        }
        switch (_depthPeelingType)
        {
            case DepthPeelingType.Front2Back:
            default:
                RenderTexture colorAccumTex = RenderTexture.GetTemporary(Screen.width / lod2, Screen.height / lod2, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
                Graphics.Blit(_allTexture, colorAccumTex);
                for (int i = _layers - 1; i >= 0; i--) {
                    RenderTexture tmpAccumTex = RenderTexture.GetTemporary(Screen.width / lod2, Screen.height / lod2, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
                    _compositeMaterial.SetTexture("_LayerTex", _colorTextures[i]);
                    Graphics.Blit(colorAccumTex, tmpAccumTex, _compositeMaterial, 1);
                    RenderTexture.ReleaseTemporary(colorAccumTex);
                    colorAccumTex = tmpAccumTex;
                }
                Graphics.Blit(colorAccumTex, destination);
                RenderTexture.ReleaseTemporary(colorAccumTex);
                break;
            case DepthPeelingType.DualPeeling:
                
                _compositeMaterial.SetTexture("_FrontTex", _colorTextures[0]);
                _compositeMaterial.SetTexture("_BackTex", _colorTextures[1]);
                Graphics.Blit(null, destination, _compositeMaterial, 2);
                
                break;
        }
        ReleaseRenderTextures();
    }

    void ReleaseRenderTextures()
    {
        RenderTexture.ReleaseTemporary(_allTexture);
        for (int i = 0; i < _depthTextures.Length; i++)
        {
            if(_depthTextures.Length > i && _depthTextures[i] != null)
                RenderTexture.ReleaseTemporary(_depthTextures[i]);
        }

        foreach (var colotTex in _colorTextures)
        {
            if(colotTex != null)
                RenderTexture.ReleaseTemporary(colotTex);
        }
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
        
        ReleaseRenderTextures();
        _colorTextures = null;
        _depthTextures = null;
    }
}