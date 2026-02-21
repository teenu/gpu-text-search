#pragma once
#include "vk_init.h"

#define CHUNK_SIZE    (256u * 1024 * 1024)  // 256 MB per dispatch
#define MAX_POSITIONS (1 << 20)             // 1M match positions

typedef struct {
    VkContext           *ctx;
    VkShaderModule       shader;
    VkDescriptorSetLayout ds_layout;
    VkPipelineLayout     pipe_layout;
    VkPipeline           pipeline;
    VkDescriptorPool     desc_pool;
    VkDescriptorSet      desc_set;
    VkCommandPool        cmd_pool;
    VkCommandBuffer      cmd_buf;
    // Pre-allocated buffers (reused across chunks)
    VkBuffer             buf_text, buf_pat, buf_res;
    VkDeviceMemory       mem_text, mem_pat, mem_res;
    void                *map_text, *map_pat, *map_res;
} SearchPipeline;

typedef struct {
    uint32_t  count;
    uint32_t *positions;  // caller must free()
} SearchResult;

int  vk_search_init(SearchPipeline *sp, VkContext *ctx);
int  vk_search_run(SearchPipeline *sp, const void *text, uint32_t text_len,
                   const void *pattern, uint32_t pat_len, SearchResult *result);
void vk_search_cleanup(SearchPipeline *sp);
