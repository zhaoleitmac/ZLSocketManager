//
//  GMSocketSessionManager.m
//  ZLSocketManager
//
//  Created by 赵雷 on 2018/6/12.
//  Copyright © 2018年 赵雷. All rights reserved.
//

#import "GMSocketSessionManager.h"
#import <libkern/OSAtomic.h>
#import "GMSocketConnection.h"
#import "GMSocketSessionMsg.h"
#import "SMConstant.h"
#import "SMLog.h"
#import "GMSocketManager.h"
#import "GMProtoBufSession.h"
#import "GMSessionError.h"

#define kConnectTimeout 10

UInt16 const CASHIER_PORT = 8838;

static int const excuteCountMax = 3;

@interface GMSocketSessionManager () <GMSocketConnectionDelegate>

///执行block所用，加锁不重复执行回调
@property (nonatomic, assign) OSSpinLock actionLock;

//访问sessiones所用，防止多处访问sessiones可能造成崩溃
@property (nonatomic, assign) OSSpinLock sessionLock;

@property (atomic, strong) NSMutableSet <GMSocketSession *> *sessiones;

@property (nonatomic, strong) GMSocketConnection *connection;

@property (nonatomic, copy) NSString *host;

@property (nonatomic, assign) UInt16 port;

@end


@implementation GMSocketSessionManager

+ (instancetype)sharedInstance {
    return [self new];
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (instancetype)init {
    static dispatch_once_t onceToken;
    static typeof(self) instance;
    dispatch_once(&onceToken, ^{
        instance = [super init];
        self.actionLock = OS_SPINLOCK_INIT;
        self.sessionLock = OS_SPINLOCK_INIT;
        self.sessiones = [NSMutableSet new];
        self.connection.delegate = self;

    });
    return instance;
}


- (BOOL)isConnected {
    return self.connection.isConnected;
}

- (BOOL)isDisconnected {
    BOOL isConnected = self.connection.isConnected;
    BOOL isConnecting = self.connection.isConnecting;
    BOOL disconnected = !isConnected && !isConnecting; //未连接
    return disconnected;
}

- (void)disconnect {
    if (self.connection) {
        [self.connection disconnect];
        self.connection = nil;
    }
}

#pragma mark - connect

- (void)connectionWithHost:(NSString *)host port:(UInt16)port callback:(void(^)(NSError *error))callback {
    [self disconnect];//如果有先断开连接
    self.connection = [[GMSocketConnection alloc] initWithHost:host port:port];
    self.connection.delegate = self;
    SMSelfWeakly
    [self.connection connection:kConnectTimeout callback:^(GMSocketConnection *connection, NSError *error) {
        SMSelfStrongly
        if (!error) {
            self.host = host;
            self.port = port;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if (callback) {
                callback(error);
            }
        });
    }];
}

- (void)connection:(void(^)(NSError *error))callback {
    [self connection:kConnectTimeout callback:callback];
}

- (void)connection:(NSTimeInterval)timeout callback:(void(^)(NSError *error))callback {
    BOOL isConnected = self.connection.isConnected;
    BOOL isConnecting = self.connection.isConnecting;
    BOOL disconnected = !isConnected && !isConnecting; //未连接
    if (disconnected) {//未连接
        [self connectionWithHost:self.host port:self.port callback:callback];
    } else {
        if (callback) {
            callback(nil);
        }
    }
}

#pragma mark - handle request

- (void)sendRequestData:(__kindof GPBMessage *)requestData
                msgType:(int)msgType
                timeout:(NSTimeInterval)timeout
               callback:(GMSocketSessionCallback)callback {
    GMSocketSession *session = [GMSocketSession new];
    GMProtoBufSession *sessionInfo = [GMProtoBufSession sessionInfoWithRequestMsgType:msgType];
    session.sessionInfo = sessionInfo;
    session.requestData = requestData;
    session.IDENTIFIER = [GMSocketManager sharedInstance].IDENTIFIER;
    session.callback = callback;
    session.timeOutTimer = [NSTimer timerWithTimeInterval:timeout target:self selector:@selector(timeoutAction:) userInfo:@{@"IDENTIFIER" : @(session.IDENTIFIER)} repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:session.timeOutTimer forMode:NSRunLoopCommonModes];
    [self excuteSession:session];
}

