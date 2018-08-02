//
//  GMProtoBufSession.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/27.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Protobuf/GPBProtocolBuffers.h>

@interface GMProtoBufSession : NSObject

///请求消息
@property (nonatomic, assign) int REQUEST_MSG_TYPE;

///回复消息
@property (nonatomic, assign) int RESPONSE_MSG_TYPE;

///回复对象类名
@property (nonatomic, strong) NSString *responseClassName;

+ (instancetype)sessionInfoWithRequestMsgType:(int)requestMsgType;

@end
