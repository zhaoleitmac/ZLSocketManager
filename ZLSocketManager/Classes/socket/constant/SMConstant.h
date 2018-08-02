//
//  SMConstant.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/7/30.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <UIKit/UIKit.h>

///weak/strong reference
#define SMSelfWeakly __weak typeof(self) __SMWeakSelf = self;
#define SMSelfStrongly __strong typeof(__SMWeakSelf) self = __SMWeakSelf;

//singleton
#define SM_SINGLETON_DECLARE \
+(instancetype)sharedInstance;

#define SM_SINGLETON_IMPLEMENTATION \
+(instancetype)sharedInstance{ \
return [self new]; \
} \
\
+(instancetype)allocWithZone:(struct _NSZone *)zone{ \
static id instance; \
static dispatch_once_t onceToken; \
dispatch_once(&onceToken, ^{ \
instance = [super allocWithZone:zone]; \
}); \
return instance; \
}\
\
-(instancetype)init{\
static dispatch_once_t onceToken;\
static typeof(self) instance;\
dispatch_once(&onceToken, ^{\
instance = [super init];\
});\
return instance;\
}
