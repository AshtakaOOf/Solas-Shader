uniform sampler2D shadowtex0;

#ifdef SHADOW_COLOR
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
#endif

const vec2 shadowOffsets[8] = vec2[8](
    vec2( 0.000000,  0.250000),
    vec2( 0.292496, -0.319290),
    vec2(-0.556877,  0.048872),
    vec2( 0.524917,  0.402445),
    vec2(-0.130636, -0.738535),
    vec2(-0.445032,  0.699604),
    vec2( 0.870484, -0.234003),
    vec2(-0.859268, -0.446273)
);

vec3 calculateShadowPos(vec3 worldPos) {
    vec3 shadowPos = ToShadow(worldPos);
    float distb = sqrt(shadowPos.x * shadowPos.x + shadowPos.y * shadowPos.y);
    float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);

    shadowPos.xy /= distortFactor;
    shadowPos.z *= 0.2;
    
    return shadowPos * 0.5 + 0.5;
}

float texture2DShadow(sampler2D shadowtex, vec3 shadowPos) {
    return step(shadowPos.z - 0.0001, texture2D(shadowtex, shadowPos.xy).r);
}

#ifdef VPS
//Variable Penumbra Shadows based on Tech's Lux Shader (https://github.com/TechDevOnGitHub)
void findBlockerDistance(vec3 shadowPos, mat2 ditherRotMat, inout float offset, float skyLightMap, float viewLengthFactor) {
    float blockerDistance = 0.0;
        
    for (int i = 0; i < 8; i++){
        vec2 pixelOffset = ditherRotMat * shadowOffsets[i] * 0.015;
        blockerDistance += shadowPos.z - texture2D(shadowtex0, shadowPos.xy + pixelOffset).r;
    }
    blockerDistance *= 0.125;

    offset = mix(offset, max(offset, blockerDistance * VPS_BLUR_STRENGTH), skyLightMap * viewLengthFactor);
}
#endif

vec3 computeShadow(vec3 shadowPos, float offset, float dither, float skyLightMap, float ao, float viewLengthFactor) {
    float shadow0 = 0.0;

    float cosTheta = cos(dither * TAU);
	float sinTheta = sin(dither * TAU);
    mat2 ditherRotMat =  mat2(cosTheta, -sinTheta, sinTheta, cosTheta);

    #ifdef VPS
    findBlockerDistance(shadowPos, ditherRotMat, offset, skyLightMap, viewLengthFactor);
    #endif

    for (int i = 0; i < 8; i++) {
        vec2 pixelOffset = ditherRotMat * shadowOffsets[i] * offset;
        shadow0 += texture2DShadow(shadowtex0, vec3(shadowPos.st + pixelOffset, shadowPos.z));
    }
    shadow0 *= 0.125;

    vec3 shadowCol = vec3(0.0);
    #ifdef SHADOW_COLOR
    if (shadow0 < 0.999) {
        for (int i = 0; i < 8; i++) {
            vec2 pixelOffset = ditherRotMat * shadowOffsets[i] * offset;
            shadowCol += texture2D(shadowcolor0, shadowPos.st + pixelOffset).rgb *
                         texture2DShadow(shadowtex1, vec3(shadowPos.st + pixelOffset, shadowPos.z));
        }
        shadowCol *= 0.125;
    }
    #endif

    //Light leak fix
    shadow0 = mix(shadow0, shadow0 * ao, (1.0 - ao));

    return clamp(shadowCol * (1.0 - shadow0) + shadow0, 0.0, 1.0);
}