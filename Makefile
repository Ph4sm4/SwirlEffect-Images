CXX = g++
NASM = nasm

# Linux x86 32-bit
CXXFLAGS = -std=c++17 -Wall -Wextra -O2 -m32
NASMFLAGS = -f elf32

# Use locally built GLFW
GLFW_DIR = glfw-3.4
INCLUDES = -I$(GLFW_DIR)/include
LIBS = -L$(GLFW_DIR)/build/src -lglfw3 -lGL -lX11 -lpthread -ldl -lm

TARGET = image_viewer
CPP_SRC = main.cpp
ASM_SRC = swirl.asm
OBJ = main.o swirl.o

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CXX) $(CXXFLAGS) $(OBJ) -o $(TARGET) $(LIBS)

main.o: $(CPP_SRC)
	$(CXX) $(CXXFLAGS) $(INCLUDES) -c $(CPP_SRC) -o main.o

swirl.o: $(ASM_SRC)
	$(NASM) $(NASMFLAGS) $(ASM_SRC) -o swirl.o

clean:
	rm -f $(TARGET) $(OBJ)

.PHONY: all clean
