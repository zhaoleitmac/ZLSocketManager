//
//  GMSocketSessionManager.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/12.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SMConstant.h"

@class GMSocketConnection;
@class GMProtoBufSession;
@class GPBMessage;

FOUNDATION_EXTERN UInt16 const CASHIER_PORT;

///成功回调
typedef void(^GMSocketSessionCallback)(id r, NSError *e);

@interface GMSocketSessionManager : NSObject

SM_SINGLETON_DECLARE

- (BOOL)isConnected;

///完全断开状态（无正在尝试连接）
- (BOOL)isDisconnected;

///连接收银机
- (void)connectionWithHost:(NSString *)host port:(UInt16)port callback:(void(^)(NSError *error))callback;

- (void)connection:(void(^)(NSError *error))callback;

- (void)connection:(NSTimeInterval)timeout callback:(void(^)(NSError *error))callback;

///断开收银机
- (void)disconnect;

///发送请求
- (void)sendRequestData:(__kindof GPBMessage *)requestData
                msgType:(int)msgType
                timeout:(NSTimeInterval)timeout
               callback:(GMSocketSessionCallback)callback;

@end

@interface  GMSocketSession : NSObject

@property (nonatomic, strong) __kindof GPBMessage *requestData;

@property (nonatomic, strong) GMProtoBufSession *sessionInfo;

@property (nonatomic, strong) NSTimer *timeOutTimer;

//超时计数
@property (nonatomic, assign) int timeOutCount;

@property (nonatomic, assign) int IDENTIFIER;

@property (nonatomic, copy) GMSocketSessionCallback callback;

//执行中
@property (nonatomic, assign) BOOL excuting;

@end
