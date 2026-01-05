#ifndef _QUATERNION_INCLUDED
#define _QUATERNION_INCLUDED

#define QUATERNION_IDENTITY float4(0, 0, 0, 1)

#ifndef PI
#define PI 3.14159265359f
#endif 
#ifndef TAU
#define TAU 6.28318530718
#endif 

// Quaternion multiplication
// http://mathworld.wolfram.com/Quaternion.html
float4 qmul(float4 q1, float4 q2)
{
    return float4(
        q2.xyz * q1.w + q1.xyz * q2.w + cross(q1.xyz, q2.xyz),
        q1.w * q2.w - dot(q1.xyz, q2.xyz)
    );
}

// Vector rotation with a quaternion
// http://mathworld.wolfram.com/Quaternion.html
float3 rotate_vector(float3 v, float4 r)
{
    float4 r_c = r * float4(-1, -1, -1, 1);
    return qmul(r, qmul(float4(v, 0), r_c)).xyz;
}

// A given angle of rotation about a given axis
float4 rotate_angle_axis(float angle, float3 axis)
{
    float sn = sin(angle * 0.5);
    float cs = cos(angle * 0.5);
    return float4(axis * sn, cs);
}

// https://stackoverflow.com/questions/1171849/finding-quaternion-representing-the-rotation-from-one-vector-to-another
float4 from_to_rotation(float3 v1, float3 v2)
{
    float4 q;
    float d = dot(v1, v2);
    if (d < -0.999999)
    {
        float3 right = float3(1, 0, 0);
        float3 up = float3(0, 1, 0);
        float3 tmp = cross(right, v1);
        if (length(tmp) < 0.000001)
        {
            tmp = cross(up, v1);
        }
        tmp = normalize(tmp);
        q = rotate_angle_axis(PI, tmp);
    }
    else if (d > 0.999999) {
        q = QUATERNION_IDENTITY;
    }
    else {
        q.xyz = cross(v1, v2);
        q.w = 1 + d;
        q = normalize(q);
    }
    return q;
}

float4 q_conj(float4 q)
{
    return float4(-q.x, -q.y, -q.z, q.w);
}

// https://jp.mathworks.com/help/aeroblks/quaternioninverse.html
float4 q_inverse(float4 q)
{
    float4 conj = q_conj(q);
    return conj / (q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
}

float4 q_diff(float4 q1, float4 q2)
{
    return q2 * q_inverse(q1);
}

float4 q_look_at(float3 forward, float3 up)
{
    float3 right = normalize(cross(forward, up));
    up = normalize(cross(forward, right));

    float m00 = right.x;
    float m01 = right.y;
    float m02 = right.z;
    float m10 = up.x;
    float m11 = up.y;
    float m12 = up.z;
    float m20 = forward.x;
    float m21 = forward.y;
    float m22 = forward.z;

    float num8 = (m00 + m11) + m22;
    float4 q = QUATERNION_IDENTITY;
    if (num8 > 0.0)
    {
        float num = sqrt(num8 + 1.0);
        q.w = num * 0.5;
        num = 0.5 / num;
        q.x = (m12 - m21) * num;
        q.y = (m20 - m02) * num;
        q.z = (m01 - m10) * num;
        return q;
    }

    if ((m00 >= m11) && (m00 >= m22))
    {
        float num7 = sqrt(((1.0 + m00) - m11) - m22);
        float num4 = 0.5 / num7;
        q.x = 0.5 * num7;
        q.y = (m01 + m10) * num4;
        q.z = (m02 + m20) * num4;
        q.w = (m12 - m21) * num4;
        return q;
    }

    if (m11 > m22)
    {
        float num6 = sqrt(((1.0 + m11) - m00) - m22);
        float num3 = 0.5 / num6;
        q.x = (m10 + m01) * num3;
        q.y = 0.5 * num6;
        q.z = (m21 + m12) * num3;
        q.w = (m20 - m02) * num3;
        return q;
    }

    float num5 = sqrt(((1.0 + m22) - m00) - m11);
    float num2 = 0.5 / num5;
    q.x = (m20 + m02) * num2;
    q.y = (m21 + m12) * num2;
    q.z = 0.5 * num5;
    q.w = (m01 - m10) * num2;
    return q;
}

float4 q_slerp(in float4 a, in float4 b, float t)
{
    // if either input is zero, return the other.
    if (length(a) == 0.0)
    {
        if (length(b) == 0.0)
        {
            return QUATERNION_IDENTITY;
        }
        return b;
    }
    else if (length(b) == 0.0)
    {
        return a;
    }

    float cosHalfAngle = a.w * b.w + dot(a.xyz, b.xyz);

    if (cosHalfAngle >= 1.0 || cosHalfAngle <= -1.0)
    {
        return a;
    }
    else if (cosHalfAngle < 0.0)
    {
        b.xyz = -b.xyz;
        b.w = -b.w;
        cosHalfAngle = -cosHalfAngle;
    }

    float blendA;
    float blendB;
    if (cosHalfAngle < 0.99)
    {
        // do proper slerp for big angles
        float halfAngle = acos(cosHalfAngle);
        float sinHalfAngle = sin(halfAngle);
        float oneOverSinHalfAngle = 1.0 / sinHalfAngle;
        blendA = sin(halfAngle * (1.0 - t)) * oneOverSinHalfAngle;
        blendB = sin(halfAngle * t) * oneOverSinHalfAngle;
    }
    else
    {
        // do lerp if angle is really small.
        blendA = 1.0 - t;
        blendB = t;
    }

    float4 result = float4(blendA * a.xyz + blendB * b.xyz, blendA * a.w + blendB * b.w);
    if (length(result) > 0.0)
    {
        return normalize(result);
    }
    return QUATERNION_IDENTITY;
}

float4x4 quaternion_to_matrix(float4 quat)
{
    float4x4 m = float4x4(float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0), float4(0, 0, 0, 0));

    float x = quat.x, y = quat.y, z = quat.z, w = quat.w;
    float x2 = x + x, y2 = y + y, z2 = z + z;
    float xx = x * x2, xy = x * y2, xz = x * z2;
    float yy = y * y2, yz = y * z2, zz = z * z2;
    float wx = w * x2, wy = w * y2, wz = w * z2;

    m[0][0] = 1.0 - (yy + zz);
    m[0][1] = xy - wz;
    m[0][2] = xz + wy;

    m[1][0] = xy + wz;
    m[1][1] = 1.0 - (xx + zz);
    m[1][2] = yz - wx;

    m[2][0] = xz - wy;
    m[2][1] = yz + wx;
    m[2][2] = 1.0 - (xx + yy);

    m[3][3] = 1.0;

    return m;
}

