//
//  SMLog.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/7/30.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef DEBUG
#define SMDebugLog(format, ...) (printf("\r\n<------LOG BEGIN------>\r\n[fileName:%s]\r\n" "[functionName:%s]\r\n" "[codeRow:%d]\r\n%s\r\n<-------LOG END------->\r\n\r\n", [[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __PRETTY_FUNCTION__, __LINE__, [[NSString stringWithFormat:(format), ##__VA_ARGS__] UTF8String]))
#else
#define SMDebugLog(format, ...)
#endif

#define SM_MEMORAY_CHECK_DEBUG_LOG SMDebugLog(@"<%@,%p> is dealoc.Memory safe", self.class, self)
