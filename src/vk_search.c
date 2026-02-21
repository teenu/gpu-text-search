#include "vk_search.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define VK_CHECK(call) do { \
    VkResult r = (call); \
    if (r != VK_SUCCESS) { fprintf(stderr, "%s failed: %d\n", #call, r); return -1; } \
} while(0)

#define WG_SIZE 256

static long read_spv(const char *path, uint32_t **out) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    *out = malloc(len);
    if (fread(*out, 1, len, f) != (size_t)len) { free(*out); fclose(f); return -1; }
    fclose(f);
    return len;
}

static int find_spv(char *buf, size_t bufsz) {
    ssize_t n = readlink("/proc/self/exe", buf, bufsz - 1);
    if (n > 0) {
        buf[n] = '\0';
        char *slash = strrchr(buf, '/');
        if (slash) {
            snprintf(slash + 1, bufsz - (slash + 1 - buf),
                     "shaders/search.comp.spv");
            if (access(buf, R_OK) == 0) return 0;
        }
    }
    snprintf(buf, bufsz, "shaders/search.comp.spv");
    if (access(buf, R_OK) == 0) return 0;
    return -1;
}

static int create_buffer_mapped(VkContext *ctx, VkDeviceSize size,
                                VkBuffer *buf, VkDeviceMemory *mem, void **mapped) {
    VkBufferCreateInfo bci = {
        .sType = VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
        .size = size,
        .usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT,
        .sharingMode = VK_SHARING_MODE_EXCLUSIVE,
    };
    VK_CHECK(vkCreateBuffer(ctx->device, &bci, NULL, buf));

    VkMemoryRequirements mr;
    vkGetBufferMemoryRequirements(ctx->device, *buf, &mr);

    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(ctx->phys_dev, &mp);
    uint32_t type_idx = UINT32_MAX;
    uint32_t want = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;

    for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
        if (!(mr.memoryTypeBits & (1u << i))) continue;
        uint32_t flags = mp.memoryTypes[i].propertyFlags;
        if ((flags & (want | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) ==
            (want | VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT)) {
            type_idx = i; break;
        }
    }
    if (type_idx == UINT32_MAX) {
        for (uint32_t i = 0; i < mp.memoryTypeCount; i++) {
            if (!(mr.memoryTypeBits & (1u << i))) continue;
            if ((mp.memoryTypes[i].propertyFlags & want) == want) {
                type_idx = i; break;
            }
        }
    }
    if (type_idx == UINT32_MAX) {
        fprintf(stderr, "No suitable memory type\n"); return -1;
    }

    VkMemoryAllocateInfo mai = {
        .sType = VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mr.size,
        .memoryTypeIndex = type_idx,
    };
    VK_CHECK(vkAllocateMemory(ctx->device, &mai, NULL, mem));
    VK_CHECK(vkBindBufferMemory(ctx->device, *buf, *mem, 0));
    VK_CHECK(vkMapMemory(ctx->device, *mem, 0, size, 0, mapped));
    return 0;
}

