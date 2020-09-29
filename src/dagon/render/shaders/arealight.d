/*
Copyright (c) 2019 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.render.shaders.arealight;

import std.stdio;
import std.math;

import dlib.core.memory;
import dlib.core.ownership;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.transformation;
import dlib.math.interpolation;
import dlib.math.utils;
import dlib.image.color;
import dlib.text.str;

import dagon.core.bindings;
import dagon.graphics.shader;
import dagon.graphics.state;
import dagon.graphics.light;

class AreaLightShader: Shader
{
    String vs, fs;

    this(Owner owner)
    {
        vs = Shader.load("data/__internal/shaders/AreaLight/AreaLight.vert.glsl");
        fs = Shader.load("data/__internal/shaders/AreaLight/AreaLight.frag.glsl");

        auto myProgram = New!ShaderProgram(vs.toString, fs.toString, this);
        super(myProgram, owner);
    }

    ~this()
    {
        vs.free();
        fs.free();
    }

    override void bindParameters(GraphicsState* state)
    {
        setParameter("viewMatrix", state.viewMatrix);
        setParameter("invViewMatrix", state.invViewMatrix);
        setParameter("modelViewMatrix", state.modelViewMatrix);
        setParameter("projectionMatrix", state.projectionMatrix);
        setParameter("invProjectionMatrix", state.invProjectionMatrix);
        setParameter("resolution", state.resolution);
        setParameter("zNear", state.zNear);
        setParameter("zFar", state.zFar);

        // Environment
        if (state.environment)
        {
            setParameter("fogColor", state.environment.fogColor);
            setParameter("fogStart", state.environment.fogStart);
            setParameter("fogEnd", state.environment.fogEnd);
        }
        else
        {
            setParameter("fogColor", Color4f(0.5f, 0.5f, 0.5f, 1.0f));
            setParameter("fogStart", 0.0f);
            setParameter("fogEnd", 1000.0f);
        }

        // Light
        Vector3f lightPos;
        Color4f lightColor;
        float lightEnergy = 1.0f;
        if (state.light)
        {
            auto light = state.light;

            lightPos = light.positionAbsolute * state.viewMatrix;
            lightColor = light.color;
            lightEnergy = light.energy;

            if (light.type == LightType.AreaSphere)
            {
                setParameterSubroutine("lightRadiance", ShaderType.Fragment, "lightRadianceAreaSphere");
            }
            else if (light.type == LightType.AreaTube)
            {
                Vector3f lightPosition2Eye = (light.positionAbsolute + light.directionAbsolute * light.length) * state.viewMatrix;
                setParameter("lightPosition2", lightPosition2Eye);
                setParameterSubroutine("lightRadiance", ShaderType.Fragment, "lightRadianceAreaTube");
            }
            else if (light.type == LightType.Spot)
            {
                setParameter("lightSpotCosCutoff", cos(degtorad(light.spotOuterCutoff)));
                setParameter("lightSpotCosInnerCutoff", cos(degtorad(light.spotInnerCutoff)));
                Vector4f lightDirHg = Vector4f(light.directionAbsolute);
                lightDirHg.w = 0.0;
                Vector3f spotDirection = (lightDirHg * state.viewMatrix).xyz;
                setParameter("lightSpotDirection", spotDirection);
                setParameterSubroutine("lightRadiance", ShaderType.Fragment, "lightRadianceSpot");
            }
            else // unsupported light type
            {
                setParameterSubroutine("lightRadiance", ShaderType.Fragment, "lightRadianceFallback");
            }

            setParameter("lightPosition", lightPos);
            setParameter("lightColor", lightColor);
            setParameter("lightEnergy", lightEnergy);
            setParameter("lightRadius", light.volumeRadius);
            setParameter("lightAreaRadius", light.radius);
        }
        else
        {
            //lightPos = Vector3f(0.0f, 0.0f, 0.0f);
            //lightColor = Color4f(1.0f, 1.0f, 1.0f, 1.0f);
            setParameterSubroutine("lightRadiance", ShaderType.Fragment, "lightRadianceFallback");
        }

        // Texture 0 - color buffer
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, state.colorTexture);
        setParameter("colorBuffer", 0);

        // Texture 1 - depth buffer
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, state.depthTexture);
        setParameter("depthBuffer", 1);

        // Texture 2 - normal buffer
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, state.normalTexture);
        setParameter("normalBuffer", 2);

        // Texture 3 - pbr buffer
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, state.pbrTexture);
        setParameter("pbrBuffer", 3);

        // Texture 5 - occlusion buffer
        if (glIsTexture(state.occlusionTexture))
        {
            glActiveTexture(GL_TEXTURE5);
            glBindTexture(GL_TEXTURE_2D, state.occlusionTexture);
            setParameter("occlusionBuffer", 5);
            setParameter("haveOcclusionBuffer", true);
        }
        else
        {
            setParameter("haveOcclusionBuffer", false);
        }

        glActiveTexture(GL_TEXTURE0);

        super.bindParameters(state);
    }

    override void unbindParameters(GraphicsState* state)
    {
        super.unbindParameters(state);

        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D, 0);

        glActiveTexture(GL_TEXTURE0);
    }
}
