//
//  GMSocketTask.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/11.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketTask.h"
#import "SMConstant.h"
#import "SMLog.h"
#import "GMSocketSessionManager.h"
#import <Protobuf/GPBProtocolBuffers.h>

NSTimeInterval const GM_SOCKET_TASK_TIME_OUT_NORMAL = 15;

NSString *const kSocketErrorDomain = @"cn.qncloud.cashier";

@implementation GMSocketTask

- (__kindof GMSocketTask *)initWithDelegate:(id <GMSocketTaskDelegate>)delegate {
    if (self = [super init]) {
        self.delegate = delegate;
        _timeoutInterval = GM_SOCKET_TASK_TIME_OUT_NORMAL;
        _needLogin = YES;
    }
    return self;
}

- (__kindof GMSocketTask* (^)(int messageType))msgType {
    SMSelfWeakly
    return ^(int messageType){
        SMSelfStrongly
        self -> _messageType = messageType;
        return self;
    };
}

///发送的消息
- (__kindof GMSocketTask* (^)(__kindof GPBMessage *sendData))requestData {
    SMSelfWeakly
    return ^(__kindof GPBMessage *sendData){
        SMSelfStrongly
        self -> _sendData = sendData;
        return self;
    };
}

///发送的消息
- (__kindof GMSocketTask* (^)(NSDictionary <NSString *,id> *param))param {
    SMSelfWeakly
    return ^(NSDictionary *sendParam){
        SMSelfStrongly
        return self;
    };
}

///超时时间
- (__kindof GMSocketTask* (^)(NSTimeInterval timeout))timeout {
    SMSelfWeakly
    return ^(NSTimeInterval timeout){
        SMSelfStrongly
        self -> _timeoutInterval= timeout;
        return self;
    };
}

///取消
- (__kindof GMSocketTask* (^)(BOOL cancel))cancel {
    SMSelfWeakly
    return ^(BOOL cancel){
        SMSelfStrongly
        self -> _canceled = cancel;
        if (self -> _finishCallback){
            self -> _finishCallback(nil, [NSError errorWithDomain:@"任务已取消" code:-1002 userInfo:nil]);
            if ([self.delegate respondsToSelector:@selector(taskDidCancel:)]) {
                [self.delegate taskDidCancel:self];
            }
        }
        return self;
    };
}

///成功回调
- (__kindof GMSocketTask* (^)(GMSocketTaskSuccess))success {
    SMSelfWeakly
    return ^(GMSocketTaskSuccess success){
        SMSelfStrongly
        self -> _successCallback = success;
        return self;
    };
}

///失败回调
- (__kindof GMSocketTask* (^)(GMSocketTaskError))error {
    SMSelfWeakly
    return ^(GMSocketTaskError error){
        SMSelfStrongly
        self -> _errorCallback = error;
        return self;
    };
}

///无论成功或失败的回调
- (__kindof GMSocketTask* (^)(GMSocketTaskFinish))finish {
    SMSelfWeakly
    return ^(GMSocketTaskFinish finish){
        SMSelfStrongly
        self -> _finishCallback = finish;
        return self;
    };
}

- (__kindof GMSocketTask* (^)(void))excute {
    SMSelfWeakly
    return ^(void){
        SMSelfStrongly
        return self.excuteNeedLogin(YES);
    };
}

- (__kindof GMSocketTask* (^)(BOOL needLogin))excuteNeedLogin {
    SMSelfWeakly
    return ^(BOOL needLogin){
        SMSelfStrongly
        self -> _needLogin = needLogin;
        [self sendRequest];
        if ([self.delegate respondsToSelector:@selector(taskDidStart:)]) {
            [self.delegate taskDidStart:self];
        }
        return self;
    };
}

- (void)sendRequest {
    
    [[GMSocketSessionManager sharedInstance] sendRequestData:self.sendData msgType:self.messageType timeout:self.timeoutInterval callback:^(id response, NSError *error) {
        NSError *responseError = nil;//[self checkErrorWithResponse:response];//返回信息错误
        SMDebugLog(@"finish request\r\nmsgType:%d\r\nresult:%@\r\nerror:error%@\r\n", self.messageType, response, error);
        if (!self.canceled) {
            if ((error || responseError) && self -> _errorCallback) {
                if (error) {
                    self -> _errorCallback(error);
                } else {
                    self -> _errorCallback(responseError);
                }
            } else if (self -> _successCallback) {
                self -> _successCallback(response);
            }
            if (self -> _finishCallback){
                self -> _finishCallback(response, error);
            }
            if ([self.delegate respondsToSelector:@selector(taskDidFinish:)]) {
                [self.delegate taskDidFinish:self];
            }
        }
    }];
    SMDebugLog(@"start build request\r\nmsgType:%d\r\n", self.messageType);
}

/////检查返回信息的错误
//- (NSError *)checkErrorWithResponse:(NSDictionary *)response {
//    NSString *code = response[GMSocketTask.returnCodeKey];
//    if ([code isEqualToString:GMSocketTask.authorizationInvalidCode]) {//未授权或授权过期
//        [SJAccount disconnectCashierAndInvalidNeedSendSignoutNotification:YES needRemindClient:YES];
//        return [NSError errorWithDomain:kSocketErrorDomain code:GMSocketTask.authorizationInvalidCode.integerValue userInfo:response];
//    } else if ([code isEqualToString:GMSocketTask.sessionInvalidCode]) {//登录失效或密码错误
//        [SJAccount invalidNeedSendSignoutNotification:YES needRemindClient:YES];
//        return [NSError errorWithDomain:kSocketErrorDomain code:GMSocketTask.sessionInvalidCode.integerValue userInfo:response];
//    }
//    return nil;
//}

- (void)cancelConnect {
    self.cancel(YES);
}

- (void)cancelTask {
    self.cancel(YES);
}

- (void)dealloc {
    SMDebugLog(@"SocketTask dealloc for url: %d", self.messageType);
}


@end