#ifndef HALF_DEG2RAD
#define HALF_DEG2RAD 8.72664625e-3
#endif 


float4 qnormalize(float3 xyz, float w) {
    return normalize(float4(xyz, w));
}
float4 quaternion(float3 axis, float degree) {
    float rad = degree * HALF_DEG2RAD;
    axis = normalize(axis);
    return float4(axis * sin(rad), cos(rad));
}
float4 qfromto(float3 fromDir, float3 toDir) {
    fromDir = normalize(fromDir);
    toDir = normalize(toDir);
    float rad = 0.5 * acos(dot(fromDir, toDir));
    float3 axis = normalize(cross(fromDir, toDir));
    return qnormalize(axis * sin(rad), cos(rad));
}
float4 __qmultiply(float4 a, float4 b) {
    return float4(a.w * b.xyz + b.w * a.xyz + cross(a.xyz, b.xyz), a.w * b.w - dot(a.xyz, b.xyz));
}
float4 qmultiply(float4 a, float4 b) {
    return normalize(__qmultiply(a, b));
}
float3 qrotate(float4 q, float3 v) {
    return __qmultiply(__qmultiply(q, float4(v, 0)), float4(-q.xyz, q.w)).xyz;
}
float3 qrotateinv(float4 q, float3 v) {
    return __qmultiply(__qmultiply(float4(-q.xyz, q.w), float4(v, 0)), q).xyz;
}
float4x4 qmatrix(float4 q) {
    float4x4 m = {
        1.0 - 2.0 * (q.y * q.y + q.z * q.z),
        2.0 * (q.x * q.y - q.z * q.w),
        2.0 * (q.x * q.z + q.y * q.w),
        0.0,

        2.0 * (q.x * q.y + q.z * q.w),
        1.0 - 2.0 * (q.x * q.x + q.z * q.z),
        2.0 * (q.y * q.z - q.x * q.w),
        0.0,

        2.0 * (q.x * q.z - q.y * q.w),
        2.0 * (q.y * q.z + q.x * q.w),
        1.0 - 2.0 * (q.x * q.x + q.y * q.y),
        0.0,

        0, 0, 0, 1
    };
    return m;
}

// rotate vector
float3 RotateAroundX(float3 p, float angle)
{
    float s, c;
    sincos(angle, s, c);
    return float3(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

float3 RotateAroundY(float3 p, float angle)
{
    float s, c;
    sincos(angle, s, c);
    return float3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

float3 RotateAroundZ(float3 p, float angle)
{
    float s, c;
    sincos(angle, s, c);
    return float3(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

float4 EulerToQuaternion(float3 rad)
{
    float cy = cos(rad.y * 0.5);
    float sy = sin(rad.y * 0.5);
    float cp = cos(rad.x * 0.5);
    float sp = sin(rad.x * 0.5);
    float cr = cos(rad.z * 0.5);
    float sr = sin(rad.z * 0.5);

    // Quaternion as float4 (x, y, z, w)
    float4 rotation;
    rotation.x = sp * cy * cr + cp * sy * sr;
    rotation.y = cp * sy * cr - sp * cy * sr;
    rotation.z = cp * cy * sr - sp * sy * cr;
    rotation.w = cp * cy * cr + sp * sy * sr;

    return rotation;
}

#endif 