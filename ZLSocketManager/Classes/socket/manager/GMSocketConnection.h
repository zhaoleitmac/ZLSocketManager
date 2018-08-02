//
//  GMSocketConnection.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/12.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GMSocketSessionMsg.h"

#define kSocketAckMsgTag -1

#define kSocketTaskTag -2

@protocol GMSocketConnectionDelegate;

@interface GMSocketConnection : NSObject

@property (nonatomic, weak) id <GMSocketConnectionDelegate>  delegate;//执行socket代理

/** 需要公开的对外的外接设备属性，以便重新连接 */
@property (nonatomic, assign, readonly) int port;//端口号

@property (nonatomic, copy, readonly) NSString *host;//静态ip地址 [host]

@property (nonatomic, assign, readonly) BOOL isConnected;

@property (nonatomic, assign, readonly) BOOL isDisconnected;

@property (atomic, assign, readonly) BOOL isConnecting;

- (instancetype)initWithHost:(NSString *)host
                        port:(int)port;

+ (NSString *)connectionIdWithHost:(NSString *)host
                              port:(int)port;


///开启心跳
- (void)startConnectionHeartBeat;
///暂停心跳
- (void)stopConnectionHeartBeat;

///重连
- (void)connection:(void(^)(GMSocketConnection *connection, NSError *error))callback;

- (void)connection:(NSTimeInterval)timeout callback:(void(^)(GMSocketConnection *connection, NSError *error))callback;

///断开连接
- (void)disconnect;

///发送请求消息
- (void)sendMessage:(GMSocketSessionMsg *)message timeout:(NSTimeInterval)time tag:(int)tag;

- (void)cleanDataBuffer;
@end

@protocol GMSocketConnectionDelegate <NSObject>

@required

///处理消息
- (void)handleMessage:(GMSocketSessionMsg *)message connection:(GMSocketConnection *)connection;

@optional

///连接成功
- (void)didConnect:(GMSocketConnection *)connection;
///连接失败
- (void)didFailConnect:(GMSocketConnection *)connection;

///心跳断开
- (void)heatBeatDidDisconnect:(GMSocketConnection *)connection;

@end


