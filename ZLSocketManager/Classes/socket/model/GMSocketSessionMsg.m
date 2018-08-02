//
//  GMSocketSessionMsg.m
//  socketdemo
//
//  Created by vvipchen on 2018/6/8.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketSessionMsg.h"

@implementation GMSocketSessionMsg

+ (instancetype)messageWithIDENTIFIER:(int)IDENTIFIER msgType:(int)msgType messageData:(__kindof GPBMessage *)messageData {
    GMSocketSessionMsg *message = [GMSocketSessionMsg new];
    GMSocketSessionHeader *header = [GMSocketSessionHeader new];
    header.MSG_TYPE = msgType;
    header.IDENTIFIER = IDENTIFIER;
    GMSocketSessionBody *body = [GMSocketSessionBody new];
    NSData *data = [messageData data];
    body.DATA = data;
    message.header = header;
    message.body = body;
    return message;
}

+ (instancetype)heartbeatMessage {
    GMSocketSessionMsg *messageObject = [GMSocketSessionMsg new];
    GMSocketSessionHeader *heartbeatHeader = [GMSocketSessionHeader heartbeatHeader];
    messageObject.header = heartbeatHeader;
    return messageObject;
}


@end