int vk_search_init(SearchPipeline *sp, VkContext *ctx) {
    memset(sp, 0, sizeof(*sp));
    sp->ctx = ctx;

    // Load SPIR-V
    char spv_path[512];
    if (find_spv(spv_path, sizeof(spv_path)) != 0) {
        fprintf(stderr, "Cannot find shaders/search.comp.spv\n"); return -1;
    }
    uint32_t *spv_code;
    long spv_len = read_spv(spv_path, &spv_code);
    if (spv_len < 0) { fprintf(stderr, "Failed to read %s\n", spv_path); return -1; }

    VkShaderModuleCreateInfo smci = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = spv_len, .pCode = spv_code,
    };
    VK_CHECK(vkCreateShaderModule(ctx->device, &smci, NULL, &sp->shader));
    free(spv_code);

    // Descriptor set layout
    VkDescriptorSetLayoutBinding bindings[3] = {
        { 0, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL },
        { 1, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL },
        { 2, VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1, VK_SHADER_STAGE_COMPUTE_BIT, NULL },
    };
    VkDescriptorSetLayoutCreateInfo dslci = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
        .bindingCount = 3, .pBindings = bindings,
    };
    VK_CHECK(vkCreateDescriptorSetLayout(ctx->device, &dslci, NULL, &sp->ds_layout));

    // Pipeline layout
    VkPushConstantRange pcr = {
        .stageFlags = VK_SHADER_STAGE_COMPUTE_BIT,
        .offset = 0, .size = 3 * sizeof(uint32_t),
    };
    VkPipelineLayoutCreateInfo plci = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
        .setLayoutCount = 1, .pSetLayouts = &sp->ds_layout,
        .pushConstantRangeCount = 1, .pPushConstantRanges = &pcr,
    };
    VK_CHECK(vkCreatePipelineLayout(ctx->device, &plci, NULL, &sp->pipe_layout));

    // Compute pipeline
    VkComputePipelineCreateInfo cpci = {
        .sType = VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
        .stage = {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VK_SHADER_STAGE_COMPUTE_BIT,
            .module = sp->shader, .pName = "main",
        },
        .layout = sp->pipe_layout,
    };
    VK_CHECK(vkCreateComputePipelines(ctx->device, VK_NULL_HANDLE, 1, &cpci, NULL, &sp->pipeline));

    // Descriptor pool + set
    VkDescriptorPoolSize ps = { VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 3 };
    VkDescriptorPoolCreateInfo dpci = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO,
        .maxSets = 1, .poolSizeCount = 1, .pPoolSizes = &ps,
    };
    VK_CHECK(vkCreateDescriptorPool(ctx->device, &dpci, NULL, &sp->desc_pool));
    VkDescriptorSetAllocateInfo dsai = {
        .sType = VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO,
        .descriptorPool = sp->desc_pool,
        .descriptorSetCount = 1, .pSetLayouts = &sp->ds_layout,
    };
    VK_CHECK(vkAllocateDescriptorSets(ctx->device, &dsai, &sp->desc_set));

    // Command pool + buffer
    VkCommandPoolCreateInfo cpoci = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = ctx->queue_family,
    };
    VK_CHECK(vkCreateCommandPool(ctx->device, &cpoci, NULL, &sp->cmd_pool));
    VkCommandBufferAllocateInfo cbai = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = sp->cmd_pool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = 1,
    };
    VK_CHECK(vkAllocateCommandBuffers(ctx->device, &cbai, &sp->cmd_buf));

    // Pre-allocate buffers with persistent mapping
    uint32_t res_buf_sz = (1 + MAX_POSITIONS) * sizeof(uint32_t);
    if (create_buffer_mapped(ctx, CHUNK_SIZE, &sp->buf_text, &sp->mem_text, &sp->map_text) != 0) return -1;
    if (create_buffer_mapped(ctx, 256,        &sp->buf_pat,  &sp->mem_pat,  &sp->map_pat)  != 0) return -1;
    if (create_buffer_mapped(ctx, res_buf_sz,  &sp->buf_res,  &sp->mem_res,  &sp->map_res)  != 0) return -1;

    // Bind descriptor set once (buffers never change)
    VkDescriptorBufferInfo dbis[3] = {
        { sp->buf_text, 0, CHUNK_SIZE },
        { sp->buf_pat,  0, 256 },
        { sp->buf_res,  0, res_buf_sz },
    };
    VkWriteDescriptorSet writes[3];
    for (int i = 0; i < 3; i++) {
        writes[i] = (VkWriteDescriptorSet){
            .sType = VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET,
            .dstSet = sp->desc_set, .dstBinding = i,
            .descriptorCount = 1,
            .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER,
            .pBufferInfo = &dbis[i],
        };
    }
    vkUpdateDescriptorSets(ctx->device, 3, writes, 0, NULL);

    return 0;
}