- (void)excuteSession:(GMSocketSession *)session {
    
    [self addSession:session];

    OSSpinLock lock = self.actionLock;
    BOOL locked = OSSpinLockTry(&lock);
    BOOL isConnecting = self.connection.isConnecting; //连接中
    BOOL isConnected = self.connection.isConnected;//已连接
    if (!isConnecting) {
        if (isConnected) {
            [self excuteAllSession];
        } else {
            SMSelfWeakly
            [self connection:^(NSError *error) {
                SMSelfStrongly
                if (error) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (session.callback) {
                            session.callback(nil, error);
                        }
                        [self removeSessione:session];
                    });
                }
            }];
        }
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (void)excuteAllSession {
    OSSpinLock lock = self.sessionLock;
    BOOL locked = OSSpinLockTry(&lock);
    for (GMSocketSession *session in self.sessiones) {
        if (!session.excuting) {    //未在执行中
            GMSocketSessionMsg *messageObj = [GMSocketSessionMsg messageWithIDENTIFIER:session.IDENTIFIER msgType:session.sessionInfo.REQUEST_MSG_TYPE messageData:session.requestData];
            [self.connection sendMessage:messageObj timeout:-1 tag:kSocketTaskTag];
            session.excuting = YES; //设置正在执行
        }
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (void)addSession:(GMSocketSession *)session {
    OSSpinLock lock = self.sessionLock;
    BOOL locked = OSSpinLockTry(&lock);
    [self.sessiones addObject:session];
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (void)removeSessione:(GMSocketSession *)session {
    OSSpinLock lock = self.sessionLock;
    BOOL locked = OSSpinLockTry(&lock);
    [session.timeOutTimer invalidate];
    session.timeOutTimer = nil;
    if ([self.sessiones containsObject:session]) {
        [self.sessiones removeObject:session];
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}

- (GMSocketSession *)sessionWithId:(long)IDENTIFIER {
    GMSocketSession *currentSession = nil;
    OSSpinLock lock = self.sessionLock;
    BOOL locked = OSSpinLockTry(&lock);
    for (GMSocketSession *session in self.sessiones) {
        if (session.IDENTIFIER == IDENTIFIER) {
            currentSession = session;
            break;
        }
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
    return currentSession;
}

- (void)timeoutAction:(NSTimer *)timer {
    NSNumber *idN = timer.userInfo[@"IDENTIFIER"];
    long IDENTIFIER = idN.longLongValue;
    
    //超时清空缓存
    [self.connection cleanDataBuffer];

    GMSocketSession *session = [self sessionWithId:IDENTIFIER];
    session.timeOutCount++;
    
    if (session.timeOutCount < excuteCountMax) { //超时了两次，就是执行了三次
        
        [self removeSessione:session];
        
        NSTimeInterval timeOut = 5;
        session.timeOutTimer = [NSTimer timerWithTimeInterval:timeOut target:self selector:@selector(timeoutAction:) userInfo:@{@"IDENTIFIER" : @(session.IDENTIFIER)} repeats:NO];
        [[NSRunLoop mainRunLoop] addTimer:session.timeOutTimer forMode:NSRunLoopCommonModes];
        session.excuting = NO;  //设置未在执行
        [self excuteSession:session];
        
    } else {
        [self doSessionActionWithIDENTIFIER:IDENTIFIER responseData:nil error:[NSError errorWithDomain:@"请求超时" code:-1001 userInfo:nil]];
    }
}

#pragma mark - handle response

///执行Session的callback，加锁不重复执行
- (void)doSessionActionWithIDENTIFIER:(long)IDENTIFIER responseData:(NSData *)responseData error:(NSError *)error {

    OSSpinLock lock = self.actionLock;
    BOOL locked = OSSpinLockTry(&lock);
    GMSocketSession *currentSession = [self sessionWithId:IDENTIFIER];
    if (currentSession) {
        id responseObj = nil;
        NSError *errorObj = error;
        
        if (responseData.length) {
            Class responseClass = NSClassFromString(currentSession.sessionInfo.responseClassName);
            SEL selector = @selector(parseFromData:error:);
            if ([responseClass respondsToSelector:selector]) {
                responseObj = [responseClass performSelector:selector withObject:responseData withObject:nil];
                
                SEL errorSelector = @selector(returnCode);
                if (!errorObj && [responseObj respondsToSelector:errorSelector]) {//匹配错误信息
                    int returnCode = [responseObj performSelector:errorSelector];
                    NSString *returnMsg = [GMSessionError errorMsgWithErrorCode:returnCode];
                    if (returnMsg.length) {
                        errorObj = [NSError errorWithDomain:returnMsg code:returnCode userInfo:nil];
                    }
                }
            }
            
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if (currentSession.callback) {
                currentSession.callback(responseObj, errorObj);
                currentSession.callback = nil;
            }
            [self removeSessione:currentSession];
        });
    }
    if (locked) {
        OSSpinLockUnlock(&lock);
    }
}


#pragma mark - GMSocketConnectionDelegate

- (void)handleMessage:(GMSocketSessionMsg *)message connection:(GMSocketConnection *)connection {

    //处理回调
    if (![self handlePushMessage:message connection:connection]) {//不是推送消息
        [self doSessionActionWithIDENTIFIER:message.header.IDENTIFIER responseData:message.body.DATA error:nil];
    }
}

- (BOOL)handlePushMessage:(GMSocketSessionMsg *)message connection:(GMSocketConnection *)connection {
    int MSG_TYPE = message.header.MSG_TYPE;
    NSData *data = message.body.DATA;
    BOOL isPushMessage = NO;
    //利用MSG_TYPE判断是不是推送
    if (isPushMessage) {
        SMDebugLog(@"received push message\r\nmsgType:%d\r\n", MSG_TYPE);
    }
    
    return isPushMessage;
}

//心跳断开重连
- (void)heatBeatDidDisconnect:(GMSocketConnection *)connection {
    if (self.connection == connection) {
        [self connectNeedConnected];
    }
}

- (void)connectNeedConnected {
    [self connection:^(NSError *error) {
        if (error) {
            [self connectNeedConnected];
        }
    }];
}

@end


@implementation GMSocketSession

@end
