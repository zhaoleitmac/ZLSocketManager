//
//  GMProtoBufSession.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/27.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMProtoBufSession.h"

static NSDictionary *sessionInfos;

@implementation GMProtoBufSession

+ (void)load {
    NSString *sessionInfoPath = [[NSBundle mainBundle] pathForResource:@"PBMessageInfo.plist" ofType:nil];
    NSDictionary *sessionInfosDic = [NSDictionary dictionaryWithContentsOfFile:sessionInfoPath];
    sessionInfos = sessionInfosDic;
}

+ (instancetype)sessionInfoWithRequestMsgType:(int)requestMsgType {
    NSString *key = [NSString stringWithFormat:@"%d", requestMsgType];
    NSDictionary *sessionInfoDic = sessionInfos[key];
  
    if (sessionInfoDic) {
        return [GMProtoBufSession new]; //利用sessionInfoDic生成对象，字典转对象根据实际项目所用方法修改此处。
    }
    return nil;
}

@end
