//
//  GMSocketTask.h
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/11.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import <Foundation/Foundation.h>

@class GPBMessage;

@protocol GMSocketTaskDelegate;

///成功回调
typedef void(^GMSocketTaskSuccess)(id responseObj);
///失败回调
typedef void(^GMSocketTaskError)(NSError *error);
///统一回调
typedef void(^GMSocketTaskFinish)(id responseObj, NSError *error);

@interface GMSocketTask : NSObject {
    
@protected
    GMSocketTaskSuccess _successCallback;
    GMSocketTaskError _errorCallback;
    GMSocketTaskFinish _finishCallback;
//    NSString *_taskIP;
//    UInt16 _taskPort;

}

@property (nonatomic, assign, readonly) int messageType;
@property (nonatomic, copy, readonly) __kindof GPBMessage *sendData;

@property (nonatomic, assign, readonly) NSTimeInterval timeoutInterval;
@property (nonatomic, assign, readonly) BOOL needLogin;

- (__kindof GMSocketTask *)initWithDelegate:(id <GMSocketTaskDelegate>)delegate;

@property (nonatomic,weak) id <GMSocketTaskDelegate> delegate;

@property (nonatomic, assign, readonly) BOOL canceled;

///请求类型
- (__kindof GMSocketTask* (^)(int messageType))msgType;

///发送的消息
- (__kindof GMSocketTask* (^)(__kindof GPBMessage *))requestData;
- (__kindof GMSocketTask* (^)(NSDictionary <NSString *, id> *sendParam))param;

///超时时间
- (__kindof GMSocketTask* (^)(NSTimeInterval timeout))timeout;

///取消
- (__kindof GMSocketTask* (^)(BOOL cancel))cancel;

///成功回调
- (__kindof GMSocketTask* (^)(GMSocketTaskSuccess))success;

///失败回调
- (__kindof GMSocketTask* (^)(GMSocketTaskError))error;

///无论成功或失败的回调
- (__kindof GMSocketTask* (^)(GMSocketTaskFinish))finish;

///执行请求，默认需要account.deviceId & account.sessionId
- (__kindof GMSocketTask* (^)(void))excute;

///执行请求，选择是否需要重登陆逻辑
- (__kindof GMSocketTask* (^)(BOOL needLogin))excuteNeedLogin;

///取消该次任务
- (void)cancelTask;

@end

@protocol GMSocketTaskDelegate <NSObject>

@optional

- (void)taskDidStart:(__kindof GMSocketTask *)task;

- (void)taskDidCancel:(__kindof GMSocketTask *)task;

- (void)taskDidFinish:(__kindof GMSocketTask *)task;


@end

