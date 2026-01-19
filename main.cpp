#define GL_SILENCE_DEPRECATION
#ifdef __APPLE__
#include <OpenGL/gl3.h>
#else
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>
#endif
#include <GLFW/glfw3.h>
#include <iostream>
#include <string>

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

// External assembly function for swirl effect
extern "C"
{
    void apply_swirl(unsigned char *imageData, unsigned char *outBuffer, int width, int height, int channels,
                     float strength, int centerX, int centerY);
}

// Vertex Shader
const char *vertexShaderSource = R"(
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;
out vec2 TexCoord;
void main() {
    gl_Position = vec4(aPos, 0.0, 1.0);
    TexCoord = aTexCoord;
}
)";

// Fragment Shader
const char *fragmentShaderSource = R"(
#version 330 core
out vec4 FragColor;
in vec2 TexCoord;
uniform sampler2D texture1;
void main() {
    FragColor = texture(texture1, TexCoord);
}
)";

GLuint compileShader(GLenum type, const char *source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    int success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success)
    {
        char infoLog[512];
        glGetShaderInfoLog(shader, 512, nullptr, infoLog);
        std::cerr << "Shader compilation error: " << infoLog << std::endl;
    }
    return shader;
}

int main(int argc, char *argv[])
{
    // Check for image path argument
    if (argc < 3)
    {
        std::cerr << "Usage: " << argv[0] << " <image_path> <swirl_strength>" << std::endl;
        std::cerr << "Example: " << argv[0] << " /path/to/image.png 2.0" << std::endl;
        return 1;
    }

    std::string imagePath = argv[1];
    float swirlStrength = std::stof(argv[2]);

    // Initialize GLFW
    if (!glfwInit())
    {
        std::cerr << "Failed to initialize GLFW" << std::endl;
        return -1;
    }

    // Configure GLFW for macOS
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);

    // Load image to get dimensions
    int imgWidth, imgHeight, imgChannels;
    // Flip vertically for OpenGL (OpenGL expects origin at bottom-left)
    stbi_set_flip_vertically_on_load(true);
    unsigned char *imageData = stbi_load(imagePath.c_str(), &imgWidth, &imgHeight, &imgChannels, 0);

    if (!imageData)
    {
        std::cerr << "Failed to load image: " << imagePath << std::endl;
        glfwTerminate();
        return -1;
    }

    std::cout << "Loaded image: " << imgWidth << "x" << imgHeight << " with " << imgChannels << " channels" << std::endl;

    // Allocate output buffer for swirl effect
    size_t imageSize = imgWidth * imgHeight * imgChannels;
    unsigned char *outBuffer = new unsigned char[imageSize];

    // Apply swirl effect using assembly function
    int centerX = imgWidth / 2;
    int centerY = imgHeight / 2;

    std::cout << "Applying swirl effect (strength=" << swirlStrength << ")..." << std::endl;
    apply_swirl(imageData, outBuffer, imgWidth, imgHeight, imgChannels, swirlStrength, centerX, centerY);
    std::cout << "Swirl effect applied!" << std::endl;

    // Free original image data and use the output buffer
    stbi_image_free(imageData);
    imageData = outBuffer;

    // Create window with image aspect ratio
    int windowWidth = imgWidth;
    int windowHeight = imgHeight;

    // Scale down if image is too large
    const int maxSize = 1200;
    if (windowWidth > maxSize || windowHeight > maxSize)
    {
        float scale = std::min((float)maxSize / windowWidth, (float)maxSize / windowHeight);
        windowWidth = (int)(windowWidth * scale);
        windowHeight = (int)(windowHeight * scale);
    }

    // Ensure minimum window size
    windowWidth = std::max(windowWidth, 400);
    windowHeight = std::max(windowHeight, 300);

    GLFWwindow *window = glfwCreateWindow(windowWidth, windowHeight, "Image Viewer", nullptr, nullptr);
    if (!window)
    {
        std::cerr << "Failed to create GLFW window" << std::endl;
        stbi_image_free(imageData);
        glfwTerminate();
        return -1;
    }

    glfwMakeContextCurrent(window);

    // Create and compile shaders
    GLuint vertexShader = compileShader(GL_VERTEX_SHADER, vertexShaderSource);
    GLuint fragmentShader = compileShader(GL_FRAGMENT_SHADER, fragmentShaderSource);

    // Create shader program
    GLuint shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    int success;
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (!success)
    {
        char infoLog[512];
        glGetProgramInfoLog(shaderProgram, 512, nullptr, infoLog);
        std::cerr << "Shader linking error: " << infoLog << std::endl;
    }

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    // Vertex data - full screen quad with texture coordinates
    float vertices[] = {
        // positions    // texture coords
        -1.0f, 1.0f, 0.0f, 1.0f,  // top left
        -1.0f, -1.0f, 0.0f, 0.0f, // bottom left
        1.0f, -1.0f, 1.0f, 0.0f,  // bottom right
        1.0f, 1.0f, 1.0f, 1.0f    // top right
    };

    unsigned int indices[] = {
        0, 1, 2,
        0, 2, 3};

    // Create VAO, VBO, EBO
    GLuint VAO, VBO, EBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    // Position attribute
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(0);

    // Texture coordinate attribute
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(float), (void *)(2 * sizeof(float)));
    glEnableVertexAttribArray(1);

    // Create texture
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);

    // Set texture parameters
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

    // Ensure tight row alignment for 3-channel images
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

    // Upload texture data
    GLenum format = GL_RGB;
    if (imgChannels == 1)
        format = GL_RED;
    else if (imgChannels == 3)
        format = GL_RGB;
    else if (imgChannels == 4)
        format = GL_RGBA;

    glTexImage2D(GL_TEXTURE_2D, 0, format, imgWidth, imgHeight, 0, format, GL_UNSIGNED_BYTE, imageData);

    // Free image data after uploading to GPU
    delete[] imageData;

    // Enable blending for transparent images
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    // Render loop
    while (!glfwWindowShouldClose(window))
    {
        // Handle input
        if (glfwGetKey(window, GLFW_KEY_ESCAPE) == GLFW_PRESS)
            glfwSetWindowShouldClose(window, true);

        // Clear screen
        glClearColor(0.1f, 0.1f, 0.1f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        // Draw
        glUseProgram(shaderProgram);
        glBindTexture(GL_TEXTURE_2D, texture);
        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

        // Swap buffers and poll events
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // Cleanup
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);
    glDeleteTextures(1, &texture);
    glDeleteProgram(shaderProgram);

    glfwTerminate();
    return 0;
}
