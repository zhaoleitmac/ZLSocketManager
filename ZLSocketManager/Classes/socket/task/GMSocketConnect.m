//
//  GMSocketConnect.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/11.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketConnect.h"
#import "SMConstant.h"
#import "SMLog.h"
#import "GMUDPSocketManager.h"
#import <Protobuf/GPBProtocolBuffers.h>

@interface GMSocketConnect ()

@end

@implementation GMSocketConnect

- (__kindof GMSocketConnect* (^)(int messageType))msgType {
    SMSelfWeakly
    return ^(int messageType){
        SMSelfStrongly
        self -> _messageType = messageType;
        return self;
    };
}

- (__kindof GMSocketConnect *)initWithDelegate:(id <GMSocketConnectDelegate>)delegate {
    if (self = [super init]) {
        self.delegate = delegate;
    }
    return self;
}

///连接的IP
- (__kindof GMSocketConnect* (^)(NSString *IP))IP {
    SMSelfWeakly
    return ^(NSString *IP){
        SMSelfStrongly
        self -> _connectIP = IP;
        return self;
    };
}

///连接的端口号
- (__kindof GMSocketConnect* (^)(UInt16 port))port {
    SMSelfWeakly
    return ^(UInt16 port){
        SMSelfStrongly
        self -> _connectPort = port;
        return self;
    };
}

///发送的消息
- (__kindof GMSocketConnect* (^)(__kindof GPBMessage *sendData))requestData {
    SMSelfWeakly
    return ^(__kindof GPBMessage *sendData){
        SMSelfStrongly
        self -> _sendData = sendData;
        return self;
    };
}

///发送的消息
- (__kindof GMSocketConnect* (^)(NSDictionary *param))param {
    SMSelfWeakly
    return ^(NSDictionary *sendParam){
        SMSelfStrongly
        return self;
    };
}

///超时时间
- (__kindof GMSocketConnect* (^)(NSTimeInterval timeout))timeout {
    SMSelfWeakly
    return ^(NSTimeInterval timeout){
        SMSelfStrongly
        self -> _timeoutInterval= timeout;
        return self;
    };
}

///取消
- (__kindof GMSocketConnect* (^)(BOOL cancel))cancel {
    SMSelfWeakly
    return ^(BOOL cancel){
        SMSelfStrongly
        self -> _canceled = cancel;
        if (self -> _finishCallback){
            self -> _finishCallback(nil, [NSError errorWithDomain:NSURLErrorDomain code:-1001 userInfo:@{@"msg" : @"连接已取消"}]);
            if ([self.delegate respondsToSelector:@selector(connectDidCancel:)]) {
                [self.delegate connectDidCancel:self];
            }
        }
        return self;
    };
}

///成功回调
- (__kindof GMSocketConnect* (^)(QNSocketConnectSuccess))success {
    SMSelfWeakly
    return ^(QNSocketConnectSuccess success){
        SMSelfStrongly
        self -> _successCallback = success;
        return self;
    };
}

///失败回调
- (__kindof GMSocketConnect* (^)(QNSocketConnectError))error {
    SMSelfWeakly
    return ^(QNSocketConnectError error){
        SMSelfStrongly
        self -> _errorCallback = error;
        return self;
    };
}

///无论成功或失败的回调
- (__kindof GMSocketConnect* (^)(QNSocketConnectFinish))finish {
    SMSelfWeakly
    return ^(QNSocketConnectFinish finish){
        SMSelfStrongly
        self -> _finishCallback = finish;
        return self;
    };
}

- (__kindof GMSocketConnect* (^)(void))send {
    SMSelfWeakly
    return ^(void){
        SMSelfStrongly
        [[GMUDPSocketManager sharedInstance] sendRequestData:self -> _sendData msgType:self -> _messageType toHost:self -> _connectIP port:self -> _connectPort withTimeout:self -> _timeoutInterval callback:^(NSDictionary *response, NSError *error) {
            if (!self.canceled) {
                if (error && self -> _errorCallback) {
                    self -> _errorCallback(error);
                } else if (self -> _successCallback) {
                    self -> _successCallback(response);
                }
                if (self -> _finishCallback){
                    self -> _finishCallback(response, error);
                }
                if ([self.delegate respondsToSelector:@selector(connectDidFinish:)]) {
                    [self.delegate connectDidFinish:self];
                }
                SMDebugLog(@"finish request\r\nhost:%@\r\nport:%d\r\nresult:%@\r\nerror:error%@\r\n",self -> _connectIP, self -> _connectPort,response,error);
            }
        }];
        if ([self.delegate respondsToSelector:@selector(connectDidStart:)]) {
            [self.delegate connectDidStart:self];
        }
        SMDebugLog(@"start build request\r\nhost:%@\r\nport:%d\r\n",self -> _connectIP,self -> _connectPort);

        return self;
    };
}

- (void)cancelConnect {
    self.cancel(YES);
}

- (void)dealloc {
    SM_MEMORAY_CHECK_DEBUG_LOG;
}

@end
