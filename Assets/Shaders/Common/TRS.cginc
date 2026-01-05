
float ConvertDegToRad(float degrees)
{
    return (3.1415 / 180.0) * degrees;
}

float4x4 TransformationMatrix(float3 pos)
{
    return float4x4(1, 0, 0, pos.x,
					0, 1, 0, pos.y,
					0, 0, 1, pos.z,
					0, 0, 0, 1);
}

float4x4 RotationMatrix(float3 anglesDeg)
{
    float3 radian = float3(ConvertDegToRad(anglesDeg.x), ConvertDegToRad(anglesDeg.y), ConvertDegToRad(anglesDeg.z));

    float4x4 rotationX = float4x4(1.0, 0.0, 0.0, 0.0,
                                  0.0, cos(radian.x), -sin(radian.x), 0.0,
                                  0.0, sin(radian.x), cos(radian.x), 0.0,
                                  0.0, 0.0, 0.0, 1.0);

    float4x4 rotationY = float4x4(cos(radian.y), 0.0, sin(radian.y), 0.0,
                                  0.0, 1.0, 0.0, 0.0,
                                  -sin(radian.y), 0.0, cos(radian.y), 0.0,
                                  0.0, 0.0, 0.0, 1.0);

    float4x4 rotationZ = float4x4(cos(radian.z), -sin(radian.z), 0.0, 0.0,
                                  sin(radian.z), cos(radian.z), 0.0, 0.0,
                                  0.0, 0.0, 1.0, 0.0,
                                  0.0, 0.0, 0.0, 1.0);

    return mul(mul(rotationX, rotationY), rotationZ);
}

float4x4 ScaleMatrix(float3 scale)
{
    return float4x4(scale.x,     0.0,     0.0, 0.0,
                        0.0, scale.y,     0.0, 0.0,
                        0.0,     0.0, scale.z, 0.0,
                        0.0,     0.0,     0.0, 1.0);
}

float4x4 TBNRotate(float3 uv)
{
    float3 n = normalize(float3(uv.x, uv.y, 1));
    float3 t = float3(1, 0, 0);
    float3 b = normalize(cross(n, t));
    t = cross(b, n);
    return float4x4(t.x, b.x, n.x, 0,
		            t.y, b.y, n.y, 0,
		            t.z, b.z, n.z, 0,
		              0,   0,   0, 1);
}

float4x4 TRS(float3 pos, float3 rotationAng, float3 scale)
{
    float4x4 translation = TransformationMatrix(pos);
    float4x4 rotation = RotationMatrix(rotationAng);
    return mul(mul(translation, rotation), ScaleMatrix(scale));
}

float4x4 TRS(float3 pos, float3 rotationAng, float3 scale, float3 normal)
{
    float4x4 translation = TransformationMatrix(pos);
    float4x4 rotation = mul(TBNRotate(normal), RotationMatrix(rotationAng));
    return mul(mul(translation, rotation), ScaleMatrix(scale));
}

float4x4 TnRS(float3 pos, float3 rotationAng, float3 initNormal, float3 normal, float3 scale)
{
    float4x4 translation = TransformationMatrix(pos);
    float4x4 rotation = mul(TBNRotate(normal), mul(TBNRotate(initNormal), RotationMatrix(rotationAng))); //TBNRotate(normal); //TBNRotate(normal);// 
    return mul(mul(translation, rotation), ScaleMatrix(scale));
}