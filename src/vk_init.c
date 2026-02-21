#include "vk_init.h"
#include <stdio.h>
#include <string.h>

#define VK_CHECK(call) do { \
    VkResult r = (call); \
    if (r != VK_SUCCESS) { fprintf(stderr, "%s failed: %d\n", #call, r); return -1; } \
} while(0)

static int find_memory_type(VkPhysicalDevice pd, uint32_t *out) {
    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(pd, &mp);

    // Prefer HOST_VISIBLE + DEVICE_LOCAL (APU shared memory = zero-copy)
    uint32_t want = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT
                  | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT
                  | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT;
    for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
        if ((mp.memoryTypes[i].propertyFlags & want) == want) {
            *out = i;
            return 0;
        }
    }
    // Fallback: HOST_VISIBLE + HOST_COHERENT (staging-like, works everywhere)
    want = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
    for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
        if ((mp.memoryTypes[i].propertyFlags & want) == want) {
            *out = i;
            return 0;
        }
    }
    return -1;
}

int vk_init(VkContext *ctx) {
    memset(ctx, 0, sizeof(*ctx));

    // Instance
    VkApplicationInfo app = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "gts",
        .apiVersion = VK_API_VERSION_1_0,
    };
    VkInstanceCreateInfo ici = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app,
    };
    VK_CHECK(vkCreateInstance(&ici, NULL, &ctx->instance));

    // Physical device - prefer integrated GPU
    uint32_t count = 0;
    vkEnumeratePhysicalDevices(ctx->instance, &count, NULL);
    if (count == 0) { fprintf(stderr, "No Vulkan devices\n"); return -1; }

    VkPhysicalDevice devs[16];
    if (count > 16) count = 16;
    vkEnumeratePhysicalDevices(ctx->instance, &count, devs);

    int best = -1;
    int best_score = -1;
    for (uint32_t i = 0; i < count; i++) {
        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(devs[i], &props);
        int score = 0;
        if (props.deviceType == VK_PHYSICAL_DEVICE_TYPE_DISCRETE_GPU)   score = 3;
        if (props.deviceType == VK_PHYSICAL_DEVICE_TYPE_INTEGRATED_GPU) score = 2;
        if (props.deviceType == VK_PHYSICAL_DEVICE_TYPE_CPU)            score = 1;
        if (score > best_score) { best_score = score; best = (int)i; }
    }
    ctx->phys_dev = devs[best];

    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(ctx->phys_dev, &props);
    fprintf(stderr, "Device: %s\n", props.deviceName);
    if (strstr(props.deviceName, "llvmpipe") || strstr(props.deviceName, "lavapipe"))
        fprintf(stderr, "WARNING: Running on software renderer (lavapipe). Performance will be limited.\n");

    ctx->max_wg_count_x = props.limits.maxComputeWorkGroupCount[0];
    ctx->max_wg_count_y = props.limits.maxComputeWorkGroupCount[1];

    // Compute queue family
    uint32_t qcount = 0;
    vkGetPhysicalDeviceQueueFamilyProperties(ctx->phys_dev, &qcount, NULL);
    VkQueueFamilyProperties qprops[32];
    if (qcount > 32) qcount = 32;
    vkGetPhysicalDeviceQueueFamilyProperties(ctx->phys_dev, &qcount, qprops);

    ctx->queue_family = UINT32_MAX;
    for (uint32_t i = 0; i < qcount; i++) {
        if (qprops[i].queueFlags & VK_QUEUE_COMPUTE_BIT) {
            ctx->queue_family = i;
            break;
        }
    }
    if (ctx->queue_family == UINT32_MAX) {
        fprintf(stderr, "No compute queue\n");
        return -1;
    }

    // Logical device
    float prio = 1.0f;
    VkDeviceQueueCreateInfo dqci = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = ctx->queue_family,
        .queueCount = 1,
        .pQueuePriorities = &prio,
    };
    VkDeviceCreateInfo dci = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = 1,
        .pQueueCreateInfos = &dqci,
    };
    VK_CHECK(vkCreateDevice(ctx->phys_dev, &dci, NULL, &ctx->device));
    vkGetDeviceQueue(ctx->device, ctx->queue_family, 0, &ctx->queue);

    // Memory type
    if (find_memory_type(ctx->phys_dev, &ctx->mem_type_idx) != 0) {
        fprintf(stderr, "No suitable memory type\n");
        return -1;
    }

    return 0;
}

void vk_cleanup(VkContext *ctx) {
    if (ctx->device)   vkDestroyDevice(ctx->device, NULL);
    if (ctx->instance) vkDestroyInstance(ctx->instance, NULL);
}
