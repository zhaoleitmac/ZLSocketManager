//
//  GMSocketManager.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/7.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketManager.h"
#import "GCDAsyncUdpSocket.h"
#import "SMLog.h"
#import <libkern/OSAtomic.h>
#import "GMSocketConnect.h"
#import "GMSocketTask.h"
#import "GMSocketSessionManager.h"

#define MAX_IDENTIFIER ((0x7FFFFFFF >> 1) - 1)

@interface GMSocketManager () <GMSocketConnectDelegate, GMSocketTaskDelegate>

///搜寻收银机锁
@property (nonatomic, assign) OSSpinLock connectLock;
///搜寻收银机请求集合
@property (nonatomic, strong) NSMutableSet <GMCashierConnect *> *connects;

///会话锁
@property (nonatomic, assign) OSSpinLock taskLock;
///网络会话请求集合
@property (nonatomic, strong) NSMutableSet <GMSocketTask *> *tasks;

@property (nonatomic, assign) int IDENTIFIER;

@end

@implementation GMSocketManager

+ (instancetype)sharedInstance {
    return [self new];
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (instancetype)init {
    static dispatch_once_t onceToken;
    static typeof(self) instance;
    dispatch_once(&onceToken, ^{
        instance = [super init];
        self.connects = [NSMutableSet set];
        self.connectLock = OS_SPINLOCK_INIT;
        
        self.tasks = [NSMutableSet set];
        self.taskLock = OS_SPINLOCK_INIT;

    });
    return instance;
}

- (GMSocketConnect *)creatUDPTask {
    return [[GMSocketConnect alloc] initWithDelegate:self];
}

///TCP回话
- (GMSocketTask *)creatTask {
    return [[GMSocketTask alloc] initWithDelegate:self];
}

- (int)IDENTIFIER {
    if (_IDENTIFIER < MAX_IDENTIFIER) {
        _IDENTIFIER++;
    } else {
        _IDENTIFIER = 1;
    }
    return _IDENTIFIER;
}

#pragma mark - GMSocketConnectDelegate

- (void)connectDidStart:(__kindof GMCashierConnect *)connect {
    OSSpinLock lock = self.connectLock;
    BOOL locked = OSSpinLockTry(&lock);
    [self.connects addObject:connect];
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (void)connectDidFinish:(__kindof GMSocketConnect *)connect {
    OSSpinLock lock = self.connectLock;
    BOOL locked = OSSpinLockTry(&lock);
    if ([self.connects containsObject:connect]) {
        [self.connects removeObject:connect];
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}


#pragma mark - GMSocketTaskDelegate

- (void)taskDidStart:(__kindof GMSocketTask *)task {
    OSSpinLock lock = self.taskLock;
    BOOL locked = OSSpinLockTry(&lock);
    [self.tasks addObject:task];
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (void)taskDidFinish:(__kindof GMSocketTask *)task {
    OSSpinLock lock = self.taskLock;
    BOOL locked = OSSpinLockTry(&lock);
    if ([self.tasks containsObject:task]) {
        [self.tasks removeObject:task];
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

@end