int vk_search_run(SearchPipeline *sp, const void *text, uint32_t text_len,
                  const void *pattern, uint32_t pat_len, SearchResult *result) {
    VkContext *ctx = sp->ctx;
    result->count = 0;
    result->positions = NULL;

    if (pat_len == 0 || text_len == 0 || pat_len > text_len) return 0;

    // Copy data into pre-allocated, persistently-mapped buffers
    memcpy(sp->map_text, text, text_len);
    // Zero pad to uint boundary
    uint32_t padded = ((text_len + 3) / 4) * 4;
    if (padded > text_len) memset((char*)sp->map_text + text_len, 0, padded - text_len);

    memset(sp->map_pat, 0, 256);
    memcpy(sp->map_pat, pattern, pat_len);

    // Zero match count
    *(uint32_t*)sp->map_res = 0;

    // Record + dispatch
    VkCommandBufferBeginInfo cbbi = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    VK_CHECK(vkBeginCommandBuffer(sp->cmd_buf, &cbbi));
    vkCmdBindPipeline(sp->cmd_buf, VK_PIPELINE_BIND_POINT_COMPUTE, sp->pipeline);
    vkCmdBindDescriptorSets(sp->cmd_buf, VK_PIPELINE_BIND_POINT_COMPUTE,
                            sp->pipe_layout, 0, 1, &sp->desc_set, 0, NULL);

    uint32_t max_pos = MAX_POSITIONS;
    uint32_t pc[3] = { text_len, pat_len, max_pos };
    vkCmdPushConstants(sp->cmd_buf, sp->pipe_layout,
                       VK_SHADER_STAGE_COMPUTE_BIT, 0, sizeof(pc), pc);

    uint32_t total = text_len - pat_len + 1;
    uint32_t groups_x = (total + WG_SIZE - 1) / WG_SIZE;
    uint32_t gy = 1;
    if (groups_x > ctx->max_wg_count_x) {
        gy = (groups_x + ctx->max_wg_count_x - 1) / ctx->max_wg_count_x;
        groups_x = ctx->max_wg_count_x;
    }
    vkCmdDispatch(sp->cmd_buf, groups_x, gy, 1);
    VK_CHECK(vkEndCommandBuffer(sp->cmd_buf));

    VkSubmitInfo si = {
        .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .commandBufferCount = 1, .pCommandBuffers = &sp->cmd_buf,
    };
    VK_CHECK(vkQueueSubmit(ctx->queue, 1, &si, VK_NULL_HANDLE));
    VK_CHECK(vkQueueWaitIdle(ctx->queue));

    // Read results directly from persistent mapping
    uint32_t *res = (uint32_t *)sp->map_res;
    result->count = res[0];
    uint32_t stored = result->count < max_pos ? result->count : max_pos;
    if (stored > 0) {
        result->positions = malloc(stored * sizeof(uint32_t));
        memcpy(result->positions, res + 1, stored * sizeof(uint32_t));
    }
    return 0;
}

void vk_search_cleanup(SearchPipeline *sp) {
    VkDevice d = sp->ctx->device;
    if (sp->map_text) vkUnmapMemory(d, sp->mem_text);
    if (sp->map_pat)  vkUnmapMemory(d, sp->mem_pat);
    if (sp->map_res)  vkUnmapMemory(d, sp->mem_res);
    if (sp->buf_text) { vkDestroyBuffer(d, sp->buf_text, NULL); vkFreeMemory(d, sp->mem_text, NULL); }
    if (sp->buf_pat)  { vkDestroyBuffer(d, sp->buf_pat, NULL);  vkFreeMemory(d, sp->mem_pat, NULL);  }
    if (sp->buf_res)  { vkDestroyBuffer(d, sp->buf_res, NULL);  vkFreeMemory(d, sp->mem_res, NULL);  }
    if (sp->cmd_pool)    vkDestroyCommandPool(d, sp->cmd_pool, NULL);
    if (sp->desc_pool)   vkDestroyDescriptorPool(d, sp->desc_pool, NULL);
    if (sp->pipeline)    vkDestroyPipeline(d, sp->pipeline, NULL);
    if (sp->pipe_layout) vkDestroyPipelineLayout(d, sp->pipe_layout, NULL);
    if (sp->ds_layout)   vkDestroyDescriptorSetLayout(d, sp->ds_layout, NULL);
    if (sp->shader)      vkDestroyShaderModule(d, sp->shader, NULL);
}
