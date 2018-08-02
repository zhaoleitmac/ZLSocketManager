//
//  GMSessionError.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/27.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GMSessionError : NSObject

+ (NSString *)errorMsgWithErrorCode:(int)errorCode;

@end
