//
//  GMSocketSessionBody.h
//  socketdemo
//
//  Created by vvipchen on 2018/6/8.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GMSocketSessionHeader.h"
#import "GMSocketSessionBody.h"
#import <Protobuf/GPBProtocolBuffers.h>

@interface GMSocketSessionMsg : NSObject

@property (nonatomic ,strong) GMSocketSessionHeader *header;

@property (nonatomic ,strong) GMSocketSessionBody *body;

+ (instancetype)messageWithIDENTIFIER:(int)IDENTIFIER msgType:(int)msgType messageData:(__kindof GPBMessage *)messageData;

///心跳消息
+ (instancetype)heartbeatMessage;

@end
