//
//  GMSessionError.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/27.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSessionError.h"

static NSDictionary *errors;

@implementation GMSessionError

+ (void)load {
    NSString *errorsPath = [[NSBundle mainBundle] pathForResource:@"GMSessionErrorMap.plist" ofType:nil];
    NSDictionary *errorsDic = [NSDictionary dictionaryWithContentsOfFile:errorsPath];
    errors = errorsDic;
}

+ (NSString *)errorMsgWithErrorCode:(int)errorCode {
    NSString *key = [NSString stringWithFormat:@"%d", errorCode];
    return errors[key];
}

@end
