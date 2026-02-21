#pragma once
#include <vulkan/vulkan.h>
#include <stdint.h>

typedef struct {
    VkInstance       instance;
    VkPhysicalDevice phys_dev;
    VkDevice         device;
    VkQueue          queue;
    uint32_t         queue_family;
    uint32_t         mem_type_idx;       // HOST_VISIBLE + DEVICE_LOCAL preferred
    uint32_t         max_wg_count_x;
    uint32_t         max_wg_count_y;
} VkContext;

// Returns 0 on success, -1 on failure (prints error to stderr).
int  vk_init(VkContext *ctx);
void vk_cleanup(VkContext *ctx);
