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
    }

    void CreateTexture()
    {
        var lod = 1 << _lod1;
        _allTexture = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 24, RenderTextureFormat.ARGB32);
        switch (_depthPeelingType)
        {
            case DepthPeelingType.Front2Back:
                default:
                if(_depthTextures == null || _layers != _depthTextures.Length)
                    _depthTextures = new RenderTexture[2];
                _depthTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32);
                _depthTextures[1] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32);
                break;
            case DepthPeelingType.DualPeeling:
                if(_depthTextures == null || _layers != _depthTextures.Length)
                    _depthTextures = new RenderTexture[2];
                _depthTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.RGFloat);
                _depthTextures[1] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.RGFloat);
                break;
        }
        
        if(_colorTextures == null || _layers != _colorTextures.Length)
            _colorTextures = new RenderTexture[_layers];
        _colorTextures[0] = RenderTexture.GetTemporary(Screen.width / lod, Screen.height / lod, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        CreateTexture();
        Shader.DisableKeyword("FRONT_BACK");
        Shader.DisableKeyword("DUAL_PEELING");
        if (!_enable)
        {
            _instance.UpdateCommandBuffer(_colorTextures[0], _depthTextures[0], _allTexture, null, RTClearFlags.ColorDepth);
            _instance.ExecuteCommandBuffer();
            Graphics.Blit(_colorTextures[0], destination);
            ReleaseRenderTextures();
            return;
        }

        // First iteration to render the scene as normal
        _instance.UpdateCommandBuffer(_colorTextures[0], _depthTextures[0], _allTexture, new Color(1.0f, 1.0f, 1.0f, 0.0f));
        _instance.ExecuteCommandBuffer();
        
        var lod1 = 1 << _lod1;
        var lod2 = 1 << _lod2;
        // Peel away the depth
        for (int i = 1; i < _layers; i++)
        {
            _colorTextures[i] = RenderTexture.GetTemporary(Screen.width / lod1, Screen.height / lod1, 0, RenderTextureFormat.ARGB32, RenderTextureReadWrite.Linear);
            switch (_depthPeelingType)
            {
                case DepthPeelingType.Front2Back:
                default:
                    Shader.EnableKeyword("FRONT_BACK");
                    Shader.SetGlobalFloat("_BlendOpRGB", (int)BlendOp.Add);
                    Shader.SetGlobalFloat("_BlendOpAlpha", (int)BlendOp.Add);
                    break;
                case DepthPeelingType.DualPeeling:
                    Shader.EnableKeyword("DUAL_PEELING");
                    Shader.SetGlobalFloat("_BlendOpRGB", (int)BlendOp.Min);
                    Shader.SetGlobalFloat("_BlendOpAlpha", (int)BlendOp.Max);
                    break;
            }
            Shader.SetGlobalTexture("_PrevDepthTex", _depthTextures[1 - i%2]);
            _instance.UpdateCommandBuffer(_colorTextures[i], _depthTextures[i%2], _allTexture, new Color(1.0f, 1.0f, 1.0f, 0.0f));
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
        ReleaseRenderTextures();
    }

    void ReleaseRenderTextures()
    {
        RenderTexture.ReleaseTemporary(_allTexture);
        RenderTexture.ReleaseTemporary(_depthTextures[0]);
        RenderTexture.ReleaseTemporary(_depthTextures[1]);
        
        for (int i = 0; i < _layers; i++) 
        {
            if(_colorTextures.Length > i && _colorTextures[i] != null)
                RenderTexture.ReleaseTemporary(_colorTextures[i]);
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
    }
}