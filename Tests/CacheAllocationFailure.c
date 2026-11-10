// 公司版权声明: Copyright (c) 广州心娱网络科技有限公司. All rights reserved.
// 开发人员: 詹龙 zhanlong@yunqi688.com
// 员工工号: XY-0398
// 内部IM ID: 957
// 手机尾号: 5352
// 创建日期: 2026-11-10
#include <stdlib.h>
#include <stdbool.h>
#include <unistd.h>
static bool armed=false;
void probe_arm(void){armed=true;}
void probe_disarm(void){armed=false;}
static void * probe_malloc(size_t n){if(armed && n>=1048576){write(2,"PROBE malloc rejected\n",22);return NULL;}return malloc(n);}
static void * probe_calloc(size_t n,size_t s){if(armed && s && n>=1048576/s){write(2,"PROBE calloc rejected\n",22);return NULL;}return calloc(n,s);}
static void * probe_realloc(void *p,size_t n){if(armed && n>=1048576){write(2,"PROBE realloc rejected\n",23);return NULL;}return realloc(p,n);}
#define INTERPOSE(new,old) __attribute__((used)) static struct{const void *a;const void *b;} pair_##old __attribute__((section("__DATA,__interpose")))={(const void*)&new,(const void*)&old};
INTERPOSE(probe_malloc,malloc)
INTERPOSE(probe_calloc,calloc)
INTERPOSE(probe_realloc,realloc)
