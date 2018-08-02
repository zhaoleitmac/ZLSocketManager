//
//  GMSocketSessionHeader.h
//  socketdemo
//
//  Created by vvipchen on 2018/6/8.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GMSocketSessionHeader : NSObject

+ (instancetype)heartbeatHeader;

+ (instancetype)searchCashierHeader;

@property (nonatomic, assign) unsigned int LENGTH;//整个数据长度

@property (nonatomic, assign) int MSG_TYPE;//消息类型

@property (nonatomic, assign) int IDENTIFIER;//一次通信过程的唯一标识，随响应(RESP)消息返回到请求消息侧
@end
