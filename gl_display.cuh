#pragma once

#include <stdio.h>
#include <stdlib.h>
#include <cuda_runtime.h>
#include <glad/glad.h>
#include <GLFW/glfw3.h>
#include <cuda_gl_interop.h>

#define CUDA_CHECK(call) do { \
    cudaError_t err_ = call; \
    if (err_ != cudaSuccess){ \
        printf("CUDA error : %s\n", cudaGetErrorString(err_)); \
        exit(1); \
    } \
} while(0)

struct Display {GLFWwindow* window; GLuint tex; GLuint prog; GLuint vao; GLuint pbo; 
    cudaGraphicsResource* cudaPbo; int W; int H; };

static GLFWwindow* init_window(int W, int H) {
    if (!glfwInit()) { fprintf(stderr, "glfwInit failed\n"); exit(1); } //boots GLFW library
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3); //3 glfwWindowHint; grabs OpenGL 3.3 context
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    GLFWwindow* win = glfwCreateWindow(W, H, "CUDA Ray Tracer - interactive", nullptr, nullptr); //creates windwo
    if (!win) { fprintf(stderr, "window create failed\n"); glfwTerminate(); exit(1); }
    glfwMakeContextCurrent(win); // makes curr GL context window 
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) { fprintf(stderr, "GLAD load failed\n"); exit(1); }
    glfwSwapInterval(0);  //Vsync off; 0 = swap buffers immediately  
    glViewport(0, 0, W, H); //mapos normalized device coords
    return win;
}

static GLuint make_texture(int W, int H) { //gen name -> bind -> configure
    GLuint tex; 
    glGenTextures(1, &tex);  //reserve 1 texture name and write to tex
    glBindTexture(GL_TEXTURE_2D, tex);//make tex the current 2D texture
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, W, H, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr); //allocates storage; GL_RGBA8 = GPU storage
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); //minified
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST); //magnified
    return tex;
}

static GLuint compile_shader(GLenum type, const char* src) { //stages the shader
    GLuint s = glCreateShader(type); 
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { char log[1024]; glGetShaderInfoLog(s, sizeof log, nullptr, log); // else print why it failed
               fprintf(stderr, "shader compile:\n%s\n", log); exit(1); }
    return s;
}

static GLuint make_program() {
    const char* VERT =
        "#version 330 core\n"
        "out vec2 uv;\n"
        "void main() {\n"
        "    vec2 p = vec2(float((gl_VertexID << 1) & 2), float(gl_VertexID & 2));\n"
        "    uv = p;                              // 0..2 across the screen\n"
        "    gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);\n"
        "}\n";
    const char* FRAG =
        "#version 330 core\n"
        "in vec2 uv;\n"
        "out vec4 frag;\n"
        "uniform sampler2D tex;\n"
        "void main() { frag = texture(tex, vec2(uv.x, 1.0 - uv.y)); }\n";
    GLuint v = compile_shader(GL_VERTEX_SHADER, VERT);
    GLuint f = compile_shader(GL_FRAGMENT_SHADER, FRAG);
    GLuint p = glCreateProgram();
    glAttachShader(p, v); glAttachShader(p, f);
    glLinkProgram(p);
    GLint ok; glGetProgramiv(p, GL_LINK_STATUS, &ok);
    if (!ok) { char log[1024]; glGetProgramInfoLog(p, sizeof log, nullptr, log);
               fprintf(stderr, "program link:\n%s\n", log); exit(1); }
    glDeleteShader(v); glDeleteShader(f);
    return p;                         
}

static GLuint make_fullscreen_vao() { //Vertex Array Object
    GLuint vao; glGenVertexArrays(1, &vao); 
    return vao;
}

static GLuint make_pbo(int W, int H){ //make Picture Buffer Object
    GLuint buf;
    glGenBuffers(1, &buf);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, buf);
    glBufferData(GL_PIXEL_UNPACK_BUFFER, W*H*sizeof(uchar4), nullptr, GL_DYNAMIC_DRAW);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    return buf;
}

static Display init_display(int W, int H){ //create display
    Display d;
    d.W = W;
    d.H = H;
    d.window = init_window(W,H);
    d.tex = make_texture(W,H);
    d.prog = make_program();
    d.vao = make_fullscreen_vao();
    d.pbo = make_pbo(W,H);
    CUDA_CHECK(cudaGraphicsGLRegisterBuffer(&d.cudaPbo, d.pbo, cudaGraphicsRegisterFlagsWriteDiscard));
    return d;
}

static uchar4* map_pbo(const Display& d){
    cudaGraphicsResource_t tmp_pbo = d.cudaPbo;
    CUDA_CHECK(cudaGraphicsMapResources(1, &tmp_pbo, 0));
    uchar4* devPtr;
    size_t numBytes;
    CUDA_CHECK(cudaGraphicsResourceGetMappedPointer((void**)&devPtr, &numBytes, d.cudaPbo));
    return devPtr;
}

static void present(const Display& d){
    CUDA_CHECK(cudaDeviceSynchronize());
    cudaGraphicsResource_t tmp_pbo = d.cudaPbo;
    CUDA_CHECK(cudaGraphicsUnmapResources(1, &tmp_pbo, 0));
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, d.pbo);
    glBindTexture(GL_TEXTURE_2D, d.tex);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, d.W, d.H, GL_RGBA, GL_UNSIGNED_BYTE, (void*)0);
    glBindBuffer(GL_PIXEL_UNPACK_BUFFER, 0);
    glClear(GL_COLOR_BUFFER_BIT);
    glUseProgram(d.prog);
    glBindVertexArray(d.vao);
    glBindTexture(GL_TEXTURE_2D, d.tex);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glfwSwapBuffers(d.window);
}