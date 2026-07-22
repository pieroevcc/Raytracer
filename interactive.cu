#include <stdio.h>
#include <stdlib.h>
#include <fstream>
#include <iostream>
#include <vector>
#include <glad/glad.h>
#include <GLFW/glfw3.h>


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
        "void main() { frag = texture(tex, uv); }\n";
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

void fill_test_pattern(std::vector<uchar4>& px, int W, int H) {
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x)
            px[y*W + x] = make_uchar4(255*x/W, 255*y/H, 128, 255);
}

int main(){
    const int W = 800, H = 450;
    GLFWwindow* window = init_window(W,H);
    GLuint tex = make_texture(W,H);
    GLuint prog = make_program();
    GLuint vao = make_fullscreen_vao();
    
    std::vector<uchar4> pixels(W*H);
    fill_test_pattern(pixels, W, H);
    glBindTexture(GL_TEXTURE_2D, tex);
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, pixels.data());


    while(!glfwWindowShouldClose(window)){ //poll -> clear -> bind (program/vao/tex) -> draw -> swap
        glfwPollEvents();
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(prog);
        glBindVertexArray(vao);
        glBindTexture(GL_TEXTURE_2D, tex);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        glfwSwapBuffers(window);
    }
    glfwTerminate();
    return 0;
}