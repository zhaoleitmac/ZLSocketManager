//
//  GMSocketConnect.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/11.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GPBMessage;

@protocol GMSocketConnectDelegate;

///成功回调
typedef void(^QNSocketConnectSuccess)(NSDictionary *response);
///失败回调
typedef void(^QNSocketConnectError)(NSError *error);
///统一回调
typedef void(^QNSocketConnectFinish)(NSDictionary *response, NSError *error);

@interface GMSocketConnect : NSObject {
@protected
    QNSocketConnectSuccess _successCallback;
    QNSocketConnectError _errorCallback;
    QNSocketConnectFinish _finishCallback;
    NSString *_connectIP;
    UInt16 _connectPort;
    NSTimeInterval _timeoutInterval;
    __kindof GPBMessage *_sendData;
    int _messageType;
}

- (__kindof GMSocketConnect *)initWithDelegate:(id <GMSocketConnectDelegate>)delegate;

@property (nonatomic,weak) id <GMSocketConnectDelegate> delegate;

@property (nonatomic, assign, readonly) BOOL canceled;

- (__kindof GMSocketConnect* (^)(int messageType))msgType;

///连接的IP
- (__kindof GMSocketConnect* (^)(NSString *IP))IP;

///连接的端口号
- (__kindof GMSocketConnect* (^)(UInt16 port))port;

///发送的消息
- (__kindof GMSocketConnect* (^)(__kindof GPBMessage *))requestData;
- (__kindof GMSocketConnect* (^)(NSDictionary *sendParam))param;

///超时时间
- (__kindof GMSocketConnect* (^)(NSTimeInterval timeout))timeout;

///取消
- (__kindof GMSocketConnect* (^)(BOOL cancel))cancel;

///成功回调
- (__kindof GMSocketConnect* (^)(QNSocketConnectSuccess))success;

///失败回调
- (__kindof GMSocketConnect* (^)(QNSocketConnectError))error;

///无论成功或失败的回调
- (__kindof GMSocketConnect* (^)(QNSocketConnectFinish))finish;

- (__kindof GMSocketConnect* (^)(void))send;

///取消该次任务
- (void)cancelConnect;

@end

@protocol GMSocketConnectDelegate <NSObject>

@optional

- (void)connectDidStart:(__kindof GMSocketConnect *)connect;

- (void)connectDidCancel:(__kindof GMSocketConnect *)connect;

- (void)connectDidFinish:(__kindof GMSocketConnect *)connect;

@end
