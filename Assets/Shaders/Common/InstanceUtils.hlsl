#ifndef _Flower_Utils_HLSL
#define _Flower_Utils_HLSL

inline uint4 UnpackIds(uint packedValue)
{
	uint monthId = (packedValue >> 28) & 0xF;
	uint flowerId = (packedValue >> 24) & 0xF;
	uint areaId = (packedValue >> 16) & 0xFF;
	uint uId = packedValue & 0xFFFF;
	return uint4(monthId, flowerId, areaId, uId);
}

inline uint PackBufferId(uint areaId, uint uId) // BufferId is composed of areaId and uId
{
	// from leftmost: area - uid
	uint packedValue = (uint)((areaId & 0xFF) << 16 | (uId & 0xFFFF));
	return packedValue;
}

inline uint PackIds(int monthId, int flowerId, int areaId, int uId) // UUID is composed of areaId, monthId, flowerId and uId
{
	uint packedValue = (uint)((monthId & 0xF) << 28 | (flowerId & 0xF) << 24 | (areaId & 0xFF) << 16 | (uId & 0xFFFF));
	return packedValue;
}

#endif
