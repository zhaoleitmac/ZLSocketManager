//
//  GMSocketUtil.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/14.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Protobuf/GPBProtocolBuffers.h>

@class GMSocketSessionMsg;
@class GMSocketSessionHeader;
@class GMSocketSessionBody;

@interface GMSocketUtil : NSObject

///消息转换为数据
+ (NSData *)dataWithMessage:(GMSocketSessionMsg *)message;
///消息头转换为数据
+ (NSData *)messageHeaderTransToData:(GMSocketSessionHeader *)header;

///数据转消息
+ (GMSocketSessionMsg *)transDataToMessage:(NSData *)data messageLength:(NSInteger)length;
////解析响应的byte数组
+ (int)analysisByteToInt:(Byte[])originalByte start:(NSInteger)start length:(NSInteger)length;
/////处理将NSData转为字符串的时候为nil
//+ (NSData *)UTF8Data:(NSData*)data;
//+ (NSString*)analysisByteToStr:(Byte[])originalByte start:(NSInteger)start length:(NSInteger)length;



@end
