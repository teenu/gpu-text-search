CC     = gcc
CFLAGS = -O2 -Wall -Wextra
LDFLAGS = -lvulkan -lm
GLSLC  = glslangValidator

SRCS = src/main.c src/vk_init.c src/vk_search.c
SPV  = shaders/search.comp.spv

gts: $(SRCS) $(SPV)
	$(CC) $(CFLAGS) -o $@ $(SRCS) $(LDFLAGS)

$(SPV): shaders/search.comp
	$(GLSLC) -V $< -o $@

clean:
	rm -f gts $(SPV)

.PHONY: clean
