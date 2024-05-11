//
//  DNMemoryValidation.m
//  DartNative
//
//  Created by 杨萧玉 on 2022/11/9.
//

#import "DNMemoryValidation.h"
#import <mach/mach.h>

#import "DNException.h"

#if !__has_feature(objc_arc)
#error
#endif

#if TARGET_OS_OSX && __x86_64__
    // 64-bit Mac - tag bit is LSB
#   define OBJC_MSB_TAGGED_POINTERS 0
#else
    // Everything else - tag bit is MSB
#   define OBJC_MSB_TAGGED_POINTERS 1
#endif

#if OBJC_MSB_TAGGED_POINTERS
#   define _OBJC_TAG_MASK (1ULL<<63)
#else
#   define _OBJC_TAG_MASK 1UL
#endif

#if TARGET_OS_MAC
#define DN_MACH_VM_MAX_ADDRESS 0x00007FFFFE000000ULL
#else
#define DN_MACH_VM_MAX_ADDRESS MACH_VM_MAX_ADDRESS
#endif

/// Returens true if a pointer is a tagged pointer
/// @param ptr is the pointer to check
bool objc_isTaggedPointer(const void *ptr) {
    return ((uintptr_t)ptr & _OBJC_TAG_MASK) == _OBJC_TAG_MASK;
}

/// Returns true if the pointer points to readable and valid memory.
/// NOTE: An expensive function.
/// @param pointer is the pointer to check
bool native_isValidReadableMemory(const void *pointer) {
    // Check for read permissions
    vm_address_t address = (vm_address_t)pointer;
    vm_size_t vmsize = 0;
    mach_port_t object = 0;
#if defined(__LP64__) && __LP64__
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCnt = VM_REGION_BASIC_INFO_COUNT_64;
    kern_return_t ret = vm_region_64(mach_task_self(), &address, &vmsize, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &infoCnt, &object);
#else
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t infoCnt = VM_REGION_BASIC_INFO_COUNT;
    kern_return_t ret = vm_region(mach_task_self(), &address, &vmsize, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &infoCnt, &object);
#endif
    // vm_region/vm_region_64 returned an error or no read permission
    if (ret != KERN_SUCCESS || (info.protection&VM_PROT_READ) == 0) {
        return false;
    }
    
    // Read the memory
    char data[sizeof(uintptr_t)];
    vm_size_t dataCnt = 0;
    ret = vm_read_overwrite(mach_task_self(), (vm_address_t)pointer, sizeof(uintptr_t), (vm_address_t)data, &dataCnt);
    if (ret != KERN_SUCCESS) {
        // vm_read returned an error
        return false;
    }
    return true;
}

/// Returns true if a pointer is valid
/// @param pointer is the pointer to check
bool native_isValidPointer(const void *pointer) {
    if (pointer == nullptr) {
        return false;
    }
    // Check for tagged pointers
    if (objc_isTaggedPointer(pointer)) {
        return true;
    }
    // Check if the pointer is aligned
    if (((uintptr_t)pointer % sizeof(uintptr_t)) != 0) {
        return false;
    }
    // Check if the pointer is not larger than VM_MAX_ADDRESS
    if ((uintptr_t)pointer > DN_MACH_VM_MAX_ADDRESS) {
        return false;
    }
    if (DartNativeCanThrowException()) {
        static NSString * const DNValidMemoryExceptionReason = @"Address(%p) is not readable.";
        static NSExceptionName const DNValidMemoryException = @"ValidMemoryException";
        // Check if the memory is valid and readable
        if (!native_isValidReadableMemory(pointer)) {
            @throw [NSException exceptionWithName:DNValidMemoryException
                                           reason:[NSString stringWithFormat:DNValidMemoryExceptionReason, pointer]
                                         userInfo:nil];
            return false;
        }
    }
    return true;
}
